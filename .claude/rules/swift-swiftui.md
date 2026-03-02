---
paths: "**/*.swift"
---

# SwiftUI Rules

> **Prerequisites**: Run `/init-swift` for universal Swift guidelines.

### Architecture

**MVVM** default. VMs: `@Observable` (iOS 17+) or `ObservableObject`. No SwiftUI imports. `@StateObject` for owned, `@ObservedObject` for injected. **TCA** for complex apps.
```swift
@Observable @MainActor final class VM {
    private(set) var items: [Item] = []
    func load() async { items = await repo.fetch() }
}
struct MyView: View {
    @State private var vm = VM()
    var body: some View { List(vm.items) { Text(.name) }.task { await vm.load() } }
}
```

### View Performance

Small focused views. `LazyVStack`/`LazyHStack` for large collections. `.equatable()` for expensive views. Pre-compute in `init`. **NEVER** `.id(UUID())` (forces redraw).

### State Management

| Property Wrapper | Use Case |
|------------------|----------|
| `@State` | View-local value types |
| `@StateObject` | Owned ObservableObject (pre-iOS 17) |
| `@ObservedObject` | Injected ObservableObject |
| `@EnvironmentObject` | Shared across view tree |
| `@Binding` | Two-way connection to parent |
| `@Observable` + `@State` | iOS 17+ preferred |

**@MainActor** on all ViewModels.

### Desktop UI (macOS)

**Multi-window:** `@Environment(\.openWindow) var openWindow; openWindow(id: "stats")`
```swift
@main struct App: App {
    var body: some Scene {
        WindowGroup { ContentView() }
        Window("Stats", id: "stats") { StatsView() }
        Settings { SettingsView() }
    }
}
```

**Commands/Menus:**
```swift
.commands {
    CommandMenu("Custom") { Button("Action") { }.keyboardShortcut("a", modifiers: [.command, .shift]) }
    CommandGroup(after: .newItem) { Button("New...") { } }
}
```

**Keyboard:** `.keyboardShortcut("s")` ⌘S, `.defaultAction` Return, `.cancelAction` Escape

**FocusedValue** for cross-window state:
```swift
struct SelectedKey: FocusedValueKey { typealias Value = Binding<Item?> }
// .focusedSceneValue(\.selected, $item) | @FocusedBinding(\.selected) var item
```

**NavigationSplitView:**
```swift
NavigationSplitView {
    List(items, selection: $sel) { NavigationLink(value: ) { Text(.name) } }.navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
} detail: {
    if let sel { DetailView(item: sel) } else { ContentUnavailableView("Select", systemImage: "doc") }
}
```

### SwiftData

```swift
@Model class Trip {
    @Attribute(.unique) var name: String
    @Relationship(deleteRule: .cascade) var items: [Item] = []
}
// .modelContainer(for: Trip.self) | @Query(sort: \Trip.date) var trips: [Trip]
```

### Accessibility

```swift
Image(systemName: "heart").accessibilityLabel("Favorite")  // REQUIRED for icons
Image(decorative: "bg")  // hides from VoiceOver
VStack { Text("Score"); Text("100") }.accessibilityElement(children: .combine).accessibilityAdjustableAction { dir in rating += dir == .increment ? 1 : -1 }
```

### Snapshot Testing

`assertSnapshot(matching: NSHostingController(rootView: view), as: .image)`

### Common Mistakes

| ❌ Avoid | ✅ Prefer |
|----------|-----------|
| `@State var vm = ClassVM()` (pre-iOS17) | `@StateObject var vm` |
| Computation in `body` | Pre-compute in `init` |
| `.id(UUID())` | Stable identity |
| Massive views | Extract focused subviews |
