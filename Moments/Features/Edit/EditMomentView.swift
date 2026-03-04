import SwiftUI
import PhotosUI

struct EditMomentView: View {
    @State private var vm: EditMomentViewModel
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    init(moment: Moment, store: SettingsStore) {
        _vm = State(initialValue: EditMomentViewModel(moment: moment, store: store))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                textEditorSection

                if !vm.existingImages.isEmpty || !vm.newImageUploads.isEmpty {
                    Divider()
                    imagesStrip
                }
            }
            .navigationTitle("Edit Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmationDialog("Delete this moment?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task { await vm.delete() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                loadPhotos(from: newItems)
            }
            .alert("Error", isPresented: Binding(
                get: { vm.submissionError != nil },
                set: { if !$0 { vm.submissionError = nil } }
            )) {
                Button("OK") { vm.submissionError = nil }
            } message: {
                Text(vm.submissionError?.localizedDescription ?? "")
            }
            .onChange(of: vm.didSaveSuccessfully) { _, success in
                if success { dismiss() }
            }
            .onChange(of: vm.didDeleteSuccessfully) { _, deleted in
                if deleted { dismiss() }
            }
        }
    }

    private var textEditorSection: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $vm.bodyText)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            if vm.bodyText.isEmpty {
                Text("What's on your mind?")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(vm.remainingCharacters)")
                .font(.caption)
                .foregroundStyle(vm.isOverLimit ? .red : .secondary)
                .padding(8)
        }
    }

    private var imagesStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.existingImages) { image in
                    existingImageThumbnail(image)
                }
                ForEach(vm.newImageUploads) { upload in
                    newUploadThumbnail(upload)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func existingImageThumbnail(_ image: MomentImage) -> some View {
        let markedForRemoval = vm.imagesToRemove.contains(image.id)
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: URL(string: image.url)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                default:
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                        .overlay(ProgressView())
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(markedForRemoval ? 0.4 : 1.0)
            .overlay {
                if markedForRemoval {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.red, lineWidth: 2)
                }
            }

            Button {
                vm.removeExistingImage(id: image.id)
            } label: {
                Image(systemName: markedForRemoval ? "arrow.uturn.backward.circle.fill" : "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .font(.system(size: 18))
            }
            .offset(x: 6, y: -6)
        }
    }

    @ViewBuilder
    private func newUploadThumbnail(_ upload: AttachedImageUpload) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: upload.image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            uploadStateOverlay(for: upload.state)

            Button {
                vm.removeNewUpload(id: upload.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .font(.system(size: 18))
            }
            .offset(x: 6, y: -6)
        }
    }

    @ViewBuilder
    private func uploadStateOverlay(for state: AttachedImageUpload.UploadState) -> some View {
        switch state {
        case .uploading:
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.4))
                .frame(width: 80, height: 80)
                .overlay { ProgressView().tint(.white) }
        case .failed:
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.4))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 24))
                }
        case .uploaded:
            EmptyView()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { dismiss() }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 10,
                matching: .images
            ) {
                Image(systemName: "photo")
            }
            .accessibilityLabel("Attach photos")

            if vm.isSubmitting {
                ProgressView()
            } else {
                Button("Save") {
                    Task { await vm.save() }
                }
                .disabled(!vm.canSave)
                .fontWeight(.semibold)
            }
        }

        ToolbarItem(placement: .bottomBar) {
            Button("Delete Moment") {
                showDeleteConfirmation = true
            }
            .foregroundStyle(.red)
        }
    }

    private func loadPhotos(from items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    vm.appendImage(image)
                }
            }
            selectedPhotoItems = []
        }
    }
}
