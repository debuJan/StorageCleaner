import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: - Header

                    VStack(spacing: 8) {
                        Text("Storage Cleaner")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Free up space on your iPhone")
                            .foregroundStyle(.secondary)
                    }

                    // MARK: - Storage

                    VStack(spacing: 12) {
                        Text("iPhone Storage")
                            .font(.headline)

                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("\(formatBytes(viewModel.usedStorage)) used")
                                .font(.title2)
                                .fontWeight(.semibold)

                            ProgressView(value: viewModel.usagePercentage)
                                .padding(.horizontal)

                            HStack {
                                Text("\(formatBytes(viewModel.freeStorage)) free")

                                Spacer()

                                Text("\(formatBytes(viewModel.totalStorage)) total")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // MARK: - Categories

                    if !viewModel.categories.isEmpty || viewModel.duplicateContactCount > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Storage Categories")
                                .font(.headline)

                            ForEach(viewModel.categories) { category in
                                StorageCategoryRow(category: category)
                            }

                            if viewModel.duplicateContactCount > 0 {
                                DuplicateContactsSummaryRow(
                                    count: viewModel.duplicateContactCount
                                )
                            }
                        }
                    }

                    // MARK: - Features

                    VStack(spacing: 12) {
                        NavigationLink("Similar Photos") {
                            SimilarPhotosView()
                        }
                        .buttonStyle(.borderedProminent)

                        NavigationLink("Screenshots") {
                            ScreenshotsView()
                        }
                        .buttonStyle(.borderedProminent)

                        NavigationLink("Large Videos") {
                            LargeVideosView()
                        }
                        .buttonStyle(.borderedProminent)

                        NavigationLink("Duplicate Contacts") {
                            DuplicateContactsView()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Cleaner")
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(
            fromByteCount: bytes,
            countStyle: .file
        )
    }
}

// MARK: - Category Row

struct StorageCategoryRow: View {
    let category: StorageCategory

    var body: some View {
        HStack(spacing: 12) {

            Image(systemName: category.icon)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)

                Text(
                    category.usedBytes > 0
                        ? "\(formatBytes(category.usedBytes)) estimated"
                        : "No estimated space"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if category.usedBytes > 0 {
                Text(formatBytes(category.usedBytes))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(
            fromByteCount: bytes,
            countStyle: .file
        )
    }
}

// MARK: - Duplicate Contacts Row

struct DuplicateContactsSummaryRow: View {
    let count: Int

    var body: some View {
        HStack(spacing: 12) {

            Image(systemName: "person.2.fill")
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("Duplicate Contacts")
                    .font(.headline)

                Text("\(count) possible duplicates found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}