import Foundation
import UIKit

struct PerceptualHash {

    static func hash(_ image: UIImage) -> UInt64? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        let size = 8

        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium

        context.draw(
            cgImage,
            in: CGRect(
                x: 0,
                y: 0,
                width: size,
                height: size
            )
        )

        guard let data = context.data else {
            return nil
        }

        let pixelCount = size * size

        let buffer = data.bindMemory(
            to: UInt8.self,
            capacity: pixelCount
        )

        var total: UInt64 = 0

        for index in 0..<pixelCount {
            total += UInt64(buffer[index])
        }

        let average = total / UInt64(pixelCount)

        var hash: UInt64 = 0

        for index in 0..<pixelCount {
            if UInt64(buffer[index]) >= average {
                hash |= UInt64(1) << UInt64(index)
            }
        }

        return hash
    }

    static func hammingDistance(
        _ first: UInt64,
        _ second: UInt64
    ) -> Int {
        (first ^ second).nonzeroBitCount
    }
}