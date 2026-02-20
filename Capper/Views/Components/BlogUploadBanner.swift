//
//  BlogUploadBanner.swift
//  Capper
//
//  A floating banner showing upload progress or success, used across screens.

import SwiftUI

struct BlogUploadBanner: View {
    @EnvironmentObject private var uploadManager: BlogUploadManager

    var body: some View {
        Group {
            if uploadManager.isUploading && !uploadManager.showUploadAnimationPage {
                // Uploading progress banner
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Uploading to cloud…")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Text("\(uploadManager.uploadProgress.current) of \(uploadManager.uploadProgress.total) photos")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    Spacer()
                    
                    // Cancel upload button
                    Button {
                        uploadManager.cancelUpload()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .contentShape(Rectangle()) // Make the whole banner tappable
                .onTapGesture {
                    uploadManager.showUploadAnimationPage = true
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .transition(.opacity.combined(with: .move(edge: .top)))
                
            } else if uploadManager.showUploadSuccessBanner {
                // Success banner
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.icloud.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Uploaded to cloud")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Text("All photos are now in the cloud.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    Spacer()
                    Button {
                        withAnimation { uploadManager.showUploadSuccessBanner = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .transition(.opacity.combined(with: .move(edge: .top)))
                // Auto dismiss success banner after a few seconds
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation {
                            uploadManager.showUploadSuccessBanner = false
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: uploadManager.isUploading)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: uploadManager.showUploadSuccessBanner)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: uploadManager.showUploadAnimationPage)
    }
}
