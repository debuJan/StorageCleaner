import Foundation
import Contacts

final class ContactsService {

    private let store = CNContactStore()

    // MARK: - Permission

    func requestAccess() async throws -> Bool {
        try await store.requestAccess(for: .contacts)
    }

    func authorizationStatus() -> CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    var hasAccess: Bool {
        authorizationStatus() == .authorized
    }

    // MARK: - Fetch Contacts

    func fetchContacts() throws -> [CNContact] {

        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]

        let request = CNFetchRequest<CNContact>(
            keysToFetch: keys
        )

        var contacts: [CNContact] = []

        try store.enumerateContacts(
            with: request
        ) { contact, _ in
            contacts.append(contact)
        }

        return contacts
    }
}