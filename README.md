# Moments — an iOS microblog client for self-hosted servers

## Overview

Moments is a minimal iOS client for posting short updates ("moments") to a self-hosted server. Each post supports up to 10,000 characters of text and up to 10 attached images. Images are uploaded individually the moment they are selected; the post is then submitted as JSON referencing the uploaded image IDs.

This app is built as the iOS companion to [theprivateer/moments](https://github.com/theprivateer/moments), a self-hosted Laravel microblog.

> [!NOTE]
> I am intentionally using **Claude Code** to help build and maintain this project as an exploration of using AI coding assistants.

## Requirements

- Xcode with the iOS 26.2+ SDK
- A running instance of [theprivateer/moments](https://github.com/theprivateer/moments) (or a compatible server exposing `POST /api/v1/images` and `POST /api/v1/moments`)
- A Personal Access Token (PAT) for that server

## Getting Started

1. Clone the repo
2. Open `Moments.xcodeproj` in Xcode
3. Select a simulator running iOS 26.2+ (e.g. iPhone 17)
4. Build and run (⌘R)
5. Tap the gear icon on the Compose screen → enter your Server URL and PAT → tap Save

## Build from the Command Line

```bash
xcodebuild -project Moments.xcodeproj -scheme Moments \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Configuration

| Setting | Description | Storage |
|---|---|---|
| **Server URL** | Base URL of your server (e.g. `https://example.com`) | UserDefaults |
| **Personal Access Token** | Bearer token used for API authentication | iOS Keychain |

Enter both values via the gear icon on the Compose screen.

## API Contract

```
GET {serverURL}/api/v1/moments?page={n}
Authorization: Bearer {token}

Response: 200 OK — { "data": [...Moment], "links": {...}, "meta": { "currentPage": n, ... } }


POST {serverURL}/api/v1/images
Authorization: Bearer {token}
Content-Type: multipart/form-data

image  — JPEG image file

Response: 201 Created — { "data": { "id": 1, "url": "..." } }


POST {serverURL}/api/v1/moments
Authorization: Bearer {token}
Content-Type: application/json

{
  "body":   "text content (up to 10,000 characters)",
  "images": [1, 2]   ← IDs returned by POST /api/v1/images
}

Responses:
- 201 Created               — { "data": { ...Moment } }
- 401 Unauthorized          — invalid or missing token
- 422 Unprocessable Entity  — validation error
```

## Project Structure

```
Moments/
├── MomentsApp.swift
├── Features/
│   ├── Compose/          (ComposeView, ComposeViewModel, AttachedImagesStrip)
│   ├── Timeline/         (TimelineView, TimelineViewModel, MomentRowView)
│   └── Settings/         (SettingsView, SettingsViewModel)
└── Shared/
    ├── Models/           (Moment, AppError)
    └── Services/         (KeychainService, SettingsStore, MomentsAPIService)
```

## Architecture

- **MVVM** with `@Observable` view models (iOS 17+), all implicitly `@MainActor`
- **SettingsStore** — single instance created in `@main`, injected via `.environment()`
- **MomentsAPIService** — stateless struct, no shared state
- **Zero third-party dependencies** — SwiftUI, Foundation, Security, and PhotosUI only

## License

TBD
