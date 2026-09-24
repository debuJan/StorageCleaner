import Foundation
import Photos
import Observation

struct SimilarPhotoGroup: Identifiable {
    let id = UUID()
    let assets: [PHAsset]
    let recommendedAssetID: String?
}

@Observable
final class SimilarPhotosViewModel {

    let photosService = PhotosService()
    private let deletionService = PhotoDeletionService()

    var groups: [SimilarPhotoGroup] = []
    var selectedIDs: Set<String> = []

    var isScanning = false
    var progress: Double = 0
    var errorMessage: String?
    var permissionMessage: String?

    var isLimitedAccess: Bool {
        photosService.isLimitedAccess
    }

    var hasScanned = false

    // MARK: - Scan

    func scan() {
        isScanning = true
        progress = 0
        errorMessage = nil
        permissionMessage = nil
        groups.removeAll()
        selectedIDs.removeAll()

        let status = photosService.authorizationStatus()

        switch status {

        case .authorized:
            startScan()

        case .limited:
            permissionMessage =
                "Photo access is limited. Only accessible photos can be scanned."
            startScan()

        case .denied:
            permissionMessage =
                "Photo access is denied. Allow access in Settings to scan your photos."
            isScanning = false

        case .restricted:
            permissionMessage = "Photo access is restricted on this device."
            isScanning = false

        case .notDetermined:
            permissionMessage = "Photo access is required to scan similar photos."
            isScanning = false

        @unknown default:
            permissionMessage = "Unable to determine photo access."
            isScanning = false
        }
    }

    private func startScan() {

        let photosService = self.photosService

        Task {

            let assets = await Task.detached(priority: .userInitiated) {
                photosService.fetchPhotosForSimilarity()
            }.value

            guard !assets.isEmpty else {
                await MainActor.run {
                    self.isScanning = false
                    self.hasScanned = true
                    self.progress = 1.0
                }
                return
            }

            let imageService = PhotoImageService()

            var hashedAssets: [SimilarityGrouper.HashedAsset] = []

            for (index, asset) in assets.enumerated() {

                guard let image = await imageService.requestThumbnail(
                    for: asset,
                    size: CGSize(width: 128, height: 128)
                ) else {
                    continue
                }

                if let hash = PerceptualHash.hash(image) {
                    hashedAssets.append(
                        SimilarityGrouper.HashedAsset(
                            id: asset.localIdentifier,
                            hash: hash,
                            creationDate: asset.creationDate ?? .distantPast
                        )
                    )
                }

                await MainActor.run {
                    self.progress = Double(index + 1) / Double(assets.count)
                }
            }

            let groupedIDs = SimilarityGrouper.group(
                assets: hashedAssets,
                threshold: 8
            )

            var newGroups: [SimilarPhotoGroup] = []

            for ids in groupedIDs {

                let groupAssets = assets.filter {
                    ids.contains($0.localIdentifier)
                }

                guard !groupAssets.isEmpty else {
                    continue
                }

                let recommended = groupAssets.max {
                    QualityScorer.score(asset: $0) < QualityScorer.score(asset: $1)
                }

                newGroups.append(
                    SimilarPhotoGroup(
                        assets: groupAssets,
                        recommendedAssetID: recommended?.localIdentifier
                    )
                )
            }

            await MainActor.run {
                self.groups = newGroups
                self.isScanning = false
                self.hasScanned = true
                self.progress = 1.0
            }
        }
    }

    // MARK: - Selection

    func toggleSelection(_ asset: PHAsset) {

        let id = asset.localIdentifier

        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func selectGroupForDeletion(_ group: SimilarPhotoGroup) {

        for asset in group.assets {
            if asset.localIdentifier != group.recommendedAssetID {
                selectedIDs.insert(asset.localIdentifier)
            }
        }
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    // MARK: - Deletion

    func deleteSelected() async {

        let identifiers = Array(selectedIDs)

        guard !identifiers.isEmpty else {
            return
        }

        do {
            try await deletionService.delete(identifiers: identifiers)

            let deletedIDs = Set(identifiers)

            groups = groups.compactMap { group in

                let remainingAssets = group.assets.filter {
                    !deletedIDs.contains($0.localIdentifier)
                }

                guard remainingAssets.count > 1 else {
                    return nil
                }

                let recommendedID = deletedIDs.contains(group.recommendedAssetID ?? "")
                    ? nil
                    : group.recommendedAssetID

                return SimilarPhotoGroup(
                    assets: remainingAssets,
                    recommendedAssetID: recommendedID
                )
            }

            selectedIDs.removeAll()

        } catch {
            errorMessage = "Failed to delete photos: \(error.localizedDescription)"
        }
    }
}