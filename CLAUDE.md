# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Build and run via Xcode — open `Moments.xcodeproj`. There is no CLI build script.

To build from the command line:
```bash
xcodebuild -project Moments.xcodeproj -scheme Moments -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

To run tests (once a test target exists):
```bash
xcodebuild test -project Moments.xcodeproj -scheme Moments -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Project Details

- **Platform**: iOS 26.2+
- **Bundle ID**: `com.philstephens.Moments`
- **Swift**: 5.0
- **UI**: SwiftUI (`@main` in `MomentsApp.swift`)
- **No SPM dependencies** currently

## Architecture

This is a new project — only the default Xcode template exists so far (`MomentsApp.swift` entry point, `ContentView.swift`). As the app grows, follow MVVM with `@Observable` view models (iOS 17+), feature-based folder structure, and SwiftData for persistence if needed. See `.claude/rules/swift.md` and `.claude/rules/swift-swiftui.md` for coding conventions.

## Server API

The Moments server API is documented as an OpenAPI 3.1 spec at `.claude/specs/openapi.yaml`. Consult this spec when working on network requests, API integration, or adding new endpoints.
