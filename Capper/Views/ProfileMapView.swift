//
//  ProfileMapView.swift
//  Capper
//

import MapKit
import SwiftUI
import UIKit

// MARK: - ProfileMapView (map + overlay sheet container)

/// Map-first Profile: full-screen map with trip markers and a draggable pull-up modal (countries / trips).
struct ProfileMapView: View {
    @EnvironmentObject private var createdRecapStore: CreatedRecapBlogStore
    @Binding var selectedCreatedRecap: CreatedRecapBlog?
    @StateObject private var viewModel: ProfileMapViewModel
    @State private var mapPosition: MapCameraPosition = .automatic

    init(createdRecapStore: CreatedRecapBlogStore, selectedCreatedRecap: Binding<CreatedRecapBlog?>) {
        _viewModel = StateObject(wrappedValue: ProfileMapViewModel(createdRecapStore: createdRecapStore))
        _selectedCreatedRecap = selectedCreatedRecap
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            profileMap
            ProfileBottomSheet(
                viewModel: viewModel,
                selectedCreatedRecap: $selectedCreatedRecap
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.onAppear()
            mapPosition = .region(viewModel.mapRegion)
        }
        .onChange(of: viewModel.mapRegionChangeCounter) { _, _ in
            mapPosition = .region(viewModel.mapRegion)
        }
    }

