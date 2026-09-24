import Foundation
import Photos

final class PhotosService {

    // MARK: - Permission

    func requestPhotoAccess() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func authorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    var hasPhotoAccess: Bool {
        let status = authorizationStatus()
        return status == .authorized || status == .limited
    }

    var isLimitedAccess: Bool {
        authorizationStatus() == .limited
    }

    // MARK: - Screenshots

    func fetchScreenshots() -> [PHAsset] {
        let options = PHFetchOptions()

        options.sortDescriptors = [
            NSSortDescriptor(
                key: "creationDate",
                ascending: false
            )
        ]

        options.predicate = NSPredicate(
            format: "mediaSubtype == %d",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )

        let result = PHAsset.fetchAssets(
            with: .image,
            options: options
        )

        var assets: [PHAsset] = []

        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        return assets
    }

    // MARK: - Videos

    func fetchVideos() -> [PHAsset] {
        let options = PHFetchOptions()

        options.sortDescriptors = [
            NSSortDescriptor(
                key: "creationDate",
                ascending: false
            )
        ]

        let result = PHAsset.fetchAssets(
            with: .video,
            options: options
        )

        var assets: [PHAsset] = []

        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        return assets
    }

    func fetchLargeVideos() async -> [LargeVideo] {
        let options = PHFetchOptions()

        options.sortDescriptors = [
            NSSortDescriptor(
                key: "creationDate",
                ascending: false
            )
        ]

        let result = PHAsset.fetchAssets(
            with: .video,
            options: options
        )

        var largeVideos: [LargeVideo] = []

        result.enumerateObjects { asset, _, _ in

            let resources = PHAssetResource.assetResources(for: asset)

            let videoResource =
                resources.first { $0.type == .fullSizeVideo }
                ?? resources.first { $0.type == .video }

            let size = (videoResource?.value(forKey: "fileSize") as? Int64) ?? 0

            largeVideos.append(
                LargeVideo(
                    asset: asset,
                    size: size
                )
            )
        }

        return largeVideos.sorted {
            $0.size > $1.size
        }
    }

    // MARK: - Similar Photos

    func fetchPhotosForSimilarity() -> [PHAsset] {
        let options = PHFetchOptions()

        options.sortDescriptors = [
            NSSortDescriptor(
                key: "creationDate",
                ascending: true
            )
        ]

        let result = PHAsset.fetchAssets(
            with: .image,
            options: options
        )

        var assets: [PHAsset] = []

        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        return assets
    }
}