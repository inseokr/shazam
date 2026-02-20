//
//  SyncEngine.swift
//  Capper
//
//  Pull-only sync: fetches cloud blogs and merges them into the local store.
//  NEVER auto-uploads. All uploads are explicit user actions.
//

import Foundation

// MARK: - SyncEngine

@MainActor
final class SyncEngine {
    static let shared = SyncEngine()
    private init() {}

    // MARK: - Merge

    /// Fetches the user's cloud blogs and merges them into the local store.
    /// - Existing local blogs with a matching cloudId are updated if the remote is newer.
    /// - Cloud-only blogs not present locally are inserted as account-owned local entries.
    /// - Local blogs are NEVER uploaded. Sync is pull-only.
    func fetchAndMerge(userId: String) async {
        do {
            let cloudBlogs = try await CloudBlogService.shared.fetchBlogs()
            for cloudBlog in cloudBlogs {
                CreatedRecapBlogStore.shared.mergeCloudBlog(cloudBlog, ownedBy: userId)
            }
            print("✅ SyncEngine: merged \(cloudBlogs.count) cloud blog(s) for userId '\(userId)'")
        } catch {
            // Non-fatal: if sync fails, the user sees their local data.
            print("⚠️ SyncEngine: fetch failed — \(error.localizedDescription)")
        }
    }
}
