import Foundation
import Photos
import Observation

@Observable
final class ScreenshotsViewModel {

    let photosService = PhotosService()
    private let deletionService = PhotoDeletionService()

    var screenshots: [PHAsset] = []
    var selectedIDs: Set<String> = []

    var isLoading = false
    var errorMessage: String?
    var permissionMessage: String?

    var isLimitedAccess: Bool {
        photosService.isLimitedAccess
    }

    var selectedAssets: [PHAsset] {
        screenshots.filter {
            selectedIDs.contains($0.localIdentifier)
        }
    }

    // MARK: - Loading

    func loadScreenshots() {

        isLoading = true
        errorMessage = nil
        permissionMessage = nil

        let status = photosService.authorizationStatus()

        switch status {

        case .authorized:
            fetchScreenshots()

        case .limited:
            permissionMessage =
                "Photo access is limited. Only selected photos are available."
            fetchScreenshots()

        case .denied:
            screenshots.removeAll()
            permissionMessage =
                "Photo access is denied. Allow access in Settings to scan your photos."
            isLoading = false

        case .restricted:
            screenshots.removeAll()
            permissionMessage = "Photo access is restricted on this device."
            isLoading = false

        case .notDetermined:
            screenshots.removeAll()
            permissionMessage = "Photo access is required to scan screenshots."
            isLoading = false

        @unknown default:
            screenshots.removeAll()
            permissionMessage = "Unable to determine photo access."
            isLoading = false
        }
    }

    private func fetchScreenshots() {

        let photosService = self.photosService

        Task {
            let fetched = await Task.detached(priority: .userInitiated) {
                photosService.fetchScreenshots()
            }.value

            await MainActor.run {
                self.screenshots = fetched
                self.isLoading = false
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

    func selectAll() {
        selectedIDs = Set(screenshots.map(\.localIdentifier))
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    // MARK: - Deletion

    func deleteSelected() async {

        let identifiers = selectedAssets.map(\.localIdentifier)

        guard !identifiers.isEmpty else {
            return
        }

        do {
            try await deletionService.delete(identifiers: identifiers)

            selectedIDs.removeAll()
            loadScreenshots()

        } catch {
            errorMessage = "Failed to delete screenshots: \(error.localizedDescription)"
        }
    }
}