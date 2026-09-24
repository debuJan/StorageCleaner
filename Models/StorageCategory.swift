import Foundation

struct StorageCategory: Identifiable {
    let id = UUID()
    let name: String
    let usedBytes: Int64
    let icon: String
}