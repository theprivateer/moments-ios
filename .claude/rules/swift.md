---
paths: "**/*.swift"
---

# Swift Rules

> **UI Framework**: Also run `/init-swift-swiftui` for SwiftUI or `/init-swift-appkit` for AppKit.

### Naming (Swift API Design Guidelines)

| Convention | Examples |
|------------|----------|
| **UpperCamelCase** | Types, protocols |
| **lowerCamelCase** | Everything else |
| Side effects → imperative verb | `sort()`, `append()` |
| No side effects → noun | `sorted()`, `distance()` |
| Mutating/nonmutating pairs | `sort()`/`sorted()`, `formUnion()`/`union()` |
| Booleans as assertions | `isEmpty`, `hasPermission`, `canEdit` |
| Protocols describing capability | `Equatable`, `ProgressReporting` |
| Factory methods | `makeIterator()` |

Clarity at call site: `x.insert(y, at: z)` reads as English.

### Project Structure

Feature-based: `Features/Settings/{View,VM,Tests}.swift`, `Shared/{Extensions,Services,Models}/`
Large apps: local SPM packages for build speed + access control.

### Performance

**Lazy loading:** `lazy var`, `.lazy` on sequences.

**Value vs Reference:** Prefer structs (stack, no ARC, thread-safe). Classes only for identity/inheritance/shared mutable state.

### Memory Management

**Retain cycles:** `[weak self]` in escaping closures, `[unowned self]` only if closure can't outlive self.
**Delegates:** Always `weak var delegate: MyDelegate?`
```swift
service.fetch { [weak self] data in guard let self else { return }; self.data = data }
```

### Concurrency

**async/await** default. **Actors** for shared state. **Structured concurrency:** `async let` for parallel, task groups for dynamic. **Sendable:** Implicit for value types, `@unchecked Sendable` only with internal sync. **Cancellation:** `Task.checkCancellation()` in loops.
```swift
func fetch() async throws -> Data {
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}
actor Cache { var items: [Item] = [] }
async let a = fetchA(); async let b = fetchB()  // parallel
try await withThrowingTaskGroup(of: T.self) { group in ... }  // dynamic
```

### Error Handling

```swift
enum AppError: LocalizedError {
    case network(Int)
    var errorDescription: String? { ... }
}
```

| Situation | Use |
|-----------|-----|
| Recoverable | `throws`/`Result` |
| Debug-only | `assert()` |
| Always-checked | `precondition()` |
| Impossible state | `fatalError()` |

### Security

**Keychain** for credentials (NEVER UserDefaults):
```swift
let q: [String: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: svc, kSecAttrAccount: acct, kSecValueData: pwd.data(using: .utf8)!, kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked]; SecItemAdd(q as CFDictionary, nil)
```

**Input validation:** Validate/sanitize all input. Typed wrappers: `struct Email { init(_ s: String) throws }`
**Cross-platform:** No Keychain on Linux/Windows—use CryptoKit AES-GCM + encrypted files.

### Data Persistence

| Solution | Use Case | Size |
|----------|----------|------|
| UserDefaults | Preferences | <100KB |
| SwiftData | Simple models, SwiftUI | S-M |
| Core Data | Complex relationships | M-L |
| GRDB/SQLite | Cross-platform | Any |
| Keychain | Secrets | Small |

### Networking

**Router pattern:** Enum with `path`, `method`, `body`. **Linux:** `import FoundationNetworking` (no Alamofire).
```swift
func fetch<T: Decodable>(from url: URL) async throws -> T {
    let (data, resp) = try await URLSession.shared.data(from: url)
    guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw NetworkError.invalid }
    return try JSONDecoder().decode(T.self, from: data)
}
```

### Testing

**XCTest:** `test_Behavior_ExpectedResult`. **swift-testing (Xcode 16+):** `@Test`, `#expect`. **Async:** `async throws`.
```swift
@Test func fullName() { #expect(person.fullName == "John Doe") }
@Test(arguments: ["A","B"]) func param(v: String) { #expect(!v.isEmpty) }
func testX() async throws { try await sut.load(); #expect(!sut.items.isEmpty) }
```

### Localization

Xcode 15+ String Catalogs auto-extract:
```swift
String(localized: "Hello", comment: "Greeting")
Text(verbatim: "API_KEY")  // prevent extraction
```

### SPM Dependencies

```swift
.package(url: "...", exact: "2.1.0")  // production
.package(url: "...", from: "2.0.0")   // semver
.package(url: "...", revision: "abc") // pinned commit
```

### Common Mistakes

| ❌ Avoid | ✅ Prefer |
|----------|-----------|
| `optional!` | `guard let`/`??` |
| `{ self.x }` in escaping closure | `{ [weak self] in self?.x }` |
| Heavy work on main thread | `Task { await bg(); await MainActor.run { ui() } }` |
| Singletons everywhere | Dependency injection |
