import Foundation
import Contacts
import Observation

@MainActor
@Observable
final class DuplicateContactsViewModel {

    let contactsService = ContactsService()
    private let deletionService = ContactDeletionService()

    var groups: [DuplicateContactGroup] = []
    var selectedIDs: Set<String> = []

    var isScanning = false
    var errorMessage: String?
    var permissionMessage: String?

    var hasContactAccess: Bool {
        contactsService.hasAccess
    }

    // MARK: - Scan

    func scan() {

        isScanning = true
        errorMessage = nil
        permissionMessage = nil

        groups.removeAll()
        selectedIDs.removeAll()

        let status = contactsService.authorizationStatus()

        switch status {

        case .authorized:
            startScan()

        case .denied:
            permissionMessage =
                "Contacts access is denied. Allow access in Settings to find duplicate contacts."
            isScanning = false

        case .restricted:
            permissionMessage =
                "Contacts access is restricted on this device."
            isScanning = false

        case .notDetermined:
            permissionMessage =
                "Contacts access is required to scan your contacts."
            isScanning = false

        @unknown default:
            permissionMessage =
                "Unable to determine Contacts access."
            isScanning = false
        }
    }

    private func startScan() {

        let contactsService = self.contactsService

        Task {

            do {

                let contacts =
                    try await Task.detached(
                        priority: .userInitiated
                    ) {
                        try contactsService.fetchContacts()
                    }.value

                var grouped:
                    [String: [CNContact]] = [:]

                for contact in contacts {

                    let key =
                        normalizedKey(
                            for: contact
                        )

                    guard !key.isEmpty else {
                        continue
                    }

                    grouped[
                        key,
                        default: []
                    ]
                    .append(contact)
                }

                groups =
                    grouped.values
                        .filter {
                            $0.count > 1
                        }
                        .map {
                            DuplicateContactGroup(
                                contacts: $0
                            )
                        }

                isScanning = false

            } catch {

                errorMessage =
                    "Failed to scan contacts: \(error.localizedDescription)"

                isScanning = false
            }
        }
    }

    // MARK: - Duplicate Detection

    private func normalizedKey(
        for contact: CNContact
    ) -> String {

        let name =
            "\(contact.givenName) \(contact.familyName)"
                .lowercased()
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        let phone =
            contact.phoneNumbers
                .first?
                .value
                .stringValue
                .filter {
                    $0.isNumber
                } ?? ""

        let email =
            contact.emailAddresses
                .first?
                .value
                .lowercased() ?? ""

        if !phone.isEmpty {
            return "phone:\(phone)"
        }

        if !email.isEmpty {
            return "email:\(email)"
        }

        return "name:\(name)"
    }

    // MARK: - Selection

    func toggleSelection(
        _ contact: CNContact
    ) {

        let id =
            contact.identifier

        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func selectDuplicates(
        in group: DuplicateContactGroup
    ) {

        for contact in group.contacts.dropFirst() {

            selectedIDs.insert(
                contact.identifier
            )
        }
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    // MARK: - Deletion

    func deleteSelected() async {

        let contacts =
            groups
                .flatMap(\.contacts)
                .filter {
                    selectedIDs.contains(
                        $0.identifier
                    )
                }

        guard !contacts.isEmpty else {
            return
        }

        let deletionService =
            self.deletionService

        do {

            try await Task.detached(
                priority: .userInitiated
            ) {
                try deletionService.delete(
                    contacts: contacts
                )
            }.value

            selectedIDs.removeAll()
            scan()

        } catch {

            errorMessage =
                "Failed to delete contacts: \(error.localizedDescription)"
        }
    }
}