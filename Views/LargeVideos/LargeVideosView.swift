import SwiftUI
import Photos
import UIKit

struct LargeVideosView: View {
    @State private var viewModel = LargeVideosViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                if viewModel.isLoading {
                    ProgressView("Scanning videos...")
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

                if viewModel.videos.isEmpty &&
                    !viewModel.isLoading &&
                    viewModel.permissionMessage == nil {

                    ContentUnavailableView(
                        "No Videos Found",
                        systemImage: "video",
                        description: Text("No videos were found in your accessible photo library.")
                    )
                    .padding(.vertical, 40)
                }

                // MARK: - Video Count

                if !viewModel.videos.isEmpty {
                    HStack {
                        Text("\(viewModel.videos.count) Videos")
                            .font(.headline)

                        Spacer()

                        Button("Select All") {
                            viewModel.selectAll()
                        }
                    }
                }

                // MARK: - Video List

                if !viewModel.videos.isEmpty {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.videos, id: \.asset.localIdentifier) { video in
                            LargeVideoRow(
                                video: video,
                                isSelected: viewModel.selectedIDs.contains(video.asset.localIdentifier)
                            ) {
                                viewModel.toggleSelection(video)
                            }
                        }
                    }
                }

                // MARK: - Review

                if !viewModel.selectedIDs.isEmpty {
                    VStack(spacing: 8) {

                        Text("Selected: \(formatBytes(viewModel.selectedSize))")
                            .font(.headline)

                        NavigationLink {
                            ReviewView(
                                assets: viewModel.selectedVideos.map(\.asset),
                                title: "Large Videos",
                                estimatedBytes: viewModel.selectedSize
                            ) {
                                await viewModel.deleteSelected()
                            }
                        } label: {
                            Text("Review \(viewModel.selectedIDs.count) Selected")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top)
                }
            }
            .padding()
        }
        .navigationTitle("Large Videos")
        .task {
            loadVideos()
        }
    }

    // MARK: - Loading

    private func loadVideos() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        if status == .notDetermined {
            Task {
                _ = await viewModel.photosService.requestPhotoAccess()
                viewModel.loadVideos()
            }
        } else {
            viewModel.loadVideos()
        }
    }

    // MARK: - Settings

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(
            fromByteCount: bytes,
            countStyle: .file
        )
    }
}

// MARK: - Video Row

struct LargeVideoRow: View {
    let video: LargeVideo
    let isSelected: Bool
    let onTap: () -> Void

    @State private var thumbnail: UIImage?
    private let imageService = PhotoImageService()

    var body: some View {
        Button(action: onTap) {

            HStack(spacing: 12) {

                ZStack(alignment: .bottomTrailing) {

                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.2)
                            .overlay {
                                ProgressView()
                            }
                    }

                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.7))
                        .clipShape(Circle())
                        .padding(6)
                }
                .frame(width: 90, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Video")
                        .font(.headline)

                    Text(
                        ByteCountFormatter.string(
                            fromByteCount: video.size,
                            countStyle: .file
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .task {
            guard thumbnail == nil else { return }

            thumbnail = await imageService.requestThumbnail(
                for: video.asset,
                size: CGSize(width: 180, height: 140)
            )
        }
    }
}