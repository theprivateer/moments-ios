import Foundation

enum AppError: LocalizedError {
    case notConfigured
    case networkError(URLError)
    case serverError(statusCode: Int, message: String?)
    case validationError([String: [String]])
    case unauthorized
    case decodingError(Error)
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Server URL or personal access token is not configured. Please open Settings to configure the app."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            if let message {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server error (\(statusCode))"
        case .validationError(let fields):
            let messages = fields.values.flatMap { $0 }.joined(separator: "\n")
            return "Validation failed:\n\(messages)"
        case .unauthorized:
            return "Unauthorized. Please check your personal access token in Settings."
        case .decodingError(let error):
            return "Failed to decode server response: \(error.localizedDescription)"
        case .keychainError(let status):
            return "Keychain error (code \(status))"
        }
    }
}
