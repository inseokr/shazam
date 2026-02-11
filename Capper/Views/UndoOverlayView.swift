//
//  UndoOverlayView.swift
//  Capper
//
//  Created for the Recap Blog Undo feature.
//

import SwiftUI

struct UndoOverlayView: View {
    let text: String
    @Binding var isMinimized: Bool
    var onUndo: () -> Void
    var onDismiss: () -> Void // Actually dismiss/clear the undo opportunity (optional for UI flow)

    // Layout constants
    private let minimizedSize: CGFloat = 44
    private let horizontalPadding: CGFloat = 16
    private let bottomPadding: CGFloat = 16

    var body: some View {
        VStack {
            if isMinimized {
                minimizedView
                    .transition(.scale(scale: 0.1, anchor: .bottomTrailing).combined(with: .opacity))
            } else {
                expandedView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isMinimized)
        .padding(.bottom, bottomPadding)
        .padding(.horizontal, horizontalPadding)
        // Allow touches to pass through empty space in the container
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(true) // Ensure the view itself receives touches for buttons/gestures
    }

    private var expandedView: some View {
        HStack {
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            Spacer()
            Button(action: onUndo) {
                Text("Undo")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue) // Or brand color
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16) // Extra inset for banner look
        .gesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.height > 0 { // Swipe down
                        withAnimation {
                            isMinimized = true
                        }
                    }
                }
        )
    }

    private var minimizedView: some View {
        HStack {
            Spacer()
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: minimizedSize, height: minimizedSize)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            // Example Expanded
            UndoOverlayView(
                text: "Place deleted",
                isMinimized: .constant(false),
                onUndo: {},
                onDismiss: {}
            )
            
            // Example Minimized
            UndoOverlayView(
                text: "Photo removed",
                isMinimized: .constant(true),
                onUndo: {},
                onDismiss: {}
            )
            .padding(.bottom, 80)
        }
    }
}
