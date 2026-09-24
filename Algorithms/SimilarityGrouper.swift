import Foundation

struct SimilarityGrouper {

    struct HashedAsset {
        let id: String
        let hash: UInt64
        let creationDate: Date
    }

    static func group(
        assets: [HashedAsset],
        threshold: Int = 8,
        timeWindow: TimeInterval = 300 // 5 minutes
    ) -> [[String]] {

        let sorted = assets.sorted { $0.creationDate < $1.creationDate }

        var groups: [[String]] = []
        var used = Set<String>()

        for (index, item) in sorted.enumerated() {
            if used.contains(item.id) {
                continue
            }

            var group = [item.id]
            used.insert(item.id)

            var nextIndex = index + 1
            while nextIndex < sorted.count {
                let other = sorted[nextIndex]

                if other.creationDate.timeIntervalSince(item.creationDate) > timeWindow {
                    break
                }

                if !used.contains(other.id) {
                    let distance = HammingDistance.calculate(item.hash, other.hash)
                    if distance <= threshold {
                        group.append(other.id)
                        used.insert(other.id)
                    }
                }

                nextIndex += 1
            }

            if group.count > 1 {
                groups.append(group)
            }
        }

        return groups
    }
}