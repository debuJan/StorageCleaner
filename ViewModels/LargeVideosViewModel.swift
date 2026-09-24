import Foundation
import Photos
import Observation

struct LargeVideo {
    let asset: PHAsset
    let size: Int64
}

@Observable
final class LargeVideosViewModel {

    let photosService = PhotosService()
    private let deletionService = PhotoDeletionService()

    var videos: [LargeVideo] = []
    var selectedIDs: Set<String> = []

    var isLoading = false
    var errorMessage: String?
    var permissionMessage: String?

    var isLimitedAccess: Bool {
        photosService.isLimitedAccess
    }

    var selectedVideos: [LargeVideo] {
        videos.filter {
            selectedIDs.contains($0.asset.localIdentifier)
        }
    }

    var selectedSize: Int64 {
        selectedVideos.reduce(0) { $0 + $1.size }
    }

    // MARK: - Loading

    func loadVideos() {

        isLoading = true
        errorMessage = nil
        permissionMessage = nil

        let status = photosService.authorizationStatus()

        switch status {

        case .authorized:
            fetchVideos()

        case .limited:
            permissionMessage =
                "Photo access is limited. Only accessible videos will be shown."
            fetchVideos()

        case .denied:
            videos.removeAll()
            permissionMessage =
                "Photo access is denied. Allow access in Settings to scan your videos."
            isLoading = false

        case .restricted:
            videos.removeAll()
            permissionMessage = "Photo access is restricted on this device."
            isLoading = false

        case .notDetermined:
            videos.removeAll()
            permissionMessage = "Photo access is required to scan videos."
            isLoading = false

        @unknown default:
            videos.removeAll()
            permissionMessage = "Unable to determine photo access."
            isLoading = false
        }
    }

    private func fetchVideos() {

        Task {
            let fetchedVideos = await photosService.fetchLargeVideos()

            await MainActor.run {
                self.videos = fetchedVideos
                self.isLoading = false
            }
        }
    }

    // MARK: - Selection

    func toggleSelection(_ video: LargeVideo) {

        let id = video.asset.localIdentifier

        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func selectAll() {
        selectedIDs = Set(videos.map { $0.asset.localIdentifier })
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    // MARK: - Deletion

    func deleteSelected() async {

        let identifiers = selectedVideos.map { $0.asset.localIdentifier }

        guard !identifiers.isEmpty else {
            return
        }

        do {
            try await deletionService.delete(identifiers: identifiers)

            selectedIDs.removeAll()
            loadVideos()

        } catch {
            errorMessage = "Failed to delete videos: \(error.localizedDescription)"
        }
    }
}