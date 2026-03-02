import Foundation
import Observation

@Observable @MainActor final class SettingsViewModel {
    var serverURLField: String
    var patField: String
    var alertError: AppError?

    private let store: SettingsStore

    var hasChanges: Bool {
        serverURLField != store.serverURL || patField != store.personalAccessToken
    }

    init(store: SettingsStore) {
        self.store = store
        self.serverURLField = store.serverURL
        self.patField = store.personalAccessToken
    }

    func save() {
        let trimmedURL = serverURLField.trimmingCharacters(in: .whitespaces)
        let trimmedPAT = patField.trimmingCharacters(in: .whitespaces)

        store.serverURL = trimmedURL
        serverURLField = trimmedURL

        do {
            try store.savePAT(trimmedPAT)
            patField = trimmedPAT
        } catch let error as AppError {
            alertError = error
        } catch {
            alertError = .keychainError(-1)
        }
    }
}
