//
//  ProfileManagementView.swift
//  Capper
//
//  Allows users to view their blogs and "manage" their cloud publication status.
//

import SwiftUI

struct ProfileManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var createdRecapStore: CreatedRecapBlogStore
    
    // In a real application, the 'isPublishedToCloud' state might reside on the data model itself.
    // For now we simulate it seamlessly via user defaults so it remembers local mock choices.
    @AppStorage("mockCloudPublishedStore") private var mockCloudPublishedStoreData: Data = Data()
    @State private var mockCloudStore: Set<UUID> = []
    @State private var selectedBlog: CreatedRecapBlog?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header Message
                    VStack(spacing: 8) {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                            .padding(.bottom, 4)
                            
                        Text("Manage Your Published Blogs")
                            .font(.system(.title2, design: .serif).weight(.medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("Select which stories appear in the cloud and on your public profile.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 16)
                    
                    // Blog List
                    // Sorting from newest (first in array usually) to oldest
                    LazyVStack(spacing: 16) {
                        ForEach(createdRecapStore.recents.sorted(by: { $0.createdAt > $1.createdAt })) { blog in
                            Button {
                                selectedBlog = blog
                            } label: {
                                ProfileManagementRow(
                                    blog: blog,
                                    isPublished: mockCloudStore.contains(blog.sourceTripId),
                                    onToggle: {
                                        togglePublication(for: blog.sourceTripId)
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    
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
            .onAppear {
                loadMockStore()
            }
        }
    }
    
    private func loadMockStore() {
        if let decoded = try? JSONDecoder().decode(Set<UUID>.self, from: mockCloudPublishedStoreData) {
            mockCloudStore = decoded
        }
    }
    
    private func saveMockStore() {
        if let encoded = try? JSONEncoder().encode(mockCloudStore) {
            mockCloudPublishedStoreData = encoded
        }
    }
    
    private func togglePublication(for id: UUID) {
        if mockCloudStore.contains(id) {
            mockCloudStore.remove(id)
        } else {
            mockCloudStore.insert(id)
        }
        saveMockStore()
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

struct ProfileManagementRow: View {
    let blog: CreatedRecapBlog
    let isPublished: Bool
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
                
                Text(blog.tripDateRangeText ?? "Unknown Date")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action Button
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Image(systemName: isPublished ? "checkmark.icloud.fill" : "icloud.and.arrow.up")
                    Text(isPublished ? "Published" : "Upload")
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
