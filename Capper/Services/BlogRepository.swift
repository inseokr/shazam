//
//  BlogRepository.swift
//  Capper
//
//  Actor-based persistence layer. All blog data is written to
//  Application Support/BlogGo/ using atomic JSON files.
//  Safe to call from any async context.
//

import Foundation

// MARK: - BlogRepository

actor BlogRepository {
    static let shared = BlogRepository()

    private let currentSchemaVersion = 2

    private struct SchemaVersion: Codable, Sendable {
        var version: Int
    }

    // MARK: - Directories

    private let baseURL: URL
    private let blogsIndexURL: URL
    private let detailDir: URL
    private let draftDir: URL
    private let settingsDir: URL
    private let schemaVersionURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseURL = appSupport.appendingPathComponent("BlogGo", isDirectory: true)
        blogsIndexURL = baseURL.appendingPathComponent("blogs/index.json")
        detailDir = baseURL.appendingPathComponent("blogs/detail", isDirectory: true)
        draftDir = baseURL.appendingPathComponent("blogs/draft", isDirectory: true)
        settingsDir = baseURL.appendingPathComponent("settings", isDirectory: true)
        schemaVersionURL = settingsDir.appendingPathComponent("schema_version.json")

        // Create directories synchronously during init (actor init runs before isolation)
        try? FileManager.default.createDirectory(at: detailDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: draftDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: settingsDir, withIntermediateDirectories: true)
    }
    
    private nonisolated func makeEncoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }
    
    private nonisolated func makeDecoder() -> JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }

    // MARK: - Migration

    /// Run on first load. Checks schema version and applies migrations if needed.
    func runMigrationsIfNeeded() {
        let storedVersion: Int
        if let data = try? Data(contentsOf: schemaVersionURL),
           let sv = try? makeDecoder().decode(SchemaVersion.self, from: data) {
            storedVersion = sv.version
        } else {
            storedVersion = 0
        }

        if storedVersion < currentSchemaVersion {
            // v0 → v1: No structural changes needed; initial version marker.
            // v1 → v2: Added ownerScope, ownerUserId, cloudId, cloudState, syncStatus,
            //          lastAutosaveAt to CreatedRecapBlog. Safe defaults are applied in
            //          the custom Codable init (decodeIfPresent with fallback values).
            //          No file restructuring required.
            writeSchemaVersion()
        }
    }

    private func writeSchemaVersion() {
        let sv = SchemaVersion(version: currentSchemaVersion)
        if let data = try? makeEncoder().encode(sv) {
            atomicWrite(data, to: schemaVersionURL)
        }
    }

    // MARK: - Blog Index (lightweight list)

    /// Load all persisted blog metadata. Returns empty array if none saved yet.
    func loadAll() -> [CreatedRecapBlog] {
        // CreatedRecapBlog is assumed to be safe for non-isolated decoding
        guard let data = try? Data(contentsOf: blogsIndexURL),
              let blogs = try? makeDecoder().decode([CreatedRecapBlog].self, from: data) else {
            return []
        }
        return blogs
    }

    /// Atomically overwrite the full blog index. Call after any mutation to the list.
    func saveIndex(_ blogs: [CreatedRecapBlog]) {
        if let data = try? makeEncoder().encode(blogs) {
            atomicWrite(data, to: blogsIndexURL)
        }
    }

    // MARK: - Blog Detail (full content: captions, notes, place stops)

    func saveDetail(_ detail: RecapBlogDetail) async {
        let url = detailDir.appendingPathComponent("\(detail.id.uuidString).json")
        // Hop to MainActor for encoding since the type conformance is isolated
        let data = await MainActor.run {
            try? makeEncoder().encode(detail)
        }
        if let data = data {
            atomicWrite(data, to: url)
        }
    }

    func loadDetail(blogId: UUID) async -> RecapBlogDetail? {
        let url = detailDir.appendingPathComponent("\(blogId.uuidString).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        // Hop to MainActor for decoding
        return await MainActor.run {
            try? makeDecoder().decode(RecapBlogDetail.self, from: data)
        }
    }

    // MARK: - Trip Draft (photo selection + trip metadata)

    func saveTripDraft(_ draft: TripDraft, blogId: UUID) async {
        let url = draftDir.appendingPathComponent("\(blogId.uuidString).json")
        let data = await MainActor.run {
            try? makeEncoder().encode(draft)
        }
        if let data = data {
            atomicWrite(data, to: url)
        }
    }

    func loadTripDraft(blogId: UUID) async -> TripDraft? {
        let url = draftDir.appendingPathComponent("\(blogId.uuidString).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        return await MainActor.run {
            try? makeDecoder().decode(TripDraft.self, from: data)
        }
    }

    // MARK: - Delete

    /// Remove all persisted data for a blog (index entry must be removed separately via saveIndex).
    func delete(blogId: UUID) {
        let detailURL = detailDir.appendingPathComponent("\(blogId.uuidString).json")
        let draftURL = draftDir.appendingPathComponent("\(blogId.uuidString).json")
        try? FileManager.default.removeItem(at: detailURL)
        try? FileManager.default.removeItem(at: draftURL)
    }

    // MARK: - Bulk Load (for store init)

    /// Load all detail files from disk. Used to restore blogDetailsBySourceId on launch.
    func loadAllDetails() async -> [UUID: RecapBlogDetail] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: detailDir, includingPropertiesForKeys: nil) else {
            return [:]
        }
        
        // Read all data first (IO on actor)
        var detailData: [Data] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file) {
                detailData.append(data)
            }
        }
        
        let immutableDetailData = detailData
        
        // Decode all on MainActor
        return await MainActor.run {
            var result: [UUID: RecapBlogDetail] = [:]
            let decoder = makeDecoder()
            for data in immutableDetailData {
                if let detail = try? decoder.decode(RecapBlogDetail.self, from: data) {
                    result[detail.id] = detail
                }
            }
            return result
        }
    }

    /// Load all trip draft files from disk. Used to restore tripDraftsBySourceId on launch.
    func loadAllTripDrafts() async -> [UUID: TripDraft] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: draftDir, includingPropertiesForKeys: nil) else {
            return [:]
        }
        
        var draftData: [Data] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file) {
                draftData.append(data)
            }
        }
        
        let immutableDraftData = draftData
        
        return await MainActor.run {
            var result: [UUID: TripDraft] = [:]
            let decoder = makeDecoder()
            for data in immutableDraftData {
                if let draft = try? decoder.decode(TripDraft.self, from: data) {
                    result[draft.id] = draft
                }
            }
            return result
        }
    }

    // MARK: - Atomic Write Helper

    private func atomicWrite(_ data: Data, to url: URL) {
        // Ensure parent directory exists
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Atomic write: write to temp file then rename
        let tempURL = dir.appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            // .atomic already does the temp+rename internally, but we use a named temp for clarity
            _ = try? FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            // Fallback: direct write
            try? data.write(to: url, options: .atomic)
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
}
