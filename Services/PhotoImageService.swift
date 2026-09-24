import Foundation
import Photos
import UIKit

final class PhotoImageService {

    private let imageManager = PHCachingImageManager()

    func requestThumbnail(
        for asset: PHAsset,
        size: CGSize
    ) async -> UIImage? {

        await withCheckedContinuation { continuation in

            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false

            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in

                continuation.resume(
                    returning: image
                )
            }
        }
    }
}