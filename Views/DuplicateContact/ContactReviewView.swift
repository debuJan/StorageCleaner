import SwiftUI
import Contacts

struct ContactReviewView: View {

    let contacts: [CNContact]

    var onConfirm: () async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {

        VStack(spacing: 16) {

            Text("Review Before Deleting")
                .font(.title2)
                .fontWeight(.bold)

            Text(
                "\(contacts.count) contacts selected"
            )
            .font(.headline)

            List {
                ForEach(
                    contacts,
                    id: \.identifier
                ) { contact in

                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {

                        Text(
                            contactName(contact)
                        )
                        .font(.headline)

                        if let phone =
                            contact.phoneNumbers.first {

                            Text(
                                phone.value.stringValue
                            )
                            .font(.subheadline)
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        if let email =
                            contact.emailAddresses.first {

                            Text(
                                email.value as String
                            )
                            .font(.subheadline)
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)

            // MARK: - Error

            if let errorMessage {

                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(
                        .center
                    )
            }

            // MARK: - Warning

            VStack(spacing: 6) {

                Text(
                    "These contacts will be permanently deleted."
                )
                .font(.subheadline)
                .fontWeight(.semibold)

                Text(
                    "Review the selected contacts carefully before confirming."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(
                    .center
                )
            }

            // MARK: - Confirm

            Button {

                guard !isDeleting else {
                    return
                }

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
                            errorMessage =
                                "Failed to delete contacts: \(error.localizedDescription)"
                        }
                    }
                }

            } label: {

                if isDeleting {

                    ProgressView()
                        .frame(
                            maxWidth: .infinity
                        )

                } else {

                    Text("Confirm Delete")
                        .frame(
                            maxWidth: .infinity
                        )
                }
            }
            .buttonStyle(
                .borderedProminent
            )
            .tint(.red)
            .disabled(
                isDeleting ||
                contacts.isEmpty
            )

            // MARK: - Cancel

            Button("Cancel") {
                dismiss()
            }
            .disabled(isDeleting)
        }
        .padding()
        .navigationTitle(
            "Review Contacts"
        )
    }

    private func contactName(
        _ contact: CNContact
    ) -> String {

        let name =
            "\(contact.givenName) \(contact.familyName)"
                .trimmingCharacters(
                    in: .whitespaces
                )

        return name.isEmpty
            ? "Unnamed Contact"
            : name
    }
}