    private var profileMap: some View {
        Map(position: $mapPosition) {
            ForEach(viewModel.tripsWithCoordinates, id: \.blog.sourceTripId) { item in
                Annotation("", coordinate: item.coordinate) {
                    TripAnnotationView(
                        blog: item.blog,
                        isSelected: viewModel.selectedTripID == item.blog.sourceTripId
                    )
                    .onTapGesture {
                        viewModel.selectTrip(item.blog.sourceTripId)
                        selectedCreatedRecap = item.blog
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .onMapCameraChange(frequency: .onEnd) { context in
            viewModel.mapRegion = context.region
        }
    }
}

// MARK: - TripAnnotationView (portrait thumbnail marker)

/// Portrait rounded-rectangle trip cover thumbnail for map annotations.
struct TripAnnotationView: View {
    let blog: CreatedRecapBlog
    var isSelected: Bool = false

    private static let width: CGFloat = 52
    private static let height: CGFloat = 72

    var body: some View {
        ZStack {
            TripCoverImage(
                theme: blog.coverImageName,
                coverAssetIdentifier: blog.coverAssetIdentifier
            )
            .frame(width: Self.width, height: Self.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.6), lineWidth: isSelected ? 3 : 1.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
        }
    }
}

// MARK: - ProfileBottomSheet (custom draggable sheet)

private enum SheetDetent: CGFloat, CaseIterable {
    case min = 0.08
    case mid = 0.42
    case countryCovers = 0.72
    case max = 0.98   // all the way to top; vertical scroll only enabled here
}

struct ProfileBottomSheet: View {
    @ObservedObject var viewModel: ProfileMapViewModel
    @Binding var selectedCreatedRecap: CreatedRecapBlog?

    @State private var dragOffset: CGFloat = 0
    @State private var currentDetent: SheetDetent = .countryCovers

    var body: some View {
        GeometryReader { geo in
            let maxH = geo.size.height
            let sheetHeight = currentSheetHeight(maxHeight: maxH)
            // Drag up (finger up) = negative translation → we use -translation so sheet expands
            let effectiveHeight = min(maxH, sheetHeight - dragOffset)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    grabHandle
                    sheetContent(containerWidth: geo.size.width, maxHeight: maxH, scrollEnabled: currentDetent == .max)
                }
                .frame(height: effectiveHeight)
                .background(Color(white: 0.12))
                .clipShape(UnevenRoundedCorners(radius: 24, corners: [.topLeft, .topRight]))
            }
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8), value: currentDetent)
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let currentHeight = sheetHeight - value.translation.height
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        let next = snapDetent(currentHeight: currentHeight, maxHeight: maxH, velocity: velocity)
                        currentDetent = next
                        dragOffset = 0
                    }
            )
        }
    }

    private func currentSheetHeight(maxHeight: CGFloat) -> CGFloat {
        maxHeight * (currentDetent.rawValue)
    }

    /// Velocity: negative = dragging up (expand), positive = dragging down (collapse).
    private func snapDetent(currentHeight: CGFloat, maxHeight: CGFloat, velocity: CGFloat) -> SheetDetent {
        let minH = maxHeight * SheetDetent.min.rawValue
        let midH = maxHeight * SheetDetent.mid.rawValue
        let coversH = maxHeight * SheetDetent.countryCovers.rawValue
        let maxH = maxHeight * SheetDetent.max.rawValue
        if velocity < -80 {
            if currentHeight < midH { return .min }
            if currentHeight < coversH { return .mid }
            if currentHeight < maxH { return .countryCovers }
            return .max
        }
        if velocity > 80 {
            if currentHeight > maxH { return .max }
            if currentHeight > coversH { return .max }
            if currentHeight > midH { return .countryCovers }
            return currentHeight > minH ? .mid : .min
        }
        let distMin = abs(currentHeight - minH)
        let distMid = abs(currentHeight - midH)
        let distCovers = abs(currentHeight - coversH)
        let distMax = abs(currentHeight - maxH)
        let d = [SheetDetent.min: distMin, .mid: distMid, .countryCovers: distCovers, .max: distMax]
        return d.min(by: { $0.value < $1.value })!.key
    }

    private var grabHandle: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.6))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func sheetContent(containerWidth: CGFloat, maxHeight: CGFloat, scrollEnabled: Bool) -> some View {
        if viewModel.countrySummaries.isEmpty && viewModel.visibleTrips.isEmpty {
            emptyState
        } else if viewModel.selectedCountryID != nil {
            tripsListContent(maxHeight: maxHeight, scrollEnabled: scrollEnabled)
        } else {
            countriesListContent(containerWidth: containerWidth, maxHeight: maxHeight, scrollEnabled: scrollEnabled)
        }
    }

    private var emptyState: some View {
        Text("No recap blogs yet. Create one from a trip!")
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }

    @ViewBuilder
    private func countriesListContent(containerWidth: CGFloat, maxHeight: CGFloat, scrollEnabled: Bool) -> some View {
        let content = VStack(alignment: .leading, spacing: 16) {
            Text("By Country")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.top, 8)

            LazyVStack(spacing: 16) {
                ForEach(viewModel.countrySummaries) { summary in
                    CountryCardView(section: CountrySection(
                        countryName: summary.countryName,
                        lastBlogDate: summary.mostRecentBlog.createdAt,
                        latestCoverBlog: summary.mostRecentBlog,
                        blogs: summary.blogs
                    )) {
                        viewModel.selectCountry(summary.countryName)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .topLeading)

        if scrollEnabled {
            ScrollView {
                content
                    .frame(minHeight: 0)
            }
        } else {
            content
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        }
    }

    private func tripsListContent(maxHeight: CGFloat, scrollEnabled: Bool) -> some View {
        let backButton = Button {
            viewModel.selectCountry(nil)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                Text("Back to By Country")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white.opacity(0.95))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)

        let listContent = LazyVStack(spacing: 12) {
            ForEach(viewModel.visibleTrips) { blog in
                TripRowView(
                    blog: blog,
                    isSelected: viewModel.selectedTripID == blog.sourceTripId
                ) {
                    viewModel.selectTrip(blog.sourceTripId)
                    viewModel.recenterToTrip(blog)
                    selectedCreatedRecap = blog
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)

        return VStack(spacing: 0) {
            backButton
            if scrollEnabled {
                ScrollView {
                    listContent
                        .frame(minHeight: 0)
                }
            } else {
                listContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipped()
            }
        }
    }
}

// MARK: - TripRowView (for modal Mode B)

private struct TripRowView: View {
    let blog: CreatedRecapBlog
    var isSelected: Bool
    var onTap: () -> Void

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                TripCoverImage(theme: blog.coverImageName, coverAssetIdentifier: blog.coverAssetIdentifier)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text(blog.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(Self.dateFormatter.string(from: blog.createdAt))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.white.opacity(0.12) : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - UnevenRoundedCorners (top-only corner radius)

private struct UnevenRoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
