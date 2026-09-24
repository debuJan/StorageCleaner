import Foundation
import Observation
import Photos
import Contacts

@Observable
final class DashboardViewModel {

    var usedStorage: Int64 = 0
    var totalStorage: Int64 = 0
    var isLoading = true

    var freeStorage: Int64 {
        max(totalStorage - usedStorage, 0)
    }

    var usagePercentage: Double {
        guard totalStorage > 0 else {
            return 0
        }

        return Double(usedStorage) / Double(totalStorage)
    }

    var categories: [StorageCategory] = []
    var duplicateContactCount: Int = 0

    private let photosService = PhotosService()
    private let contactsService = ContactsService()

    init() {
        loadStorage()
    }

    // MARK: - Storage

    func loadStorage() {
        isLoading = true

        Task {
            await loadDeviceStorage()
            await loadCategoryEstimates()
            await loadDuplicateContactCount()

            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func loadDeviceStorage() async {

        let homeURL = URL(fileURLWithPath: NSHomeDirectory())

        do {
            let values = try homeURL.resourceValues(
                forKeys: [
                    .volumeTotalCapacityKey,
                    .volumeAvailableCapacityForImportantUsageKey
                ]
            )

            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)

            await MainActor.run {
                self.totalStorage = total
                self.usedStorage = max(total - available, 0)
            }

        } catch {
            await MainActor.run {
                self.totalStorage = 0
                self.usedStorage = 0
            }
        }
    }

    // MARK: - Category Estimates (device storage only)

    private func loadCategoryEstimates() async {

        var screenshotBytes: Int64 = 0
        var videoBytes: Int64 = 0

        let status = photosService.authorizationStatus()

        if status == .authorized || status == .limited {

            let screenshots = photosService.fetchScreenshots()
            screenshotBytes = await estimatePhotoSize(assets: screenshots)

            let videos = await photosService.fetchLargeVideos()
            videoBytes = videos.reduce(0) { $0 + $1.size }
        }

        let newCategories = [
            StorageCategory(
                name: "Screenshots",
                usedBytes: screenshotBytes,
                icon: "camera.viewfinder"
            ),
            StorageCategory(
                name: "Videos",
                usedBytes: videoBytes,
                icon: "video.fill"
            )
        ]

        await MainActor.run {
            self.categories = newCategories
        }
    }

    // MARK: - Photo Size

    private func estimatePhotoSize(assets: [PHAsset]) async -> Int64 {

        guard !assets.isEmpty else {
            return 0
        }

        return await Task.detached(priority: .utility) {

            assets.reduce(Int64(0)) { total, asset in

                let resources = PHAssetResource.assetResources(for: asset)

                let resource = resources.first { $0.type == .fullSizePhoto }
                    ?? resources.first { $0.type == .photo }

                let size = (resource?.value(forKey: "fileSize") as? Int64) ?? 0

                return total + size
            }

        }.value
    }

    // MARK: - Duplicate Contacts (count, not bytes — not a storage category)

    private func loadDuplicateContactCount() async {

        let status = contactsService.authorizationStatus()

        guard status == .authorized else {
            await MainActor.run { self.duplicateContactCount = 0 }
            return
        }

        let contactsService = self.contactsService

        let count = await Task.detached(priority: .utility) { () -> Int in
            guard let contacts = try? contactsService.fetchContacts() else {
                return 0
            }

            var seen = Set<String>()
            var duplicates = 0

            for contact in contacts {
                let phone = contact.phoneNumbers.first?.value.stringValue
                    .filter { $0.isNumber } ?? ""
                let email = contact.emailAddresses.first?.value.lowercased() ?? ""
                let name = "\(contact.givenName) \(contact.familyName)"
                    .lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let key = !phone.isEmpty ? "phone:\(phone)"
                    : !email.isEmpty ? "email:\(email)"
                    : "name:\(name)"

                if !key.isEmpty {
                    if seen.contains(key) {
                        duplicates += 1
                    } else {
                        seen.insert(key)
                    }
                }
            }

            return duplicates
        }.value

        await MainActor.run {
            self.duplicateContactCount = count
        }
    }
}