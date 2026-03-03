import Foundation
import UIKit
import Observation

extension Notification.Name {
    static let momentPosted = Notification.Name("com.philstephens.Moments.momentPosted")
}

@Observable final class AttachedImageUpload: Identifiable {
    enum UploadState { case uploading, uploaded(Int), failed }
    let id = UUID()
    let image: UIImage
    var state: UploadState = .uploading

    init(image: UIImage) {
        self.image = image
    }
}

@Observable @MainActor final class ComposeViewModel {
    var bodyText: String = ""
    var imageUploads: [AttachedImageUpload] = []
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

    var allImagesSettled: Bool {
        imageUploads.allSatisfy { if case .uploading = $0.state { return false }; return true }
    }

    var hasFailedUploads: Bool {
        imageUploads.contains { if case .failed = $0.state { return true }; return false }
    }

    var hasContent: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !imageUploads.isEmpty
    }

    let store: SettingsStore
    private let api = MomentsAPIService()

    init(store: SettingsStore) {
        self.store = store
    }

    var canSubmit: Bool {
        store.isConfigured && hasContent && !isOverLimit && !isSubmitting
            && allImagesSettled && !hasFailedUploads
    }

    func submit() async {
        guard canSubmit else { return }

        isSubmitting = true
        submissionError = nil

        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyToSend: String? = trimmedBody.isEmpty ? nil : trimmedBody
        let imageIDs = imageUploads.compactMap { upload -> Int? in
            if case .uploaded(let id) = upload.state { return id }
            return nil
        }

        do {
            _ = try await api.postMoment(
                body: bodyToSend,
                imageIDs: imageIDs,
                serverURL: store.serverURL,
                token: store.personalAccessToken
            )
            bodyText = ""
            imageUploads = []
            didSubmitSuccessfully = true
            NotificationCenter.default.post(name: .momentPosted, object: nil)
        } catch let error as AppError {
            submissionError = error
        } catch {
            submissionError = .networkError(error as? URLError ?? URLError(.unknown))
        }

        isSubmitting = false
    }

    func appendImage(_ image: UIImage) {
        let upload = AttachedImageUpload(image: image)
        imageUploads.append(upload)
        Task { await performUpload(upload) }
    }

    private func performUpload(_ upload: AttachedImageUpload) async {
        do {
            let momentImage = try await api.uploadImage(upload.image, serverURL: store.serverURL, token: store.personalAccessToken)
            upload.state = .uploaded(momentImage.id)
        } catch {
            upload.state = .failed
        }
    }

    func removeImage(withID id: UUID) {
        imageUploads.removeAll { $0.id == id }
    }
}
