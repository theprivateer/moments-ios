import SwiftUI

struct TimelineView: View {
    @State private var vm: TimelineViewModel
    @State private var showingCompose = false
    @State private var showingSettings = false

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
        .task {
            await vm.loadInitialOrCached()
        }
        .onReceive(NotificationCenter.default.publisher(for: .momentPosted)) { _ in
            Task { await vm.refresh() }
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
                    MomentRowView(moment: moment)
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
