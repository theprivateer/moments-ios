import SwiftUI

struct TimelineView: View {
    struct TimelineImageViewerState: Identifiable {
        let id = UUID()
        let images: [MomentImage]
        let initialIndex: Int
    }

    @State private var vm: TimelineViewModel
    @State private var showingCompose = false
    @State private var showingSettings = false
    @State private var momentToEdit: Moment? = nil
    @State private var momentToDelete: Moment? = nil
    @State private var imageViewerState: TimelineImageViewerState? = nil

    init(store: SettingsStore) {
        _vm = State(initialValue: TimelineViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Timeline")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gear")
                                .accessibilityLabel("Settings")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingCompose = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .accessibilityLabel("Compose")
                        }
                    }
                }
        }
        .sheet(isPresented: $showingCompose) {
            ComposeView(store: vm.store)
                .environment(vm.store)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: vm.store)
                .environment(vm.store)
        }
        .sheet(item: $momentToEdit) { moment in
            EditMomentView(moment: moment, store: vm.store)
        }
        .fullScreenCover(item: $imageViewerState) { state in
            TimelineImageViewer(images: state.images, initialIndex: state.initialIndex) {
                imageViewerState = nil
            }
        }
        .confirmationDialog("Delete this moment?", isPresented: Binding(
            get: { momentToDelete != nil },
            set: { if !$0 { momentToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let moment = momentToDelete {
                    Task { await vm.deleteMoment(moment) }
                }
                momentToDelete = nil
            }
            Button("Cancel", role: .cancel) { momentToDelete = nil }
        }
        .task {
            await vm.loadInitialOrCached()
        }
        .onReceive(NotificationCenter.default.publisher(for: .momentPosted)) { _ in
            Task { await vm.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .momentUpdated)) { n in
            if let updated = n.object as? Moment { vm.updateMoment(updated) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .momentDeleted)) { n in
            if let id = n.object as? Int { vm.removeMoment(withID: id) }
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = vm.error {
                Text(error.localizedDescription)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.moments.isEmpty {
            ProgressView("Loading…")
        } else if vm.moments.isEmpty && !vm.isLoading {
            ContentUnavailableView(
                "No Moments Yet",
                systemImage: "text.bubble",
                description: Text("Tap the compose button to share your first moment.")
            )
        } else {
            List {
                ForEach(vm.moments) { moment in
                    MomentRowView(
                        moment: moment,
                        onEdit: { momentToEdit = moment },
                        onDelete: { momentToDelete = moment },
                        onImageTap: { images, selectedIndex in
                            imageViewerState = TimelineImageViewerState(
                                images: images,
                                initialIndex: selectedIndex
                            )
                        }
                    )
                    .onAppear {
                        Task { await vm.loadNextPageIfNeeded(currentItem: moment) }
                    }
                }
                if vm.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .refreshable {
                await vm.refresh()
            }
        }
    }
}

extension TimelineView {
    var errorBinding: Binding<Bool> {
        Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )
    }
}
