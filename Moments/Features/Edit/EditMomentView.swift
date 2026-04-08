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

                if !vm.orderedImages.isEmpty {
                    Divider()
                    imagesStrip
                }
            }
            .navigationTitle("Edit Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) {
                deleteBar
            }
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
            .onChange(of: vm.wasSaved) { _, success in
                if success { dismiss() }
            }
            .onChange(of: vm.wasDeleted) { _, deleted in
                if deleted { dismiss() }
            }
        }
    }

    private var deleteBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button("Delete Moment") {
                showDeleteConfirmation = true
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.red)
            .background(.bar)
        }
    }

    private var textEditorSection: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $vm.bodyText)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .accessibilityLabel("What's on your mind?")

            if vm.bodyText.isEmpty {
                Text("What's on your mind?")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(vm.remainingCharacters)")
                .font(.caption)
                .foregroundStyle(vm.isOverLimit ? .red : .secondary)
                .padding(8)
                .accessibilityLabel("\(vm.remainingCharacters) characters remaining")
        }
    }

    private var imagesStrip: some View {
        ReorderableImageStrip(items: vm.orderedImages, onMove: vm.moveImages(fromOffsets:toOffset:)) { item in
            imageThumbnail(for: item)
        }
    }

    @ViewBuilder
    private func imageThumbnail(for item: EditMomentViewModel.OrderedImageItem) -> some View {
        ZStack(alignment: .topTrailing) {
            thumbnailContent(for: item)

            Button {
                vm.removeImageItem(id: item.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .font(.system(size: 18))
            }
            .accessibilityLabel("Remove photo")
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
                        .accessibilityLabel("Upload failed")
                }
        case .uploaded:
            EmptyView()
        }
    }

    @ViewBuilder
    private func thumbnailContent(for item: EditMomentViewModel.OrderedImageItem) -> some View {
        switch item.source {
        case .existing(let image):
            AsyncImage(url: URL(string: image.url)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay(Image(systemName: "photo").foregroundStyle(.secondary).accessibilityHidden(true))
                default:
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                        .overlay(ProgressView())
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        case .newUpload(let upload):
            Image(uiImage: upload.image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    uploadStateOverlay(for: upload.state)
                }
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
