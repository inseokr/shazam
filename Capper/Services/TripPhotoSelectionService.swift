//
//  TripPhotoSelectionService.swift
//  Capper
//
//  Created for deterministic "Best 3 Photos" selection per place cluster.
//

import Foundation
import Photos
import CoreLocation

@MainActor
final class TripPhotoSelectionService {
    static let shared = TripPhotoSelectionService()
    
    // Use PlaceStopClusteringService to match how blog stops are created.
    private let placeStopClusteringService = PlaceStopClusteringService()
    
    /// Main entry point: Given a TripDraft, fetch its assets, cluster them into place stops,
    /// select top 3 per stop, and return a new TripDraft with those photos marked isSelected=true.
    func selectTopPhotosPerCluster(trip: TripDraft) async -> TripDraft {
        // 1. Collect all local identifiers from the trip
        let allPhotoIds = trip.days.flatMap { $0.photos }.compactMap { $0.localIdentifier }
        guard !allPhotoIds.isEmpty else {
            print("[TripPhotoSelectionService] No local identifiers found in trip.")
            return trip
        }
        
        // 2. Fetch PHAssets
        let assets = fetchAssets(with: allPhotoIds)
        guard !assets.isEmpty else {
            print("[TripPhotoSelectionService] No matching PHAssets found.")
            return trip
        }
        
        // 3. Cluster using PlaceStopClusteringService (matches blog creation logic)
        // Sort assets by date first as required by the service
        let sortedAssets = assets.sorted {
            ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
        }
        
        // Convert to ClusterPhotoInput
        let inputs: [ClusterPhotoInput] = sortedAssets.map { asset in
            let coord: PhotoCoordinate? = asset.location.map { loc in
                PhotoCoordinate(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            }
            return ClusterPhotoInput(id: UUID(), timestamp: asset.creationDate ?? Date(), location: coord)
        }
        
        // We need a mapping from input ID (UUID) back to PHAsset to find the asset later.
        // Or better yet, map from ClusterPhotoInput -> PHAsset via index?
        // Since inputs are created from sortedAssets 1:1, we can use indices or just match timestamps/coords (risk of collision).
        // Let's store a map of UUID -> PHAsset localIdentifier
        var idToLocalId: [UUID: String] = [:]
        for (index, input) in inputs.enumerated() {
            idToLocalId[input.id] = sortedAssets[index].localIdentifier
        }
        
        // Call the service
        let stopGroups = placeStopClusteringService.placeStops(from: inputs) { idx in
            "Stop \(idx + 1)"
        }
        print("[TripPhotoSelectionService] Found \(stopGroups.count) place stops.")
        
        var selectedAssetIds: Set<String> = []
        
        // 4. For each stop group, select top 3
        for (index, stopGroup) in stopGroups.enumerated() {
            // Find assets belonging to this group
            let groupLocalIds = stopGroup.photos.compactMap { idToLocalId[$0.id] }
            let groupAssets = sortedAssets.filter { groupLocalIds.contains($0.localIdentifier) }
            
            let best3 = selectBestPhotos(from: groupAssets, maxCount: 3)
            
            print("[TripPhotoSelectionService] Stop \(index): \(groupAssets.count) photos -> selected \(best3.count)")
            best3.forEach { selectedAssetIds.insert($0.localIdentifier) }
        }
        
        // 5. Update TripDraft
        var updatedTrip = trip
        for dayIdx in updatedTrip.days.indices {
            for photoIdx in updatedTrip.days[dayIdx].photos.indices {
                if let localId = updatedTrip.days[dayIdx].photos[photoIdx].localIdentifier {
                    if selectedAssetIds.contains(localId) {
                        updatedTrip.days[dayIdx].photos[photoIdx].isSelected = true
                    } else {
                        updatedTrip.days[dayIdx].photos[photoIdx].isSelected = false
                    }
                }
            }
        }
        
        return updatedTrip
    }
    
    private func fetchAssets(with localIdentifiers: [String]) -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false
        // We can fetch all at once
        let result = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: fetchOptions)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }
    
    /// Deterministic selection logic
    /// 1. Higher resolution (pixel count)
    /// 2. Closest to centroid
    /// 3. Prefer a diversity of timestamps (avoid near-duplicates)
    private func selectBestPhotos(from assets: [PHAsset], maxCount: Int) -> [PHAsset] {
        if assets.count <= maxCount { return assets }
        
        // Calculate centroid for this cluster
        let locations = assets.compactMap { $0.location }
        let centroid: CLLocation?
        if !locations.isEmpty {
            let avgLat = locations.map { $0.coordinate.latitude }.reduce(0, +) / Double(locations.count)
            let avgLon = locations.map { $0.coordinate.longitude }.reduce(0, +) / Double(locations.count)
            centroid = CLLocation(latitude: avgLat, longitude: avgLon)
        } else {
            centroid = nil
        }
        
        // Strategy:
        // 1. Sort by Time to identify bursts/duplicates (within 2s). Keep best of burst.
        // 2. Sort remaining by Quality + Centroid.
        // 3. Take top N.
        
        let timeSorted = assets.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        
        var distinctCandidates: [PHAsset] = []
        var currentBurst: [PHAsset] = []
        
        for asset in timeSorted {
            if let last = currentBurst.last,
               let t1 = last.creationDate?.timeIntervalSince1970,
               let t2 = asset.creationDate?.timeIntervalSince1970,
               abs(t2 - t1) < 2.0 { // 2 seconds threshold
                currentBurst.append(asset)
            } else {
                // Flush previous burst
                if !currentBurst.isEmpty {
                    distinctCandidates.append(bestInBurst(currentBurst, centroid: centroid))
                }
                currentBurst = [asset]
            }
        }
        // Flush last
        if !currentBurst.isEmpty {
            distinctCandidates.append(bestInBurst(currentBurst, centroid: centroid))
        }
        
        // Sort candidates by Quality (Res) then Centroid
        let finalSorted = distinctCandidates.sorted { a, b in
            // 1. Resolution
            let resA = a.pixelWidth * a.pixelHeight
            let resB = b.pixelWidth * b.pixelHeight
            if resA != resB {
                return resA > resB
            }
            // 2. Centroid
            if let c = centroid {
                let distA = a.location?.distance(from: c) ?? Double.infinity
                let distB = b.location?.distance(from: c) ?? Double.infinity
                return distA < distB
            }
            // 3. Stable
            return a.localIdentifier < b.localIdentifier
        }
        
        return Array(finalSorted.prefix(maxCount))
    }
    
    private func bestInBurst(_ assets: [PHAsset], centroid: CLLocation?) -> PHAsset {
        if assets.count == 1 { return assets[0] }
        return assets.max { a, b in
            // Return true if A < B (so max returns B). We want A < B means B is better.
            
            // 1. Resolution
            let resA = a.pixelWidth * a.pixelHeight
            let resB = b.pixelWidth * b.pixelHeight
            if resA != resB {
                return resA < resB // Higher is better
            }
            // 2. Centroid
            if let c = centroid {
                let distA = a.location?.distance(from: c) ?? Double.infinity
                let distB = b.location?.distance(from: c) ?? Double.infinity
                return distA > distB // Smaller distance is better
            }
            return false
        } ?? assets[0]
    }
}
