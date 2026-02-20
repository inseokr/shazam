//
//  ProfileManagementView.swift
//  Capper
//
//  Allows users to view their blogs and manage cloud upload status.
//

import SwiftUI

struct ProfileManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var createdRecapStore: CreatedRecapBlogStore

    @State private var selectedBlog: CreatedRecapBlog?
    @State private var uploadingBlogId: UUID?
    @State private var uploadProgress: (current: Int, total: Int) = (0, 0)
    @State private var showUploadError = false
    @State private var uploadErrorMessage = ""
    @State private var selectedCountryFilter: String? = nil

    // Remove-from-cloud confirmation
    @State private var showRemoveConfirmation = false
    @State private var blogPendingRemoval: CreatedRecapBlog? = nil

    // MARK: - Derived lists

    private var publishedBlogs: [CreatedRecapBlog] {
        createdRecapStore.recents
            .filter { createdRecapStore.isBlogInCloud(blogId: $0.sourceTripId) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var notUploadedBlogs: [CreatedRecapBlog] {
        createdRecapStore.recents
            .filter { !createdRecapStore.isBlogInCloud(blogId: $0.sourceTripId) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var notUploadedCountries: [String] {
        let countries = notUploadedBlogs.compactMap { $0.countryName }
        return Array(Set(countries)).sorted()
    }

    private var filteredNotUploadedBlogs: [CreatedRecapBlog] {
        guard let country = selectedCountryFilter else { return notUploadedBlogs }
        return notUploadedBlogs.filter { $0.countryName == country }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                            .padding(.bottom, 4)

                        Text("Manage Your Blogs")
                            .font(.system(.title2, design: .serif).weight(.medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)

                        Text("Upload blogs to the cloud so they appear on your profile.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 8)

                    // MARK: - Published Section
                    if !publishedBlogs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.icloud.fill")
                                    .foregroundColor(.green)
                                Text("Published")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(publishedBlogs.count)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)

                            LazyVStack(spacing: 12) {
                                ForEach(publishedBlogs) { blog in
                                    Button {
                                        selectedBlog = blog
                                    } label: {
                                        ProfileManagementRow(
                                            blog: blog,
                                            isPublished: true,
                                            isUploading: false,
                                            uploadProgress: nil,
                                            onToggle: {
                                                blogPendingRemoval = blog
                                                showRemoveConfirmation = true
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // MARK: - Not Uploaded Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "icloud.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("Not Uploaded")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(notUploadedBlogs.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)

                        // Country filter pills
                        if notUploadedCountries.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    filterPill(label: "All", isSelected: selectedCountryFilter == nil) {
                                        selectedCountryFilter = nil
                                    }
                                    ForEach(notUploadedCountries, id: \.self) { country in
                                        filterPill(label: country, isSelected: selectedCountryFilter == country) {
                                            selectedCountryFilter = country
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        if filteredNotUploadedBlogs.isEmpty {
                            Text("No blogs here.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredNotUploadedBlogs) { blog in
                                    Button {
                                        selectedBlog = blog
                                    } label: {
                                        ProfileManagementRow(
                                            blog: blog,
                                            isPublished: false,
                                            isUploading: uploadingBlogId == blog.sourceTripId,
                                            uploadProgress: uploadingBlogId == blog.sourceTripId ? uploadProgress : nil,
                                            onToggle: {
                                                uploadBlog(blog)
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedBlog) { blog in
                RecapBlogPageView(
                    blogId: blog.sourceTripId,
                    initialTrip: createdRecapStore.tripDraft(for: blog.sourceTripId)
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Upload Failed", isPresented: $showUploadError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(uploadErrorMessage)
            }
            .alert("Remove from Cloud?", isPresented: $showRemoveConfirmation, presenting: blogPendingRemoval) { blog in
                Button("Yes, Remove", role: .destructive) {
                    removeFromCloud(blog)
                }
                Button("No", role: .cancel) {
                    blogPendingRemoval = nil
                }
            } message: { blog in
                Text("Are you sure you want to remove \"\(blog.title)\" from the cloud? It will no longer appear on your public profile.")
            }
        }
    }

    // MARK: - Filter Pill

    private func filterPill(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Remove from Cloud

    private func removeFromCloud(_ blog: CreatedRecapBlog) {
        createdRecapStore.removeFromCloud(blogId: blog.sourceTripId)
        blogPendingRemoval = nil
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    // MARK: - Upload

    private func uploadBlog(_ blog: CreatedRecapBlog) {
        guard !createdRecapStore.isBlogInCloud(blogId: blog.sourceTripId) else { return }
        guard uploadingBlogId == nil else { return }
        guard AuthService.shared.currentJwtToken != nil else {
            uploadErrorMessage = "Please sign in to upload photos."
            showUploadError = true
            return
        }

        guard var detail = createdRecapStore.getBlogDetail(blogId: blog.sourceTripId) else {
            uploadErrorMessage = "Blog has not been saved yet. Open the blog and save it first."
            showUploadError = true
            return
        }

        var photosToUpload: [(dayIdx: Int, stopIdx: Int, photoIdx: Int, assetId: String)] = []
        for (dIdx, day) in detail.days.enumerated() {
            for (sIdx, stop) in day.placeStops.enumerated() {
                for (pIdx, photo) in stop.photos.enumerated() {
                    if photo.isIncluded && photo.cloudURL == nil,
                       let assetId = photo.localIdentifier {
                        photosToUpload.append((dIdx, sIdx, pIdx, assetId))
                    }
                }
            }
        }

        guard !photosToUpload.isEmpty else { return }

        uploadingBlogId = blog.sourceTripId
        uploadProgress = (0, photosToUpload.count)

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        Task {
            var failCount = 0
            for item in photosToUpload {
                do {
                    let cloudURL = try await APIManager.shared.uploadPhoto(assetIdentifier: item.assetId)
                    detail.days[item.dayIdx].placeStops[item.stopIdx].photos[item.photoIdx].cloudURL = cloudURL
                } catch {
                    failCount += 1
                    print("🚨 Upload failed for asset \(item.assetId): \(error.localizedDescription)")
                }
                uploadProgress.current += 1
            }

            createdRecapStore.saveBlogDetail(detail)
            uploadingBlogId = nil

            if failCount == 0 {
                let snapshot = detail
                Task {
                    try? await APIManager.shared.publishBlogDetail(snapshot)
                }
            }

            if failCount > 0 {
                uploadErrorMessage = "\(failCount) photo\(failCount == 1 ? "" : "s") failed to upload. Try again."
                showUploadError = true
            }
        }
    }
}

struct ProfileManagementRow: View {
    let blog: CreatedRecapBlog
    let isPublished: Bool
    var isUploading: Bool = false
    var uploadProgress: (current: Int, total: Int)?
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            AssetPhotoView(
                assetIdentifier: blog.coverAssetIdentifier ?? blog.coverImageName,
                cornerRadius: 12,
                targetSize: CGSize(width: 180, height: 180)
            )
            .frame(width: 60, height: 60)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(blog.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if isUploading, let progress = uploadProgress {
                    Text("Uploading \(progress.current)/\(progress.total)…")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text(blog.tripDateRangeText ?? "Unknown Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Action Button
            Button(action: onToggle) {
                Group {
                    if isUploading {
                        ProgressView()
                            .tint(.blue)
                            .frame(width: 16, height: 16)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: isPublished ? "checkmark.icloud.fill" : "icloud.and.arrow.up")
                            Text(isPublished ? "Published" : "Upload")
                        }
                    }
                }
                .font(.system(.subheadline, weight: .medium))
                .foregroundColor(isPublished ? .green : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isPublished ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .disabled(isUploading)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ProfileManagementView()
        .environmentObject(CreatedRecapBlogStore.shared)
}
