import Foundation
import Contacts

final class ContactDeletionService {

    enum DeletionError: Error {
        case invalidContact
    }

    private let store = CNContactStore()

    func delete(contacts: [CNContact]) throws {
        guard !contacts.isEmpty else { return }

        let saveRequest = CNSaveRequest()

        for contact in contacts {
            guard let mutableContact = contact.mutableCopy() as? CNMutableContact else {
                throw DeletionError.invalidContact
            }

            saveRequest.delete(mutableContact)
        }

        try store.execute(saveRequest)
    }
}