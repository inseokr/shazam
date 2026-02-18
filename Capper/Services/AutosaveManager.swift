//
//  AutosaveManager.swift
//  Capper
//
//  Debounced autosave for blog editors. Call scheduleSave() on every
//  keystroke; the actual disk write fires 500ms after the last call.
//  Cancels any pending save if a new edit arrives before the timer fires.
//

import Foundation

@MainActor
final class AutosaveManager {
    static let shared = AutosaveManager()

    private var debounceTask: Task<Void, Never>?
    private let debounceInterval: UInt64 = 500_000_000 // 500ms in nanoseconds

    private init() {}

    /// Schedule a debounced save of the given blog detail.
    /// Safe to call on every keystroke — only the last call within the debounce window fires.
    func scheduleSave(detail: RecapBlogDetail) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: self.debounceInterval)
            } catch {
                return // Task was cancelled — a newer edit is coming
            }
            guard !Task.isCancelled else { return }
            // Persist detail to disk (background, non-blocking)
            await BlogRepository.shared.saveDetail(detail)
            // Update the store's in-memory record as a draft (no lastEditedAt bump)
            CreatedRecapBlogStore.shared.saveBlogDetail(detail, asDraft: true)
        }
    }

    /// Cancel any pending autosave (e.g. when user explicitly taps Save).
    func cancelPending() {
        debounceTask?.cancel()
        debounceTask = nil
    }
}
