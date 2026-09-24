import Foundation

struct HammingDistance {

    static func calculate(
        _ first: UInt64,
        _ second: UInt64
    ) -> Int {
        (first ^ second).nonzeroBitCount
    }
}