# Metra: App for Students (Metra Siswa)

**Metra: App for Students** (*Metra Siswa*) is an accessible, VoiceOver-first iPhone and iPad application that transforms math photos, scanned pages, PDF files and teacher-shared classroom materials into structured, spoken Indonesian learning experiences.

Document conversion, formula recognition, spoken math rendering and AI assistant run on-device using **Core ML**, **Apple Vision**, **MathCAT**, and **Apple Foundation Models**.

---

## Key Features

### 1. On-Device Document & Math Conversion
- **Multiple Input Sources**: Import math materials directly from:
  - **Guided Camera Capture** — Real-time document boundary detection with VoiceOver directional prompts (*move left/right/up/down, closer/farther, straighten, hold still*) and haptic feedback; double-tap anywhere once ready to capture.
  - **Photo Library** — Import single-page images (JPEG, PNG, HEIC up to 64 megapixels).
  - **Files (PDF)** — Import multi-page PDF documents.
- **Import Limits & Atomic Saves**: Supports files up to **50 MB** and up to **10 pages per PDF**. If any page fails readability checks, the app reports the exact page number(s) and avoids saving partial materials.
- **Automated Structuring**: Extracts layout, prose, formulas, and visual diagrams into topic-grouped sections, generates an overview, and uses on-device Foundation Models (when available) to suggest concise material titles and source book metadata.

### 2. Accessible Step-by-Step Math Reader
- **Spoken Indonesian Mathematics**: Converts LaTeX/MathML expressions into natural spoken Indonesian using native **MathCAT**.
- **Switchable Reading Styles**: Toggle between **ClearSpeak** (*Bacaan terperinci*) and **SimpleSpeak** (*Bacaan ringkas*) directly inside the topic reader. SpeakEasy readings are also preserved when produced by the pipeline.
- **Sentence-by-Sentence Navigation**: Breaks each topic into navigable sentences grouped by content type (prose, analogies, *Notasi Matematika*, and *Visual Matematika*) so students can learn at their own pace.
- **VoiceOver-First Design**: Wraps UI and learning text with `id-ID` SSML speech tags (`IndonesianSpeech`), manages VoiceOver focus transitions across onboarding, topics, import progress, and sheets, and respects Dynamic Type, Increased Contrast, and Reduce Motion.

### 3. On-Device AI Assistant (*Asisten Metra*)
- **Context-Aware Q&A**: Double-tap any sentence in a topic to open *Asisten Metra* pre-loaded with the selected sentence, topic title, material title, and surrounding context.
- **Text & Indonesian Voice Input**: Type questions directly (no microphone/speech permission needed) or record spoken Indonesian questions (up to 60 seconds, with VoiceOver Magic Tap support).
- **Accessible Explanations**: Powered by Apple's on-device `FoundationModels` (`SystemLanguageModel.default`), constrained to reply in concise, plain-text Indonesian suitable for screen readers without Markdown or visual-only references.
- **Device Requirements**: Requires an Apple Intelligence–capable device with Apple Intelligence enabled and the iOS device language set to **English** (the app provides guidance and a shortcut to Settings when unavailable).

### 4. Teacher Classroom Channels (CloudKit)
- **Join via Invite Code**: Students enter a 6-character classroom code from their teacher to join a class backed by **CloudKit**.
- **Automatic Material Sync**: Fetches shared classroom materials, displays teacher/class source badges, subscribes to CloudKit updates, and automatically saves received materials to the student's local phone storage.
- **Student Display Profile**: Supports customizable student display names (defaults to `Siswa-XXXXXX`) and manual/pull-to-refresh syncing.

### 5. Offline Saved Math Material Management
- **Local Persistence**: Stores converted and teacher-shared math materials on-device via **SwiftData** (with an automatic in-memory fallback if persistent store initialization fails).
- **Search & Organization**: Newest math materials appear first; search by title, category, or overview with VoiceOver result announcements, rename titles, or swipe/tap to delete materials.

---

## Architecture & Project Structure

The app follows a layered **MVVM + Coordinator** architecture with a dedicated local Swift Package for the ML/document pipeline:

