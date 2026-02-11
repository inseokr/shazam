//
//  CountryBlogsView.swift
//  Capper
//
//  Blogs for a single country: list/grid. Shown when user taps a Country Card.
//

import SwiftUI

struct CountryBlogsView: View {
    let section: CountrySection
    @Binding var selectedBlog: CreatedRecapBlog?
    @EnvironmentObject private var createdRecapStore: CreatedRecapBlogStore
    @State private var localSelectedBlog: CreatedRecapBlog?
    @State private var showMap = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    var body: some View {
        List {
            ForEach(section.blogs) { blog in
                Button {
                    localSelectedBlog = blog
                } label: {
                    HStack(spacing: 14) {
                        TripCoverImage(theme: blog.coverImageName, coverAssetIdentifier: blog.coverAssetIdentifier)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(alignment: .bottomLeading) {
                                if blog.lastEditedAt == nil {
                                    Text("Draft")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(4)
                                        .padding(2)
                                }
                            }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(blog.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(blog.totalPlaceVisitCount) Place\(blog.totalPlaceVisitCount == 1 ? "" : "s") • \(blog.tripDurationDays) Day\(blog.tripDurationDays == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Edited \(Self.dateFormatter.string(from: blog.lastEditedAt ?? blog.createdAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(displayCountryName(section.countryName))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showMap = true
                } label: {
                    Image(systemName: "map")
                }
            }
        }
        .navigationDestination(isPresented: $showMap) {
            CountryMapView(
                countryName: section.countryName,
                selectedCreatedRecap: $localSelectedBlog
            )
            .environmentObject(createdRecapStore)
        }
        .navigationDestination(item: $localSelectedBlog) { recap in
            RecapBlogPageView(
                blogId: recap.sourceTripId,
                initialTrip: createdRecapStore.tripDraft(for: recap.sourceTripId)
            )
        }
    }

    private func displayCountryName(_ name: String) -> String {
        name.isEmpty || name == "Unknown" ? "Other" : name
    }
}
