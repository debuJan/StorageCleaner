import Foundation
import Contacts

struct DuplicateContactGroup: Identifiable {
    let id = UUID()
    let contacts: [CNContact]
}