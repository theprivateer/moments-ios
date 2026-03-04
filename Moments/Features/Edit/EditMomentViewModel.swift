import Foundation
import UIKit
import Observation

extension Notification.Name {
    static let momentUpdated = Notification.Name("com.philstephens.Moments.momentUpdated")
    static let momentDeleted = Notification.Name("com.philstephens.Moments.momentDeleted")
}

@Observable @MainActor final class EditMomentViewModel {
    var bodyText: String
    var existingImages: [MomentImage]
    var imagesToRemove: Set<Int> = []
    var newImageUploads: [AttachedImageUpload] = []
    var isSubmitting: Bool = false
    var submissionError: AppError?
    var wasSaved: Bool = false
    var wasDeleted: Bool = false

    private let moment: Moment
    let store: SettingsStore
    private let api = MomentsAPIService()
    private var uploadTasks: [UUID: Task<Void, Never>] = [:]

    private static let maxCharacters = 10_000

    var remainingCharacters: Int {
        Self.maxCharacters - bodyText.count
    }

    var isOverLimit: Bool {
        remainingCharacters < 0
    }

    var allUploadsSettled: Bool {
        newImageUploads.allSatisfy { if case .uploading = $0.state { return false }; return true }
    }

    var hasFailedUploads: Bool {
        newImageUploads.contains { if case .failed = $0.state { return true }; return false }
    }

    var hasContent: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || existingImages.contains { !imagesToRemove.contains($0.id) }
            || !newImageUploads.isEmpty
    }

    var canSave: Bool {
        store.isConfigured && hasContent && !isOverLimit && !isSubmitting
            && allUploadsSettled && !hasFailedUploads
    }

    init(moment: Moment, store: SettingsStore) {
        self.moment = moment
        self.store = store
        self.bodyText = moment.body ?? ""
        self.existingImages = moment.images
    }

    func save() async {
        guard canSave else { return }
        isSubmitting = true
        submissionError = nil

        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyToSend: String? = trimmed.isEmpty ? nil : trimmed
        let addImageIDs = newImageUploads.compactMap { upload -> Int? in
            if case .uploaded(let id) = upload.state { return id }
            return nil
        }
        let removeImageIDs = Array(imagesToRemove)

        do {
            let updated = try await api.patchMoment(
                id: moment.id,
                body: bodyToSend,
                addImageIDs: addImageIDs,
                removeImageIDs: removeImageIDs,
                serverURL: store.serverURL,
                token: store.personalAccessToken
            )
            wasSaved = true
            NotificationCenter.default.post(name: .momentUpdated, object: updated)
        } catch let error as AppError {
            submissionError = error
        } catch {
            submissionError = .networkError(error as? URLError ?? URLError(.unknown))
        }

        isSubmitting = false
    }

    func delete() async {
        isSubmitting = true
        submissionError = nil

        do {
            try await api.deleteMoment(
                id: moment.id,
                serverURL: store.serverURL,
                token: store.personalAccessToken
            )
            wasDeleted = true
            NotificationCenter.default.post(name: .momentDeleted, object: moment.id)
        } catch let error as AppError {
            submissionError = error
        } catch {
            submissionError = .networkError(error as? URLError ?? URLError(.unknown))
        }

        isSubmitting = false
    }

    func appendImage(_ image: UIImage) {
        let upload = AttachedImageUpload(image: image)
        newImageUploads.append(upload)
        let task = Task { await performUpload(upload) }
        uploadTasks[upload.id] = task
    }

    private func performUpload(_ upload: AttachedImageUpload) async {
        do {
            let momentImage = try await api.uploadImage(upload.image, serverURL: store.serverURL, token: store.personalAccessToken)
            upload.state = .uploaded(momentImage.id)
        } catch {
            upload.state = .failed
        }
    }

    func toggleImageRemoval(id: Int) {
        if imagesToRemove.contains(id) {
            imagesToRemove.remove(id)
        } else {
            imagesToRemove.insert(id)
        }
    }

    func removeNewUpload(id: UUID) {
        uploadTasks[id]?.cancel()
        uploadTasks[id] = nil
        newImageUploads.removeAll { $0.id == id }
    }
}
