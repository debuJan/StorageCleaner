import SwiftUI
import Photos
import UIKit

struct ScreenshotsView: View {
    @State private var viewModel = ScreenshotsViewModel()
    @State private var estimatedBytes: Int64 = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                if viewModel.isLoading {
                    ProgressView("Scanning screenshots...")
                        .padding()
                }

                // Permission state
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

                // Error state
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                // Empty state
                if viewModel.screenshots.isEmpty &&
                    !viewModel.isLoading &&
                    viewModel.permissionMessage == nil {

                    ContentUnavailableView(
                        "No Screenshots Found",
                        systemImage: "photo.on.rectangle",
                        description: Text("No screenshots were found in your accessible photo library.")
                    )
                    .padding(.vertical, 40)
                }

                // Screenshot count and Select All
                if !viewModel.screenshots.isEmpty {
                    HStack {
                        Text("\(viewModel.screenshots.count) Screenshots")
                            .font(.headline)

                        Spacer()

                        Button("Select All") {
                            viewModel.selectAll()
                        }
                    }
                }

                // Screenshot grid
                if !viewModel.screenshots.isEmpty {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 8
                    ) {
                        ForEach(viewModel.screenshots, id: \.localIdentifier) { asset in
                            ScreenshotThumbnail(
                                asset: asset,
                                isSelected: viewModel.selectedIDs.contains(asset.localIdentifier)
                            ) {
                                viewModel.toggleSelection(asset)
                            }
                        }
                    }
                }

                // Review selected
                if !viewModel.selectedIDs.isEmpty {
                    NavigationLink {
                        ReviewView(
                            assets: viewModel.selectedAssets,
                            title: "Screenshots",
                            estimatedBytes: estimatedBytes
                        ) {
                            await viewModel.deleteSelected()
                        }
                    } label: {
                        Text("Review \(viewModel.selectedIDs.count) Selected")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .navigationTitle("Screenshots")
        .task {
            loadIfNeeded()
        }
        .task(id: viewModel.selectedIDs) {
            estimatedBytes = await computeEstimatedBytes()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func loadIfNeeded() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        if status == .notDetermined {
            Task {
                _ = await viewModel.photosService.requestPhotoAccess()
                viewModel.loadScreenshots()
            }
        } else {
            viewModel.loadScreenshots()
        }
    }

    private func computeEstimatedBytes() async -> Int64 {
        let selected = viewModel.selectedAssets

        return await Task.detached(priority: .userInitiated) {
            selected.reduce(Int64(0)) { total, asset in
                let resources = PHAssetResource.assetResources(for: asset)
                let resource = resources.first { $0.type == .fullSizePhoto }
                    ?? resources.first { $0.type == .photo }
                let size = (resource?.value(forKey: "fileSize") as? Int64) ?? 0
                return total + size
            }
        }.value
    }
}

// MARK: - Thumbnail

struct ScreenshotThumbnail: View {
    let asset: PHAsset
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