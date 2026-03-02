import Foundation
import UIKit
import Observation

@Observable @MainActor final class ComposeViewModel {
    var bodyText: String = ""
    var attachedImages: [UIImage] = []
    var isSubmitting: Bool = false
    var submissionError: AppError?
    var didSubmitSuccessfully: Bool = false

    private static let maxCharacters = 10_000

    var remainingCharacters: Int {
        Self.maxCharacters - bodyText.count
    }

    var isOverLimit: Bool {
        remainingCharacters < 0
    }

    var hasContent: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachedImages.isEmpty
    }

    let store: SettingsStore
    private let api = MomentsAPIService()

    init(store: SettingsStore) {
        self.store = store
    }

    var canSubmit: Bool {
        store.isConfigured && hasContent && !isOverLimit && !isSubmitting
    }

    func submit() async {
        guard canSubmit else { return }

        isSubmitting = true
        submissionError = nil

        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyToSend: String? = trimmedBody.isEmpty ? nil : trimmedBody

        do {
            _ = try await api.postMoment(
                body: bodyToSend,
                images: attachedImages,
                serverURL: store.serverURL,
                token: store.personalAccessToken
            )
            bodyText = ""
            attachedImages = []
            didSubmitSuccessfully = true
        } catch let error as AppError {
            submissionError = error
        } catch {
            submissionError = .networkError(error as? URLError ?? URLError(.unknown))
        }

        isSubmitting = false
    }

    func removeImage(at index: Int) {
        guard attachedImages.indices.contains(index) else { return }
        attachedImages.remove(at: index)
    }

    func appendImage(_ image: UIImage) {
        attachedImages.append(image)
    }
}
