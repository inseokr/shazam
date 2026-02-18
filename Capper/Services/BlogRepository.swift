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

    private let currentSchemaVersion = 1

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

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseURL = appSupport.appendingPathComponent("BlogGo", isDirectory: true)
        blogsIndexURL = baseURL.appendingPathComponent("blogs/index.json")
        detailDir = baseURL.appendingPathComponent("blogs/detail", isDirectory: true)
        draftDir = baseURL.appendingPathComponent("blogs/draft", isDirectory: true)
        settingsDir = baseURL.appendingPathComponent("settings", isDirectory: true)
        schemaVersionURL = settingsDir.appendingPathComponent("schema_version.json")

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        decoder = dec

        // Create directories synchronously during init (actor init runs before isolation)
        try? FileManager.default.createDirectory(at: detailDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: draftDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: settingsDir, withIntermediateDirectories: true)
    }

    // MARK: - Migration

    /// Run on first load. Checks schema version and applies migrations if needed.
    func runMigrationsIfNeeded() {
        let storedVersion: Int
        if let data = try? Data(contentsOf: schemaVersionURL),
           let sv = try? decoder.decode(SchemaVersion.self, from: data) {
            storedVersion = sv.version
        } else {
            storedVersion = 0
        }

        if storedVersion < currentSchemaVersion {
            // v0 → v1: No structural changes needed; just write the version file.
            // Future migrations: add cases here.
            writeSchemaVersion()
        }
    }

    private func writeSchemaVersion() {
        let sv = SchemaVersion(version: currentSchemaVersion)
        atomicWrite(sv, to: schemaVersionURL)
    }

    // MARK: - Blog Index (lightweight list)

    /// Load all persisted blog metadata. Returns empty array if none saved yet.
    func loadAll() -> [CreatedRecapBlog] {
        guard let data = try? Data(contentsOf: blogsIndexURL),
              let blogs = try? decoder.decode([CreatedRecapBlog].self, from: data) else {
            return []
        }
        return blogs
    }

    /// Atomically overwrite the full blog index. Call after any mutation to the list.
    func saveIndex(_ blogs: [CreatedRecapBlog]) {
        atomicWrite(blogs, to: blogsIndexURL)
    }

    // MARK: - Blog Detail (full content: captions, notes, place stops)

    func saveDetail(_ detail: RecapBlogDetail) {
        let url = detailDir.appendingPathComponent("\(detail.id.uuidString).json")
        atomicWrite(detail, to: url)
    }

    func loadDetail(blogId: UUID) -> RecapBlogDetail? {
        let url = detailDir.appendingPathComponent("\(blogId.uuidString).json")
        guard let data = try? Data(contentsOf: url),
              let detail = try? decoder.decode(RecapBlogDetail.self, from: data) else {
            return nil
        }
        return detail
    }

    // MARK: - Trip Draft (photo selection + trip metadata)

    func saveTripDraft(_ draft: TripDraft, blogId: UUID) {
        let url = draftDir.appendingPathComponent("\(blogId.uuidString).json")
        atomicWrite(draft, to: url)
    }

    func loadTripDraft(blogId: UUID) -> TripDraft? {
        let url = draftDir.appendingPathComponent("\(blogId.uuidString).json")
        guard let data = try? Data(contentsOf: url),
              let draft = try? decoder.decode(TripDraft.self, from: data) else {
            return nil
        }
        return draft
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
    func loadAllDetails() -> [UUID: RecapBlogDetail] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: detailDir, includingPropertiesForKeys: nil) else {
            return [:]
        }
        var result: [UUID: RecapBlogDetail] = [:]
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let detail = try? decoder.decode(RecapBlogDetail.self, from: data) else { continue }
            result[detail.id] = detail
        }
        return result
    }

    /// Load all trip draft files from disk. Used to restore tripDraftsBySourceId on launch.
    func loadAllTripDrafts() -> [UUID: TripDraft] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: draftDir, includingPropertiesForKeys: nil) else {
            return [:]
        }
        var result: [UUID: TripDraft] = [:]
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let draft = try? decoder.decode(TripDraft.self, from: data) else { continue }
            result[draft.id] = draft
        }
        return result
    }

    // MARK: - Atomic Write Helper

    private func atomicWrite<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else { return }
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
