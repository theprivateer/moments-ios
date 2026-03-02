import Foundation
import Observation

@Observable @MainActor final class SettingsStore {
    private static let serverURLKey = "serverURL"
    private static let patAccount = "pat"

    var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: Self.serverURLKey) }
    }

    private(set) var personalAccessToken: String

    var isConfigured: Bool {
        !serverURL.trimmingCharacters(in: .whitespaces).isEmpty &&
        !personalAccessToken.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init() {
        serverURL = UserDefaults.standard.string(forKey: Self.serverURLKey) ?? ""
        personalAccessToken = KeychainService.load(account: Self.patAccount) ?? ""
    }

    func savePAT(_ token: String) throws {
        try KeychainService.save(account: Self.patAccount, value: token)
        personalAccessToken = token
    }
}
