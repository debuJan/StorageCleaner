import Foundation
import Photos

final class PhotoDeletionService {

    enum DeletionError: Error {
        case assetsNotFound
    }

    func delete(identifiers: [String]) async throws {
        guard !identifiers.isEmpty else { return }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)

        guard fetchResult.count > 0 else {
            throw DeletionError.assetsNotFound
        }

        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
    }
}