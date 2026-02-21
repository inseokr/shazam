//
//  BlogUploadManager.swift
//  Capper
//
//  Shared manager to handle blog uploads in the background.

import Foundation
import SwiftUI
import Combine

@MainActor
final class BlogUploadManager: ObservableObject {
    static let shared = BlogUploadManager()

    @Published var isUploading = false
    @Published var uploadProgress: (current: Int, total: Int) = (0, 0)
    @Published var showUploadAnimationPage = false
    
    /// The ID of the blog currently being uploaded.
    @Published var uploadingBlogId: UUID?
    
    /// The local identifier of the currently uploading photo (for animation).
    @Published var currentUploadingPhotoId: String?

    @Published var showUploadSuccessBanner = false
    @Published var showUploadErrorAlert = false
    @Published var uploadErrorMessage = ""

    private var isCancelled = false
    private var activeTask: Task<Void, Never>?

    private init() {}

    func startUpload(for blogId: UUID, photosToUpload: [(dayIdx: Int, stopIdx: Int, photoIdx: Int, assetId: String)], detail: RecapBlogDetail) {
        guard !isUploading else { return }

        isUploading = true
        isCancelled = false
        uploadingBlogId = blogId
        uploadProgress = (0, photosToUpload.count)
        showUploadAnimationPage = true

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        var updatedDetail = detail

        activeTask = Task {
            var failCount = 0
            for item in photosToUpload {
                if isCancelled { break }
                
                currentUploadingPhotoId = item.assetId
                
                do {
                    let cloudURL = try await APIManager.shared.uploadPhoto(assetIdentifier: item.assetId)
                    updatedDetail.days[item.dayIdx].placeStops[item.stopIdx].photos[item.photoIdx].cloudURL = cloudURL
                } catch {
                    failCount += 1
                    print("🚨 Upload failed for asset \(item.assetId): \(error.localizedDescription)")
                }
                
                if !isCancelled {
                    uploadProgress.current += 1
                }
            }

            // Save regardless of success or failure/cancellation (saves progress)
            CreatedRecapBlogStore.shared.saveBlogDetail(updatedDetail)
            
            if isCancelled {
                resetState()
                return
            }

            uploadingBlogId = nil
            isUploading = false
            currentUploadingPhotoId = nil
            showUploadAnimationPage = false

            if failCount == 0 {
                showUploadSuccessBanner = true
                let snapshot = updatedDetail
                let blogId = snapshot.id
                Task {
                    if let blogKey = await APIManager.shared.publishBlog(detail: snapshot) {
                        await MainActor.run {
                            CreatedRecapBlogStore.shared.setBlogKey(blogId: blogId, blogKey: blogKey)
                        }
                    }
                }
            } else {
                uploadErrorMessage = "\(failCount) photo\(failCount == 1 ? "" : "s") failed to upload. Try again."
                showUploadErrorAlert = true
            }
        }
    }

    func cancelUpload() {
        isCancelled = true
        activeTask?.cancel()
        resetState()
    }

    private func resetState() {
        isUploading = false
        uploadingBlogId = nil
        currentUploadingPhotoId = nil
        showUploadAnimationPage = false
        uploadProgress = (0, 0)
    }
}
