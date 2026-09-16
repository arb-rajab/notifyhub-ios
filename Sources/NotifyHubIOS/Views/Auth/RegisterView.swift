import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display name", text: $displayName)
                        .textContentType(.name)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                }

                if let message = session.lastErrorMessage {
                    Section {
                        Text(message).foregroundStyle(.red)
                    }
                }

                Section {
                    Button(isSubmitting ? "Creating account..." : "Create Account") {
                        Task {
                            isSubmitting = true
                            await session.register(email: email, password: password, displayName: displayName)
                            isSubmitting = false
                            if session.isSignedIn {
                                dismiss()
                            }
                        }
                    }
                    .disabled(isSubmitting || email.isEmpty || password.isEmpty || displayName.isEmpty)
                }
            }
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    RegisterView().environmentObject(AppSession())
}
