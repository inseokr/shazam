//
//  ProfileMapView.swift
//  Capper
//

import MapKit
import SwiftUI

// MARK: - ProfileMapView (map + country filter buttons)

/// Map-first Profile: full-screen map with trip markers and country filter pills at top.
struct ProfileMapView: View {
    @EnvironmentObject private var createdRecapStore: CreatedRecapBlogStore
    @Binding var selectedCreatedRecap: CreatedRecapBlog?
    @StateObject private var viewModel: ProfileMapViewModel
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var selectedBlogForNavigation: CreatedRecapBlog?

    init(createdRecapStore: CreatedRecapBlogStore, selectedCreatedRecap: Binding<CreatedRecapBlog?>) {
        _viewModel = StateObject(wrappedValue: ProfileMapViewModel(createdRecapStore: createdRecapStore))
        _selectedCreatedRecap = selectedCreatedRecap
    }

    var body: some View {
        ZStack(alignment: .top) {
            profileMap
            countryFilterBar
            
            // Bottom Trip List
            VStack {
                Spacer()
                bottomTripList
            }
            .ignoresSafeArea(.keyboard)
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("My Map")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.onAppear()
            mapPosition = .region(viewModel.mapRegion)
        }
        .onChange(of: viewModel.mapRegionChangeCounter) { _, _ in
            withAnimation {
                mapPosition = .region(viewModel.mapRegion)
            }
        }
        .navigationDestination(item: $selectedBlogForNavigation) { blog in
            RecapBlogPageView(
                blogId: blog.sourceTripId,
                initialTrip: _createdRecapStore.wrappedValue.tripDraft(for: blog.sourceTripId)
            )
        }
    }

    private var profileMap: some View {
        Map(position: $mapPosition) {
            ForEach(viewModel.tripsWithCoordinates, id: \.blog.sourceTripId) { item in
                annotation(for: item)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .onMapCameraChange(frequency: .onEnd) { context in
            viewModel.mapRegion = context.region
        }
    }

    @MapContentBuilder
    private func annotation(for item: (blog: CreatedRecapBlog, coordinate: CLLocationCoordinate2D)) -> some MapContent {
        Annotation("", coordinate: item.coordinate) {
            TripAnnotationView(
                blog: item.blog,
                isSelected: viewModel.selectedTripID == item.blog.sourceTripId
            )
            .onTapGesture {
                withAnimation {
                    viewModel.selectTrip(item.blog.sourceTripId)
                    viewModel.recenterToTrip(item.blog)
                }
            }
        }
    }

    // MARK: - Country Filter Bar

    private var countryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                countryPill(label: "All", isSelected: viewModel.selectedCountryID == nil) {
                    viewModel.selectCountry(nil)
                }
                ForEach(viewModel.countrySummaries) { summary in
                    countryPill(
                        label: summary.countryName,
                        isSelected: viewModel.selectedCountryID == summary.countryName
                    ) {
                        viewModel.selectCountry(summary.countryName)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Bottom Trip List
    
    private var bottomTripList: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.visibleTrips, id: \.sourceTripId) { trip in
                        ProfileMapCardView(
                            blog: trip,
                            isSelected: viewModel.selectedTripID == trip.sourceTripId,
                            onTap: {
                                withAnimation {
                                    viewModel.selectTrip(trip.sourceTripId)
                                    viewModel.recenterToTrip(trip)
                                }
                            },
                            onNavigate: {
                                selectedBlogForNavigation = trip
                            }
                        )
                        .id(trip.sourceTripId)
                        .frame(width: 300)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20) // Safe area breathing room
            }
            .onChange(of: viewModel.selectedTripID) { _, newID in
                if let id = newID {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 140)
    }

    private func countryPill(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.white.opacity(0.2))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ProfileMapCardView (Bottom List Item)
private struct ProfileMapCardView: View {
    let blog: CreatedRecapBlog
    let isSelected: Bool
    let onTap: () -> Void
    let onNavigate: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                coverImage
                tripInfo
                chevronButton
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .background(Color.black.opacity(0.3))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var coverImage: some View {
        TripCoverImage(
            theme: blog.coverImageName,
            coverAssetIdentifier: blog.coverAssetIdentifier,
            targetSize: CGSize(width: 160, height: 160)
        )
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var tripInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(blog.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            HStack(spacing: 4) {
                if let country = blog.countryName {
                    Text(country)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
                Text(blog.tripDateRangeText ?? "")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chevronButton: some View {
        Button(action: onNavigate) {
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
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
        VStack(spacing: 4) {
            TripCoverImage(
                theme: blog.coverImageName,
                coverAssetIdentifier: blog.coverAssetIdentifier,
                targetSize: CGSize(width: 104, height: 144)
            )
            .frame(width: Self.width, height: Self.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.6), lineWidth: isSelected ? 3 : 1.5)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 2)

            Text(blog.title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 80)
                .shadow(color: .black.opacity(0.5), radius: 1)
        }
    }
}

// MARK: - CountryMapView (map filtered to a single country)

/// Map showing only trips for a specific country. Reached from CountryBlogsView toolbar.
struct CountryMapView: View {
    let countryName: String
    @Binding var selectedCreatedRecap: CreatedRecapBlog?
    @EnvironmentObject private var createdRecapStore: CreatedRecapBlogStore
    @StateObject private var viewModel: ProfileMapViewModel

    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var selectedBlogForNavigation: CreatedRecapBlog?

    init(countryName: String, selectedCreatedRecap: Binding<CreatedRecapBlog?>) {
        self.countryName = countryName
        _selectedCreatedRecap = selectedCreatedRecap
        _viewModel = StateObject(wrappedValue: ProfileMapViewModel(createdRecapStore: CreatedRecapBlogStore.shared))
    }

    var body: some View {
        Map(position: $mapPosition) {
            ForEach(viewModel.tripsWithCoordinates, id: \.blog.sourceTripId) { item in
                annotation(for: item)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .onMapCameraChange(frequency: .onEnd) { context in
            viewModel.mapRegion = context.region
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(countryName)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.selectCountry(countryName)
            mapPosition = .region(viewModel.mapRegion)
        }
        .onChange(of: viewModel.mapRegionChangeCounter) { _, _ in
            withAnimation {
                mapPosition = .region(viewModel.mapRegion)
            }
        }
        .navigationDestination(item: $selectedBlogForNavigation) { blog in
            RecapBlogPageView(
                blogId: blog.sourceTripId,
                initialTrip: _createdRecapStore.wrappedValue.tripDraft(for: blog.sourceTripId)
            )
        }
    }

    @MapContentBuilder
    private func annotation(for item: (blog: CreatedRecapBlog, coordinate: CLLocationCoordinate2D)) -> some MapContent {
        Annotation("", coordinate: item.coordinate) {
            TripAnnotationView(
                blog: item.blog,
                isSelected: viewModel.selectedTripID == item.blog.sourceTripId
            )
            .onTapGesture {
                viewModel.selectTrip(item.blog.sourceTripId)
                selectedBlogForNavigation = item.blog
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileMapView(
            createdRecapStore: CreatedRecapBlogStore.shared,
            selectedCreatedRecap: .constant(nil)
        )
        .environmentObject(CreatedRecapBlogStore.shared)
    }
}
