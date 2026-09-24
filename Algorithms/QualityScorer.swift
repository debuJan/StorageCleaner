import Foundation
import Photos

struct QualityScorer {

    static func score(
        asset: PHAsset,
        fileSize: Int64 = 0
    ) -> Double {

        var score = 0.0

        // Higher resolution = better candidate to keep
        let pixelCount = Double(
            asset.pixelWidth * asset.pixelHeight
        )

        score += min(
            pixelCount / 10_000_000,
            1.0
        ) * 0.5

        // Favorited photos are safer candidates to keep
        if asset.isFavorite {
            score += 0.3
        }

        // Slight preference for larger files when quality is otherwise similar
        if fileSize > 0 {
            score += min(
                Double(fileSize) / 50_000_000,
                1.0
            ) * 0.2
        }

        return score
    }
}