//
//  ManagePhotosView.swift
//  Capper
//

import SwiftUI

/// Grid checklist to add/remove photos for a place stop. Toggling isIncluded adds/removes from blog.
struct ManagePhotosView: View {
    let placeTitle: String
    @Binding var photos: [RecapPhoto]
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(photos.indices, id: \.self) { index in
                        photoCell(photo: photos[index], index: index)
                    }
                }
                .padding()
            }
            .navigationTitle("Manage Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .preferredColorScheme(.dark)
        }
    }

    private func photoCell(photo: RecapPhoto, index: Int) -> some View {
        let isIncluded = photos[index].isIncluded
        return Button {
            photos[index].isIncluded.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                RecapPhotoThumbnail(photo: photo, cornerRadius: 8, showIcon: false)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isIncluded ? Color.blue : Color.clear, lineWidth: 3)
                    )
                if isIncluded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ManagePhotosView(
        placeTitle: "Stop 1",
        photos: .constant([
            RecapPhoto(timestamp: Date(), imageName: "photo", isIncluded: true),
            RecapPhoto(timestamp: Date(), imageName: "camera", isIncluded: false)
        ])
    )
}
