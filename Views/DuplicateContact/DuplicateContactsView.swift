import SwiftUI
import Contacts
import UIKit

struct DuplicateContactsView: View {
    @State private var viewModel = DuplicateContactsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // MARK: - Scanning

                if viewModel.isScanning {
                    ProgressView("Scanning contacts...")
                        .padding()
                }

                // MARK: - Permission

                if let permissionMessage = viewModel.permissionMessage {

                    VStack(spacing: 10) {

                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.largeTitle)

                        Text(permissionMessage)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        Button("Open Settings") {
                            openSettings()
                        }
                        .buttonStyle(.bordered)
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

                if viewModel.groups.isEmpty &&
                    !viewModel.isScanning &&
                    viewModel.permissionMessage == nil {

                    ContentUnavailableView(
                        "No Duplicate Contacts",
                        systemImage: "person.2",
                        description: Text("No duplicate contacts were found.")
                    )
                    .padding(.vertical, 40)
                }

                // MARK: - Groups

                ForEach(viewModel.groups) { group in
                    DuplicateContactGroupView(
                        group: group,
                        selectedIDs: viewModel.selectedIDs,
                        onSelect: {
                            viewModel.selectDuplicates(in: group)
                        },
                        onToggle: { contact in
                            viewModel.toggleSelection(contact)
                        }
                    )
                }

                // MARK: - Selection

                if !viewModel.selectedIDs.isEmpty {

                    VStack(spacing: 8) {

                        Text("\(viewModel.selectedIDs.count) contacts selected")
                            .font(.headline)

                        Text("Review selected contacts before deleting.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        NavigationLink {
                            ContactReviewView(
                                contacts: viewModel.groups
                                    .flatMap(\.contacts)
                                    .filter {
                                        viewModel.selectedIDs.contains($0.identifier)
                                    }
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
        .navigationTitle("Duplicate Contacts")

        // MARK: - Toolbar

        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Scan") {
                    requestAccessAndScan()
                }
            }
        }

        // MARK: - Initial Load

        .task {
            requestAccessAndScan()
        }
    }

    // MARK: - Permission

    private func requestAccessAndScan() {

        let status = viewModel.contactsService.authorizationStatus()

        switch status {

        case .notDetermined:
            Task {
                do {
                    _ = try await viewModel.contactsService.requestAccess()
                    viewModel.scan()

                } catch {
                    viewModel.errorMessage = error.localizedDescription
                }
            }

        case .authorized:
            viewModel.scan()

        case .denied, .restricted:
            viewModel.permissionMessage =
                "Contacts access is required. Enable it in Settings to find duplicate contacts."

        @unknown default:
            viewModel.permissionMessage = "Unable to determine Contacts access."
        }
    }

    // MARK: - Settings

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }
}

// MARK: - Contact Group

struct DuplicateContactGroupView: View {

    let group: DuplicateContactGroup
    let selectedIDs: Set<String>

    let onSelect: () -> Void
    let onToggle: (CNContact) -> Void

    var body: some View {

        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text("\(group.contacts.count) Similar Contacts")
                    .font(.headline)

                Spacer()

                Button("Select Duplicates") {
                    onSelect()
                }
                .font(.subheadline)
            }

            ForEach(group.contacts, id: \.identifier) { contact in
                Button {
                    onToggle(contact)
                } label: {
                    HStack {
                        Image(
                            systemName: selectedIDs.contains(contact.identifier)
                                ? "checkmark.circle.fill"
                                : "circle"
                        )

                        VStack(alignment: .leading) {
                            Text(contactName(contact))
                                .font(.headline)

                            if let phone = contact.phoneNumbers.first {
                                Text(phone.value.stringValue)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let email = contact.emailAddresses.first {
                                Text(email.value as String)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding()
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func contactName(_ contact: CNContact) -> String {
        let name = "\(contact.givenName) \(contact.familyName)"
            .trimmingCharacters(in: .whitespaces)

        return name.isEmpty ? "Unnamed Contact" : name
    }
}