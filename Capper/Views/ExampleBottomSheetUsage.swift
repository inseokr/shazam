
import SwiftUI

struct ExampleBottomSheetUsage: View {
    @State private var isSheetOpen = false

    var body: some View {
        ZStack {
            // Main content
            VStack {
                Button("Open Bottom Sheet") {
                    withAnimation {
                        isSheetOpen = true
                    }
                }
                .font(.headline)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))

            // Bottom sheet overlay
            if isSheetOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isSheetOpen = false
                        }
                    }
                
                BottomSheetView(
                    isOpen: $isSheetOpen,
                    maxHeight: UIScreen.main.bounds.height * 0.8,
                    minHeight: 0
                ) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Bottom Sheet Content")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.top)
                        
                        ForEach(1...50, id: \.self) { i in
                            HStack {
                                Text("Item \(i)")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                }
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
        }
    }
}

#Preview {
    ExampleBottomSheetUsage()
}
