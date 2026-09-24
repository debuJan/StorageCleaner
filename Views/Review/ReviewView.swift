import SwiftUI
import Photos
import UIKit

struct ReviewView: View {
    let assets: [PHAsset]
    let title: String
    var estimatedBytes: Int64? = nil

    var onConfirm: () async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var thumbnails: [String: UIImage] = [:]

    private let imageService = PhotoImageService()

    private let columns = [
        GridItem(.adaptive(minimum: 90), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 16) {

            // MARK: - Summary

            Text("Review Before Deleting")
                .font(.title2)
                .fontWeight(.bold)

            Text("\(assets.count) items selected")
                .font(.headline)

            if let estimatedBytes, estimatedBytes > 0 {
                VStack(spacing: 4) {
                    Text("Estimated space to free")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(formatBytes(estimatedBytes))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }

            // MARK: - Selected Items

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(assets, id: \.localIdentifier) { asset in

                        ZStack(alignment: .bottomTrailing) {

                            Group {
                                if let image = thumbnails[asset.localIdentifier] {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Color.gray.opacity(0.2)
                                        .overlay {
                                            ProgressView()
                                        }
                                }
                            }
                            .frame(width: 90, height: 90)
                            .clipped()

                            if asset.mediaType == .video {
                                Image(systemName: "play.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(.black.opacity(0.7))
                                    .clipShape(Circle())
                                    .padding(6)
                            }
                        }
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 300)

            // MARK: - Error

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            // MARK: - Warning

            VStack(spacing: 6) {
                Text("These items will be permanently deleted.")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Make sure you have reviewed everything before confirming.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // MARK: - Confirm

            Button {
                guard !isDeleting else { return }

                isDeleting = true
                errorMessage = nil

                Task {
                    do {
                        try await onConfirm()

                        await MainActor.run {
                            isDeleting = false
                            dismiss()
                        }

                    } catch {
                        await MainActor.run {
                            isDeleting = false
                            errorMessage = "Failed to delete selected items: \(error.localizedDescription)"
                        }
                    }
                }

            } label: {
                if isDeleting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Confirm Delete")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isDeleting || assets.isEmpty)

            // MARK: - Cancel

            Button("Cancel") {
                dismiss()
            }
            .disabled(isDeleting)
        }
        .padding()
        .navigationTitle(title)
        .task {
            await loadThumbnails()
        }
    }

    // MARK: - Thumbnails

    private func loadThumbnails() async {

        for asset in assets {

            let id = asset.localIdentifier

            guard thumbnails[id] == nil else { continue }

            let image = await imageService.requestThumbnail(
                for: asset,
                size: CGSize(width: 180, height: 180)
            )

            if let image {
                await MainActor.run {
                    thumbnails[id] = image
                }
            }
        }
    }

    // MARK: - Formatting

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(
            fromByteCount: bytes,
            countStyle: .file
        )
    }
}