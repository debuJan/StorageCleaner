import SwiftUI
import Photos
import UIKit

struct SimilarPhotosView: View {
    @State private var viewModel = SimilarPhotosViewModel()
    @State private var estimatedBytes: Int64 = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // MARK: - Scanning

                if viewModel.isScanning {
                    VStack(spacing: 8) {
                        ProgressView("Scanning photos...")

                        ProgressView(value: viewModel.progress)

                        Text("\(Int(viewModel.progress * 100))% complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                // MARK: - Permission

                if let permissionMessage = viewModel.permissionMessage {

                    VStack(spacing: 10) {
                        Image(
                            systemName: viewModel.isLimitedAccess
                                ? "photo.badge.exclamationmark"
                                : "lock.shield"
                        )
                        .font(.largeTitle)

                        Text(permissionMessage)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        if !viewModel.isLimitedAccess {
                            Button("Open Settings") {
                                openSettings()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // MARK: - Error

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                // MARK: - Empty State

                if viewModel.hasScanned &&
                    viewModel.groups.isEmpty &&
                    !viewModel.isScanning &&
                    viewModel.permissionMessage == nil {

                    ContentUnavailableView(
                        "No Similar Photos Found",
                        systemImage: "photo.on.rectangle",
                        description: Text("No similar photos were found in your accessible photo library.")
                    )
                    .padding(.vertical, 40)
                }

                // MARK: - Similar Groups

                ForEach(viewModel.groups) { group in
                    SimilarPhotoGroupView(
                        group: group,
                        selectedIDs: viewModel.selectedIDs,
                        onSelect: {
                            viewModel.selectGroupForDeletion(group)
                        },
                        onToggle: { asset in
                            viewModel.toggleSelection(asset)
                        }
                    )
                }

                // MARK: - Selection

                if !viewModel.selectedIDs.isEmpty {
                    VStack(spacing: 8) {

                        Text("\(viewModel.selectedIDs.count) photos selected")
                            .font(.headline)

                        if estimatedBytes > 0 {
                            Text("\(formatBytes(estimatedBytes)) can be freed")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        NavigationLink {
                            ReviewView(
                                assets: viewModel.groups
                                    .flatMap(\.assets)
                                    .filter {
                                        viewModel.selectedIDs.contains($0.localIdentifier)
                                    },
                                title: "Similar Photos",
                                estimatedBytes: estimatedBytes
                            ) {
                                await viewModel.deleteSelected()
                            }
                        } label: {
                            Text("Review Selected")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Similar Photos")

        // MARK: - Scan Button

        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Scan") {
                    requestAccessAndScan()
                }
            }
        }

        // MARK: - Estimated Size

        .task(id: viewModel.selectedIDs) {
            estimatedBytes = await computeEstimatedBytes()
        }
    }

    // MARK: - Permission

    private func requestAccessAndScan() {

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {

        case .notDetermined:
            Task {
                _ = await viewModel.photosService.requestPhotoAccess()
                viewModel.scan()
            }

        case .authorized, .limited:
            viewModel.scan()

        case .denied, .restricted:
            viewModel.permissionMessage =
                "Photo access is required. Enable it in Settings to scan for similar photos."

        @unknown default:
            viewModel.permissionMessage = "Unable to determine Photos access."
        }
    }

    // MARK: - Settings

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }

    // MARK: - Estimated Size

    private func computeEstimatedBytes() async -> Int64 {

        let selectedAssets = viewModel.groups
            .flatMap(\.assets)
            .filter { viewModel.selectedIDs.contains($0.localIdentifier) }

        return await Task.detached(priority: .userInitiated) {
            selectedAssets.reduce(Int64(0)) { total, asset in

                let resources = PHAssetResource.assetResources(for: asset)

                let resource = resources.first { $0.type == .fullSizePhoto }
                    ?? resources.first { $0.type == .photo }

                let size = (resource?.value(forKey: "fileSize") as? Int64) ?? 0

                return total + size
            }
        }.value
    }

    // MARK: - Formatting

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(
            fromByteCount: bytes,
            countStyle: .file
        )
    }
}

// MARK: - Similar Photo Group

struct SimilarPhotoGroupView: View {

    let group: SimilarPhotoGroup
    let selectedIDs: Set<String>

    let onSelect: () -> Void
    let onToggle: (PHAsset) -> Void

    var body: some View {

        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text("\(group.assets.count) Similar Photos")
                    .font(.headline)

                Spacer()

                Button("Select Others") {
                    onSelect()
                }
                .font(.subheadline)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 8
            ) {
                ForEach(group.assets, id: \.localIdentifier) { asset in
                    SimilarPhotoThumbnail(
                        asset: asset,
                        isRecommended: asset.localIdentifier == group.recommendedAssetID,
                        isSelected: selectedIDs.contains(asset.localIdentifier)
                    ) {
                        onToggle(asset)
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Thumbnail

struct SimilarPhotoThumbnail: View {

    let asset: PHAsset
    let isRecommended: Bool
    let isSelected: Bool

    let onTap: () -> Void

    @State private var image: UIImage?

    private let imageService = PhotoImageService()

    var body: some View {

        Button(action: onTap) {

            ZStack(alignment: .topTrailing) {

                Group {
                    if let image {
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
                .aspectRatio(1, contentMode: .fill)
                .clipped()

                if isRecommended {
                    Text("KEEP")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(5)
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(4)
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, .blue)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            guard image == nil else { return }

            image = await imageService.requestThumbnail(
                for: asset,
                size: CGSize(width: 200, height: 200)
            )
        }
    }
}