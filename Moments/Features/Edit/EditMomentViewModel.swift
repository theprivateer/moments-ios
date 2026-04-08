import Foundation
import SwiftUI
import UIKit
import Observation

extension Notification.Name {
    static let momentUpdated = Notification.Name("com.philstephens.Moments.momentUpdated")
    static let momentDeleted = Notification.Name("com.philstephens.Moments.momentDeleted")
}

@Observable @MainActor final class EditMomentViewModel {
    struct OrderedImageItem: Identifiable {
        enum Source {
            case existing(MomentImage)
            case newUpload(AttachedImageUpload)
        }

        let id = UUID()
        let source: Source

        var existingImageID: Int? {
            guard case .existing(let image) = source else { return nil }
            return image.id
        }

        var uploadedImageID: Int? {
            guard case .newUpload(let upload) = source,
                  case .uploaded(let imageID) = upload.state else { return nil }
            return imageID
        }

        var uploadID: UUID? {
            guard case .newUpload(let upload) = source else { return nil }
            return upload.id
        }
    }

    var bodyText: String
    var orderedImages: [OrderedImageItem]
    var isSubmitting: Bool = false
    var submissionError: AppError?
    var wasSaved: Bool = false
    var wasDeleted: Bool = false

    private let moment: Moment
    private let originalExistingImageIDs: [Int]
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
        orderedImages.allSatisfy { item in
            guard case .newUpload(let upload) = item.source else { return true }
            if case .uploading = upload.state { return false }
            return true
        }
    }

    var hasFailedUploads: Bool {
        orderedImages.contains { item in
            guard case .newUpload(let upload) = item.source else { return false }
            if case .failed = upload.state { return true }
            return false
        }
    }

    var hasContent: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !orderedImages.isEmpty
    }

    var canSave: Bool {
        store.isConfigured && hasContent && !isOverLimit && !isSubmitting
            && allUploadsSettled && !hasFailedUploads
    }

    init(moment: Moment, store: SettingsStore) {
        self.moment = moment
        self.store = store
        self.originalExistingImageIDs = moment.images.map(\.id)
        self.bodyText = moment.body ?? ""
        self.orderedImages = moment.images.map { OrderedImageItem(source: .existing($0)) }
    }

    func save() async {
        guard canSave else { return }
        isSubmitting = true
        submissionError = nil

        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyToSend: String? = trimmed.isEmpty ? nil : trimmed
        let addImageIDs = orderedImages.compactMap(\.uploadedImageID)
        let visibleExistingImageIDs = Set(orderedImages.compactMap(\.existingImageID))
        let removeImageIDs = originalExistingImageIDs.filter { !visibleExistingImageIDs.contains($0) }
        let imageOrderIDs = orderedImages.compactMap { item in
            item.existingImageID ?? item.uploadedImageID
        }

        do {
            let updated = try await api.patchMoment(
                id: moment.id,
                body: bodyToSend,
                addImageIDs: addImageIDs,
                removeImageIDs: removeImageIDs,
                imageOrderIDs: imageOrderIDs,
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
        orderedImages.append(OrderedImageItem(source: .newUpload(upload)))
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

    func removeImageItem(id: UUID) {
        guard let item = orderedImages.first(where: { $0.id == id }) else { return }
        if let uploadID = item.uploadID {
            uploadTasks[uploadID]?.cancel()
            uploadTasks[uploadID] = nil
        }
        orderedImages.removeAll { $0.id == id }
    }

    func moveImages(fromOffsets: IndexSet, toOffset: Int) {
        orderedImages.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }
}
