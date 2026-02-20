//
//  BlogUploadAnimationView.swift
//  Capper
//
//  Full-screen animation page shown during blog upload.

import SwiftUI

struct BlogUploadAnimationView: View {
    @EnvironmentObject private var uploadManager: BlogUploadManager
    @Environment(\.dismiss) private var dismiss
    
    // Background color matching CreatingRecapView
    private let backgroundColor = Color(red: 5/255, green: 10/255, blue: 48/255)

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack {
                // Top Bar
                HStack {
                    Spacer()
                    Button {
                        uploadManager.showUploadAnimationPage = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(16)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                Spacer()

                // Main Content
                VStack(spacing: 32) {
                    // Photo Counter
                    Text("Uploading \(uploadManager.uploadProgress.current) of \(uploadManager.uploadProgress.total)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Animated Photo
                    ZStack {
                        // Background placeholder / border
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                            .frame(width: 260, height: 260)
                            .background(Color.black.opacity(0.2).cornerRadius(20))
                        
                        if let assetId = uploadManager.currentUploadingPhotoId {
                            AssetPhotoView(
                                assetIdentifier: assetId,
                                cornerRadius: 18,
                                targetSize: CGSize(width: 800, height: 800)
                            )
                            .frame(width: 256, height: 256)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 1.05))
                            ))
                            .id(assetId) // Forces transition on ID change
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: uploadManager.currentUploadingPhotoId)
                    
                    Text("Please keep the app open")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Bottom Cancel Button
                Button {
                    uploadManager.cancelUpload()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        // Auto-dismiss if upload finishes or cancels while on this page
        .onChange(of: uploadManager.isUploading) { _, isUploading in
            if !isUploading {
                dismiss() // just a fallback
            }
        }
        .onChange(of: uploadManager.showUploadAnimationPage) { _, show in
            if !show {
                dismiss()
            }
        }
    }
}

#Preview {
    BlogUploadAnimationView()
        .environmentObject(BlogUploadManager.shared)
}
