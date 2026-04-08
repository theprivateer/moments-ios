# AGENTS.md

Guidance for AI coding agents working in this repository.

## Server API

The Moments server API is documented as an OpenAPI 3.1 spec at `specs/openapi.yaml`. Consult this spec when working on network requests, API integration, or adding new endpoints.

## Build & Run

Build via Xcode or from the command line:
```bash
xcodebuild -project Moments.xcodeproj -scheme Moments -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Architecture

iOS 26.2+, SwiftUI, MVVM with `@Observable` view models. See `CLAUDE.md` for full details.
