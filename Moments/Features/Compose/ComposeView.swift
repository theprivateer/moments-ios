import SwiftUI
import PhotosUI

struct ComposeView: View {
    @State private var vm: ComposeViewModel
    @State private var showSettings = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showSuccessBanner = false

    init(store: SettingsStore) {
        _vm = State(initialValue: ComposeViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    textEditorSection

                    if !vm.imageUploads.isEmpty {
                        Divider()
                        AttachedImagesStrip(uploads: vm.imageUploads) { id in
                            vm.removeImage(withID: id)
                        }
                    }
                }

                if showSuccessBanner {
                    successBanner
                }
            }
            .navigationTitle("New Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showSettings) {
                SettingsView(store: vm.store)
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
            .onChange(of: vm.wasSubmitted) { _, success in
                guard success else { return }
                vm.wasSubmitted = false
                showSuccessBanner = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation {
                        showSuccessBanner = false
                    }
                }
            }
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
            }
            .accessibilityLabel("Settings")
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
                Button("Post") {
                    Task { await vm.submit() }
                }
                .disabled(!vm.canSubmit)
                .fontWeight(.semibold)
            }
        }
    }

    private var successBanner: some View {
        Text("Moment posted!")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.green))
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
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