```text
MetraStudent/
├── MetraStudent/
│   ├── App/                   # Entry point, AppCoordinator, AppRoutes, DesignSystem
│   ├── Domain/                # Models, domain protocols, TopicSentenceChunker
│   ├── Data/
│   │   ├── AISources/         # FoundationModel adapter & MetraSpeechCapture
│   │   ├── Entities/          # SwiftData entities (MathMaterialEntity)
│   │   ├── Helpers/           # DatabaseSchema
│   │   ├── Managers/          # DocumentConverter, CloudKitManager, NotificationManager
│   │   └── Repositories/      # MathMaterialRepository
│   ├── Presentation/
│   │   ├── Onboarding/        # Accessible 2-step onboarding flow
│   │   ├── Home/              # Material list, classroom channels, guided Camera
│   │   ├── Material/          # Material overview, topic list, title editing
│   │   ├── Section/           # Sentence-level reader & speech style switcher
│   │   └── AIAssistant/       # Voice/text contextual math tutor sheet
│   ├── Info.plist             # Localization (id) & camera/mic/speech usage descriptions
│   └── MetraStudent.entitlements
├── Packages/
│   └── MetraDocumentPipeline/ # Local Swift Package: Core ML models, Vision, MathJax, MathCAT
├── ModelTools/                # Maintainer-only Python scripts for ONNX → Core ML export & parity
├── Tools/                     # Asset integrity & app bundle audit scripts
├── Tests/                     # Assistant logic & regression checks
├── Verification/              # Core ML migration verification report & parity metrics
└── .github/workflows/         # TestFlight CI/CD workflow
```

---

## Tech Stack

| Layer | Technologies |
| --- | --- |
| **UI & Accessibility** | SwiftUI, Observation (`@Observable`), VoiceOver (`AccessibilityFocusState`, `id-ID` SSML), Dynamic Type, UIKit Haptics |
| **Persistence & Sync** | SwiftData (local), CloudKit (`CKContainer`, `CKQuerySubscription`, `CKShare`), UserDefaults |
| **On-Device ML & Vision** | Core ML (CPU FP32), Apple Vision, PDFKit, AVFoundation |
| **Math Speech Engine** | MathCAT (`MathCAT.xcframework`, Rust/C native library), local MathJax bridge |
| **AI & Speech** | Apple `FoundationModels`, `NaturalLanguage`, `Speech` (`SFSpeechRecognizer`), `AVFAudio` |
| **Platform Targets** | iPhone & iPad — iOS 27.0+, Xcode 27, Swift 5 language mode (Swift Tools 6.2) |

---

## Getting Started

### Prerequisites
- **macOS 27** (Apple Silicon recommended)
- **Xcode 27**
- **Git LFS**
- An **Apple Developer account** (required if running on a physical device or using your own CloudKit container)

> Normal app builds do **not** require Python, ONNX Runtime, a Teacher repo checkout, model re-export, or downloading external assets from GitHub Releases.

### 1. Install and Enable Git LFS (Once)

Using Homebrew:

```sh
brew install git-lfs
git lfs install
```

