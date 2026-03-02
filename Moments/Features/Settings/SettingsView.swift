import SwiftUI

struct SettingsView: View {
    @State private var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    init(store: SettingsStore) {
        _vm = State(initialValue: SettingsViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com", text: $vm.serverURLField)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Server URL")
                }

                Section {
                    SecureField("Personal Access Token", text: $vm.patField)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Authentication")
                } footer: {
                    Text("Token is stored securely in the system Keychain.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.save()
                        dismiss()
                    }
                    .disabled(!vm.hasChanges)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { vm.alertError != nil },
                set: { if !$0 { vm.alertError = nil } }
            )) {
                Button("OK") { vm.alertError = nil }
            } message: {
                Text(vm.alertError?.localizedDescription ?? "")
            }
        }
    }
}
