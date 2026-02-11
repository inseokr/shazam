//
//  MapWithCenterSelector.swift
//  Capper
//

import MapKit
import SwiftUI

// MARK: - Pulsing circle (fixed at center; opacity range 0.6–0.75, gentle scale + fade loop)

private struct CenterPulsingCircle: View {
    @State private var isExpanded = false
    private let size = OnboardingConstants.Map.centerCircleDiameter

    var body: some View {
        Circle()
            .fill(
                OnboardingConstants.Colors.centerCircleBlue.opacity(
                    isExpanded ? OnboardingConstants.Map.centerCircleOpacityRange.min : OnboardingConstants.Map.centerCircleOpacityRange.max
                )
            )
            .frame(width: size, height: size)
            .scaleEffect(isExpanded ? OnboardingConstants.Map.centerCircleScaleRange.max : OnboardingConstants.Map.centerCircleScaleRange.min)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: OnboardingConstants.Map.centerCirclePulseDuration)
                    .repeatForever(autoreverses: true)
                ) {
                    isExpanded = true
                }
            }
    }
}

/// Interactive map with a fixed center circle overlay. The circle stays in the center of the screen while the map pans underneath.
/// The selection area is the map region inside the circle. Tapping Select captures the current map center and reports it (parent updates text field and shows Done).
struct MapWithCenterSelector: View {
    @Binding var region: MKCoordinateRegion
    /// Called when user taps Select: (center, span). Parent should reverse geocode, update text field, and show Done.
    var onSelect: (CLLocationCoordinate2D, MKCoordinateSpan) -> Void
    var onUnselect: () -> Void
    var isSelected: Bool

    @State private var currentCenter: CLLocationCoordinate2D
    @State private var currentSpan: MKCoordinateSpan

    init(
        region: Binding<MKCoordinateRegion>,
        isSelected: Bool,
        onSelect: @escaping (CLLocationCoordinate2D, MKCoordinateSpan) -> Void,
        onUnselect: @escaping () -> Void
    ) {
        _region = region
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onUnselect = onUnselect
        _currentCenter = State(initialValue: region.wrappedValue.center)
        _currentSpan = State(initialValue: region.wrappedValue.span)
    }

    var body: some View {
        ZStack {
            MapWithRegionBinding(
                region: $region,
                center: $currentCenter,
                span: $currentSpan
            )
            .accessibilityLabel("Map for neighborhood selection. Pan and zoom to choose an area.")
            .onChange(of: region.center.latitude) { _, _ in
                currentCenter = region.center
                currentSpan = region.span
            }
            .onChange(of: region.center.longitude) { _, _ in
                currentCenter = region.center
                currentSpan = region.span
            }

            // Orange circle and Select button fixed together, centered; button right under circle with padding
            VStack(spacing: OnboardingConstants.Map.selectButtonSpacingBelowCircle) {
                CenterPulsingCircle()
                selectButton
            }
        }
    }

    private var selectButton: some View {
        Button(action: {
            if isSelected {
                onUnselect()
            } else {
                onSelect(currentCenter, currentSpan)
            }
        }) {
            Text(isSelected ? "Unselect" : "Select")
                .font(.headline)
                .foregroundColor(isSelected ? .white : .black)
                .padding(.horizontal, 32)
                .padding(.vertical, OnboardingConstants.Layout.selectButtonVerticalPadding)
                .background(isSelected ? Color.black.opacity(0.6) : Color.white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(isSelected ? "Unselect neighborhood" : "Select neighborhood")
        .accessibilityHint(isSelected ? "Clears the current selection" : "Sets the area under the circle; then tap Done to continue")
    }
}

// MARK: - Map that reports center and span when user pans/zooms

private struct MapWithRegionBinding: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var center: CLLocationCoordinate2D
    @Binding var span: MKCoordinateSpan

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.region = region
        map.delegate = context.coordinator
        map.showsUserLocation = true
        return map
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let desired = MKCoordinateRegion(center: region.center, span: region.span)

        if regionsAreClose(mapView.region, desired) { return }

        context.coordinator.isProgrammaticChange = true
        mapView.setRegion(desired, animated: true)

        DispatchQueue.main.async {
            context.coordinator.isProgrammaticChange = false
        }
    }

    private func regionsAreClose(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
        abs(a.center.latitude - b.center.latitude) < 0.000_001 &&
        abs(a.center.longitude - b.center.longitude) < 0.000_001 &&
        abs(a.span.latitudeDelta - b.span.latitudeDelta) < 0.000_001 &&
        abs(a.span.longitudeDelta - b.span.longitudeDelta) < 0.000_001
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapWithRegionBinding
        var isProgrammaticChange = false

        init(_ parent: MapWithRegionBinding) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            guard !isProgrammaticChange else { return }

            let newCenter = mapView.region.center
            let newSpan = mapView.region.span

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if !self.sameCoordinate(self.parent.center, newCenter) {
                    self.parent.center = newCenter
                }
                if !self.sameSpan(self.parent.span, newSpan) {
                    self.parent.span = newSpan
                }
            }
        }

        private func sameCoordinate(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
            abs(a.latitude - b.latitude) < 0.000_001 && abs(a.longitude - b.longitude) < 0.000_001
        }

        private func sameSpan(_ a: MKCoordinateSpan, _ b: MKCoordinateSpan) -> Bool {
            abs(a.latitudeDelta - b.latitudeDelta) < 0.000_001 &&
            abs(a.longitudeDelta - b.longitudeDelta) < 0.000_001
        }
    }
}