See the [Git LFS documentation](https://docs.github.com/en/repositories/working-with-files/managing-large-files/installing-git-large-file-storage) for alternative installation methods.

### 2. Clone the Repository

Use `git clone` so Git LFS automatically hydrates the Core ML models and `MathCAT.xcframework` (GitHub source ZIP archives may not include LFS binary payloads):

```sh
git clone https://github.com/BiruMerah/metra-student.git
cd metra-student
```

If you cloned before installing Git LFS, hydrate the binaries once:

```sh
git lfs pull
```

### 3. Verify Bundled Assets

Confirm that all required Core ML models and MathCAT slices are hydrated and match their SHA-256 checksums:

```sh
/bin/sh Tools/check-bundled-assets.sh
```

### 4. Open and Run in Xcode

```sh
open MetraStudent.xcodeproj
```

1. Select the **MetraStudent** scheme.
2. Choose an Apple Silicon iOS Simulator or a physical iPhone/iPad.
3. If you are outside the BiruMerah Apple Developer team, follow [Using Your Own CloudKit Container & Schema](#using-your-own-cloudkit-container--schema) below to point the app to your own container.
4. Build and Run (`⌘R`).

### Build for iOS Simulator via CLI

```sh
xcodebuild -project MetraStudent.xcodeproj -scheme MetraStudent \
  -destination 'generic/platform=iOS Simulator' ARCHS=arm64 CODE_SIGNING_ALLOWED=NO build
```

---

## Using Your Own CloudKit Container & Schema

By default, this repository is configured to use the BiruMerah container (`iCloud.id.birumerah.metra`). Because CloudKit containers are tied to an Apple Developer Team, anyone forking or building this project under their own Apple Developer account needs to create their own CloudKit container and replicate the exact schema below in the **Public Database**.

> **Using with Metra: App for Teachers?** Both the Teacher and Student apps must point to the **exact same** CloudKit container identifier so teachers can publish classrooms and materials that students can join and sync.
>
> **SwiftData note:** Local SwiftData storage intentionally sets `cloudKitDatabase: .none` in [`MetraStudentApp.swift`](MetraStudent/App/MetraStudentApp.swift) so it does not conflict with the custom CloudKit container.

### Step 1: Create Your CloudKit Container in Xcode

1. Open `MetraStudent.xcodeproj` and select the **MetraStudent** target → **Signing & Capabilities**.
2. Set **Team** to your Apple Developer Team and change the **Bundle Identifier** (e.g., `com.yourorg.metra.student`).
3. Ensure **iCloud** is enabled with **CloudKit** checked.
4. Click **+** under **Containers** to create a new container (e.g., `iCloud.com.yourorg.metra`), select it, and uncheck `iCloud.id.birumerah.metra`.
5. Ensure **Push Notifications** remains enabled (used for silent `CKQuerySubscription` change notifications).

### Step 2: Update Container Identifiers in Code & Config

Replace `iCloud.id.birumerah.metra` with your container ID in these files:

1. **[`MetraStudent/MetraStudent.entitlements`](MetraStudent/MetraStudent.entitlements)**
   ```xml
   <key>com.apple.developer.icloud-container-identifiers</key>
   <array>
       <string>iCloud.com.yourorg.metra</string>
   </array>
   <key>com.apple.developer.icloud-services</key>
   <array>
       <string>CloudKit</string>
   </array>
   ```
2. **[`MetraStudent/Data/Managers/CloudKitManager.swift`](MetraStudent/Data/Managers/CloudKitManager.swift)**
   ```swift
   let container = CKContainer(identifier: "iCloud.com.yourorg.metra")
   ```
3. *(Optional, for TestFlight/App Store exports)* Update `teamID` in [`ExportOptions.plist`](ExportOptions.plist).

### Step 3: Recreate the Exact CloudKit Schema

You can either import the full `.ckdb` schema in one step with `cktool` (**fastest & exact**), or create the record types, fields, indexes, and permissions manually in the CloudKit Console.

#### Option A: Import the Exact `.ckdb` Schema with `cktool` (Recommended)

Save the following CloudKit Schema Language definition as `schema.ckdb`:

```ckdb
DEFINE SCHEMA

    RECORD TYPE ClassroomChannel (
        "___createTime"   TIMESTAMP,
        "___createdBy"    REFERENCE,
        "___etag"         STRING,
        "___modTime"      TIMESTAMP,
        "___modifiedBy"   REFERENCE,
        "___recordID"     REFERENCE,
        code              STRING,
        createdAt         TIMESTAMP,
        createdBy         STRING,
        members           LIST<STRING>,
        name              STRING,
        ownerUserRecordID STRING QUERYABLE SEARCHABLE SORTABLE,
        shareURL          STRING QUERYABLE SEARCHABLE SORTABLE,
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world"
    );

    RECORD TYPE SharedMaterial (
        "___createTime"    TIMESTAMP,
        "___createdBy"     REFERENCE,
        "___etag"          STRING,
        "___modTime"       TIMESTAMP,
        "___modifiedBy"    REFERENCE,
        "___recordID"      REFERENCE QUERYABLE,
        category           STRING QUERYABLE,
        channelCode        STRING QUERYABLE SEARCHABLE,
        createdAt          TIMESTAMP,
        defaultSpeechStyle STRING,
        fileAsset          ASSET,
        fileName           STRING,
        format             STRING,
        overview           STRING,
        reviewStatus       STRING QUERYABLE,
        revision           INT64,
        roleTag            STRING,
        schemaVersion      INT64,
        senderName         STRING QUERYABLE,
        senderRole         STRING,
        title              STRING QUERYABLE SEARCHABLE SORTABLE,
        updatedAt          TIMESTAMP QUERYABLE SORTABLE,
        validatedAt        TIMESTAMP,
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world"
    );

    RECORD TYPE Users (
        "___createTime" TIMESTAMP,
        "___createdBy"  REFERENCE,
        "___etag"       STRING,
        "___modTime"    TIMESTAMP,
        "___modifiedBy" REFERENCE,
        "___recordID"   REFERENCE,
        roles           LIST<INT64>,
        GRANT WRITE TO "_creator",
        GRANT READ TO "_world"
    );

    RECORD TYPE "cloudkit.share" (
        "___createTime"               TIMESTAMP,
        "___createdBy"                REFERENCE,
        "___etag"                     STRING,
        "___modTime"                  TIMESTAMP,
        "___modifiedBy"               REFERENCE,
        "___recordID"                 REFERENCE,
        "cloudkit.thumbnailImageData" BYTES,
        "cloudkit.title"              STRING,
        "cloudkit.type"               STRING,
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world"
    );
```

Import it into your container's **Development** environment (requires an Apple CloudKit Management Token from CloudKit Console):

```sh
xcrun cktool import-schema \
  --team-id YOUR_TEAM_ID \
  --container-id iCloud.com.yourorg.metra \
  --environment development \
  --file schema.ckdb
```

#### Option B: Manual Setup in CloudKit Console

Open [CloudKit Console](https://icloud.developer.apple.com/), select your container, switch to **Development**, and configure **Schema → Record Types**, **Indexes**, and **Security Roles** in the **Public Database** as follows:

##### 1. `ClassroomChannel`

| Field Name | CloudKit Type | Indexes |
| --- | --- | --- |
| `code` | `String` | — |
| `createdAt` | `Date/Time` (`TIMESTAMP`) | — |
| `createdBy` | `String` | — |
| `members` | `String (List)` (`LIST<STRING>`) | — |
| `name` | `String` | — |
| `ownerUserRecordID` | `String` | **Queryable, Searchable, Sortable** |
| `shareURL` | `String` | **Queryable, Searchable, Sortable** |

##### 2. `SharedMaterial`

| Field Name | CloudKit Type | Indexes |
| --- | --- | --- |
| `recordName` (`___recordID`, system) | System (`REFERENCE`) | **Queryable** |
| `category` | `String` | **Queryable** |
| `channelCode` | `String` | **Queryable, Searchable** |
| `createdAt` | `Date/Time` (`TIMESTAMP`) | — |
| `defaultSpeechStyle` | `String` | — |
| `fileAsset` | `Asset` | — |
| `fileName` | `String` | — |
| `format` | `String` | — |
| `overview` | `String` | — |
| `reviewStatus` | `String` | **Queryable** |
| `revision` | `Int(64)` | — |
| `roleTag` | `String` | — |
| `schemaVersion` | `Int(64)` | — |
| `senderName` | `String` | **Queryable** |
| `senderRole` | `String` | — |
| `title` | `String` | **Queryable, Searchable, Sortable** |
| `updatedAt` | `Date/Time` (`TIMESTAMP`) | **Queryable, Sortable** |
| `validatedAt` | `Date/Time` (`TIMESTAMP`) | — |

##### Security Roles (Public Database)

| Record Type | World (`_world`) | Authenticated (`_icloud`) | Creator (`_creator`) |
| --- | --- | --- | --- |
| `ClassroomChannel` | Read | Create | Write |
| `SharedMaterial` | Read | Create | Write |
| `Users` | Read | — | Write |
| `cloudkit.share` | Read | Create | Write |

#### Troubleshooting Notes for Fresh Containers
- **Querying `ClassroomChannel` by `code` & Subscriptions**: [`CloudKitManager.swift`](MetraStudent/Data/Managers/CloudKitManager.swift) queries `ClassroomChannel` with `NSPredicate(format: "code == %@")` and registers a `CKQuerySubscription` with `NSPredicate(value: true)`. If a brand-new container returns *"Field 'code' is not marked queryable"* or *"recordName is not marked queryable"*, add **Queryable** indexes to `ClassroomChannel.code` and `ClassroomChannel.recordName`.
- **Updating `members` on Join**: Because the base schema grants `WRITE` on `ClassroomChannel` only to `_creator`, students joining a teacher-created channel won't be able to modify `members` unless you also grant **Write** to **Authenticated** (`_icloud`) on `ClassroomChannel`.
- **Student `SharedMaterial` Inline Payload Fields**: [`CloudKitManager.swift`](MetraStudent/Data/Managers/CloudKitManager.swift) reads/writes `content` (`String`) and `materialID` (`String`) on `SharedMaterial`. In **Development**, CloudKit creates these fields automatically on first write; make sure they exist in your schema before deploying to **Production**.

### Step 4: Deploy Schema to Production (Before TestFlight / Release)

Xcode Debug builds use CloudKit's **Development** environment, while TestFlight and App Store builds use **Production**. Before distributing a Release build:
1. Open your container in [CloudKit Console](https://icloud.developer.apple.com/).
2. Click **Deploy Schema Changes…** to promote all record types, indexes, and security roles from **Development** to **Production**.

### Step 5: Quick Smoke Test (Without the Teacher App)

1. Sign into an iCloud account on your simulator or iPhone/iPad (**Settings → Sign in to your iPhone/iPad**).
2. In **CloudKit Console → Data → Records** (Public Database, Development):
   - Create a **`ClassroomChannel`** record with `code = "TEST01"`, `name = "Matematika Uji Coba"`, `createdBy = "Bu Sari"`.
   - Create a **`SharedMaterial`** record with `channelCode = "TEST01"`, `title = "Persamaan Linear"`, `category = "Aljabar"`, `overview = "Pengenalan persamaan linear satu variabel."` (plus `content` with plain text or a JSON `PortableEnvelope` / `MathMaterialModel` payload).
3. Run **Metra Student**, tap **Gabung Kelas**, and enter **`TEST01`**. The classroom and material should sync and automatically save to **Daftar Materi**.

---

## Bundled Core ML Models, MathCAT & Git LFS

Large binary model weights and native MathCAT archives are tracked via Git LFS (configured in [`.gitattributes`](.gitattributes)). The lightweight visual classifier (`MathVisualRepresentationClassifier.mlmodel`) remains in standard Git.

| Primary Binary Asset | Role | Approx. Size |
| --- | --- | ---: |
| `PP-DocLayout-L.mlpackage` | Page layout & region detection | 137.2 MB |
| `PaddleOCR-PP-OCRv5-mobile-rec.mlpackage` | Character & math symbol OCR | 16.4 MB |
| `Pix2Text-MFD.mlpackage` | Mathematical formula region detection | 44.5 MB |
| `UniMERNet-Encoder.mlpackage` | Formula image feature encoding | 104.4 MB |
| `UniMERNet-Decoder.mlpackage` | Autoregressive LaTeX token decoding | 325.7 MB |
| `MathCAT.xcframework` (iOS device slice) | Native spoken-math rendering library | 43.5 MB |
| `MathCAT.xcframework` (iOS Simulator slice) | Native spoken-math library for Simulator | 43.5 MB |

- **Storage & Precision**: The five converted Core ML packages total **631.8 MB** (down ~33% from 948.5 MB in ONNX) by sharing weights losslessly between `first_token` and `cached_token` decoder functions without quantization. Inference runs on **Core ML CPU FP32** to preserve verified numerical parity; ONNX Runtime is completely removed from app dependencies.
- **Git LFS Note**: Git LFS manages large binary files in Git history so they fit within GitHub's 100 MiB regular file limit. It does **not** shrink the compiled app bundle, and end users do not need Git LFS.
- **System Frameworks**: Apple Vision, Speech, and Foundation Models are managed directly by iOS and require no bundling or conversion.

---

## Testing & Verification

### Verify Bundled ML & MathCAT Checksums
```sh
/bin/sh Tools/check-bundled-assets.sh
```

### Run Metra Assistant Logic Checks
Exercises section chunking, prompt construction, typed vs. voice flows, speech style switching, permissions, availability handling, cancellation, and language validation using stubbed capture/generation:

```sh
zsh Tests/run-assistant-checks.sh
```

See [Tests/README.md](Tests/README.md) for the full on-device VoiceOver verification checklist.

### Run `MetraDocumentPipeline` Package Tests
```sh
cd Packages/MetraDocumentPipeline
xcodebuild -scheme MetraDocumentPipeline -destination 'platform=macOS' test
```

### Audit Built `.app` Bundle
Ensures all 6 `.mlmodelc` compiled models are bundled and that no Python scripts, `.onnx` files, Python frameworks, or ONNX Runtime binaries leaked into the app:

```sh
/bin/sh Tools/check-app-bundle.sh /path/to/MetraStudent.app
```

---

## CI/CD (TestFlight)

The GitHub Actions workflow [`.github/workflows/testflight.yml`](.github/workflows/testflight.yml) runs on pushes to `master` or manual dispatch (`workflow_dispatch`):

1. Checks out source and hydrates LFS assets (`lfs: true`).
2. Verifies bundled Core ML & MathCAT SHA-256 checksums (`Tools/check-bundled-assets.sh`).
3. Runs `Tests/run-assistant-checks.sh`.
4. Archives a `Release` iOS build (`CURRENT_PROJECT_VERSION` auto-incremented by `github.run_number`).
5. Audits the archived `.app` bundle (`Tools/check-app-bundle.sh`).
6. Signs and uploads the build to **TestFlight** via App Store Connect API credentials.

---

## Maintainer Model Tooling

The [`ModelTools/`](ModelTools/README.md) directory contains Python scripts used strictly by maintainers on Apple Silicon Macs to re-export ONNX models to Core ML and verify numerical parity. It is outside the Xcode app target and never included in app archives.

---

## Additional Documentation

- [Core ML Migration Verification Report](Verification/COREML-MIGRATION.md) — Numerical parity results (110 passing checks), native test results, LFS clone checks, and bundle audit notes.
- [Bundled Asset Provenance, Attributions & Licenses](Packages/MetraDocumentPipeline/ENGINE-ASSETS.md) — Upstream model commits, hashes, and licensing details.
- [SpeakEasy Math Renderer Notes](Packages/MetraDocumentPipeline/SPEAKEASY-SOURCE.md) — Details on the Larry's Speakeasy Indonesian/English renderer port in MathCAT.
- [Assistant Logic Checks & Device Verification](Tests/README.md) — Automated checks and manual VoiceOver testing guide.
- [Maintainer Model Export Tools](ModelTools/README.md) — Re-export and parity workflow.

---

## Pre-Release & Licensing Notes

- **Physical Device Benchmarks**: Local parity verification validates numerical accuracy on Apple Silicon macOS (CPU FP32) and does not replace latency, memory, and end-to-end document import testing on physical iPhones/iPads prior to release.
- **Third-Party Licenses & Attribution**:
  - **MathCAT**: See [`Packages/MetraDocumentPipeline/LICENSE-MathCAT`](Packages/MetraDocumentPipeline/LICENSE-MathCAT).
  - **UniMERNet**, **PP-DocLayout**, and **PaddleOCR**: Apache-2.0 (see [ENGINE-ASSETS.md](Packages/MetraDocumentPipeline/ENGINE-ASSETS.md) for full academic citations and upstream references).
  - **Pix2Text-MFD**: Upstream contains conflicting license declarations (MIT on the model card vs. AGPL-3.0/Ultralytics in ONNX metadata). Resolve this licensing ambiguity before commercial distribution.
