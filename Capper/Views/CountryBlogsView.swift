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
    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    var body: some View {
        List {
            ForEach(section.blogs) { blog in
                Button {
                    selectedBlog = blog
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        TripCoverImage(theme: blog.coverImageName, coverAssetIdentifier: blog.coverAssetIdentifier)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(blog.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(Self.dateFormatter.string(from: blog.createdAt))
                                .font(.subheadline)
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
    }

    private func displayCountryName(_ name: String) -> String {
        name.isEmpty || name == "Unknown" ? "Other" : name
    }
}
