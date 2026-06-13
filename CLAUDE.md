# AI Assistant iOS Project Guidelines

## 1. Core Stack & Technology
- **UI Framework:** SwiftUI (utilizing `@Observable`)
- **Architecture:** Clean Architecture + MVVM
- **Language Version:** Swift 6 across both the app target and `VoiceAgentKit`, under two deliberately different default-isolation regimes (see §6).
- **Concurrency:** Modern Swift Concurrency (`async`/`await`, `Task`, `actor`, `@MainActor`)
- **Deployment Target:** iOS 26.0+
- **Test Framework:** Swift Testing

## 2. Development Philosophy & SOLID Principles
Before generating any code, verify that it strictly adheres to SOLID principles:
- **SRP:** ViewModels must only handle view states and formatting. All business logic must be extracted into Use Cases (Interactors).
- **OCP:** Code should be open for extension but closed for modification. Utilize protocols for abstraction rather than modifying existing classes or structs.
- **LSP:** Subclasses or protocol implementations must be substitutable for their base types without altering the correctness of the program.
- **ISP:** Keep protocols small and specialized. Avoid monolithic protocols (e.g., split a large `Repository` into `ReaderRepository` and `WriterRepository`).
- **DIP:** High-level modules (Domain) must not depend on low-level modules (Data/Presentation). Boundaries must be isolated via protocols.

## 3. Clean Architecture Layering
Strictly separate the project into three layers. Dependencies must only flow inwards: **Presentation/Data -> Domain**.

### 3.1 Domain Layer (Pure Swift, zero framework dependencies)
- **Entities:** Core business data structures (Structs), completely free of technical implementation details.
- **Use Cases:** Each Use Case handles a single business logic implementation. Name them starting with verbs (e.g., `FetchUserProfileUseCase`). Must be defined via protocols.
- **Repository Interfaces:** Protocols defining data operations required by the Domain layer, implemented by the Data layer.

### 3.2 Data Layer (Implementation Details)
- **Repositories:** Implement the protocols defined in the Domain layer. Coordinate between different data sources.
- **Data Sources:** Divided into Remote (Network/API) and Local (SwiftData/CoreData/UserDefaults).
- **DTOs (Data Transfer Objects):** Codable structures representing API responses. Must be mapped to Domain Entities within the Data layer; DTOs must never leak into the Domain layer.

### 3.3 Presentation Layer (UI & State)
- **Views:** Pure SwiftUI views. Keep them as "dumb" as possible, containing zero business logic.
- **ViewModels:** Must use the `@Observable` macro for state management.
  - Must only depend on Use Case protocols, never directly on Repositories.
  - State mutations must execute on the `@MainActor`.

### 3.4 App Feature Folder Layout (Mandatory)
Every App-target feature follows this layout. Before adding a file, decide which layer it belongs to:
```
Features/<Feature>/
├── Domain/
│   ├── <Noun>.swift              # Entities (pure data structs)
│   ├── Repositories/             # Repository interfaces (protocols)
│   └── UseCases/                 # <Verb><Noun>UseCase protocol + <Verb><Noun>Interactor impl
├── Data/                         # Repository implementations, data sources, SwiftData @Model / DTOs
├── Presentation/                 # Views, @Observable ViewModels
└── Preview/                      # Mocks/stubs for SwiftUI Previews
```
Entities and interfaces shared across features live in `Shared/Domain/`.

### 3.5 Naming Conventions (Mandatory)
| Role | Naming | Location |
| --- | --- | --- |
| Entity | noun (`ChatMessage`) | Domain |
| Repository interface (persistence) | `<Noun><Read/Write>Repository` (`ChatSessionReadRepository`, `ConversationRepository`) | Domain/Repositories |
| Repository implementation | concrete mechanism name (`SwiftDataChatStore`, `InMemoryConversationRepository`) | Data |
| External-service port / gateway | gerund (`SpeechRecognizing`, `LLMResponding`) | `VoiceAgentDomain` (Kit) |
| Use Case | protocol `<Verb><Noun>UseCase` + impl `<Verb><Noun>Interactor` | Domain/UseCases |
| ViewModel | `<Feature>ViewModel` | Presentation |
| App Coordinator | `AppCoordinator` (one per app) | `App/` |
| Composition Root | `CompositionRoot` (assembly) | `App/` |

Repository vs gateway: accessing data the app persists itself (conversations, sessions, history) is a **Repository** (use the suffix); talking to an external system/device (STT/LLM/TTS/microphone) is a **gateway port** (use a gerund; lives in the Kit).

### 3.6 Hard Prohibitions (break layering — reject and fix on sight)
- A Repository or data-source **implementation** placed in Domain (implementations live only in Data).
- A ViewModel depending on a Repository or gateway protocol directly — ViewModels may depend **only** on Use Case protocols.
- A Use Case interactor placed in Data (the interactor is business logic; it belongs in Domain).
- Domain importing any framework / UI / networking (only `Foundation` and Kit ports are allowed).
- Adding a protocol that is effectively a Repository without the `Repository` suffix.

**Before adding a file:** pure data → Entity (Domain); a protocol describing "how data is accessed" → Repository interface (Domain); a protocol describing "how one unit of business is performed" → UseCase (Domain); a concrete type touching frameworks/networking/DB → Data; anything a ViewModel calls → must be a UseCase.

## 4. SPM Modular Architecture (Strictly Enforced)
The project strictly implements Clean Architecture across local SPM modules to ensure decoupling. Do NOT place Core Domain or Data logic in the Main App target. 

### 4.1 VoiceAgentKit (Local SPM)
This package contains the core infrastructure and domain logic. The Domain layer is isolated in its own target, and each external dependency (audio hardware, VAD, STT, LLM, TTS) lives in a separate target so it can be replaced independently:
- **`VoiceAgentDomain` Target:** The pure Swift Domain layer. Defines all abstraction boundaries — Entities (`AudioFrame`, `Transcription`, `LLMMessage`, `VADEvent`, etc.) and the protocols every other target implements (`AudioRecording`, `VoiceActivityDetecting`, `SpeechProbabilityScoring`, `SpeechRecognizing`, `LLMResponding`, `SpeechSynthesizing`). Imports `Foundation` ONLY — strictly no `AVFoundation`, `CoreAudio`, networking, or UI. All other targets depend on this; it depends on none of them (DIP).
- **`AVAudioCapture` Target:** Microphone capture implementing `AudioRecording`. Owns the hardware audio dependencies (`AVFoundation`, `AVAudioEngine`, `Accelerate` for downsampling). Must ensure thread-safe hardware access via `actor`.
- **`VoiceActivityDetection` Target:** Speech endpointing/segmentation implementing `VoiceActivityDetecting` (`SpeechEndpointDetector`). Pure logic over `[Float]` windows; no `AVFoundation`. Consumes a `SpeechProbabilityScoring` scorer via injection.
- **`SileroVAD` Target:** A `SpeechProbabilityScoring` implementation backed by the Silero ONNX model (`onnxruntime`). Swappable for any other scorer.
- **`WhisperSTT` Target:** Pure stateless networking layer for Speech-to-Text (self-hosted Whisper via HTTP) implementing `SpeechRecognizing`. Strictly no UI or `AVFoundation` imports.
- **`ProxyLLM` Target:** Pure stateless networking layer for the LLM (SSE streams) implementing `LLMResponding`. Kept separate from `WhisperSTT` so STT and LLM have single responsibilities and can each be replaced independently. Strictly no UI or `AVFoundation` imports.
- **`AppleTTS` Target:** An `AVSpeechSynthesizer` wrapper implementing `SpeechSynthesizing` for real-time text-to-speech synthesis and playback control. `AVFoundation` is isolated to the speaker wrapper file only.

### 4.2 Main App Target (Presentation + Composition Root)
- Houses SwiftUI Views, `@Observable` ViewModels, the per-feature Domain/Data layers, one App Coordinator, and the Composition Root. A turn of the voice pipeline is itself a Use Case (`ProcessVoiceTurnInteractor`), not a free-standing orchestrator object.
- Views and ViewModels depend ONLY on `VoiceAgentDomain` abstractions and feature Use Case protocols (plus `SwiftUI`/`Observation`); they must NOT import concrete Kit modules (`AVAudioCapture`, `SileroVAD`, `WhisperSTT`, `ProxyLLM`, `AppleTTS`, etc.).
- **`CompositionRoot` (`App/CompositionRoot.swift`)** is the ONLY type that imports the concrete Kit targets. It builds the dependency graph (stores, repositories, gateways, interactors, ViewModels) and returns a fully-wired `AppCoordinator`. It is the single place a concrete implementation may be named.
- **`AIAssistantPOCApp` (`@main`)** is a thin entry point only: it calls `CompositionRoot().makeAppCoordinator()` and hands the coordinator to `RootView`. No wiring logic lives here.

#### App Coordinator (`AppCoordinator`)
- A single `@MainActor @Observable` app-level coordinator that owns the child ViewModels (`voice`, `sessionList`, lazily-built `settings`), holds cross-feature navigation state (`rootDestination`, history drawer), and exposes intent methods the root view calls.
- It is the ONE place permitted to hold other ViewModels — this is the documented exception to the "a type in Presentation owns only its own state" expectation, and it exists so individual ViewModels stay unaware of each other and of navigation.
- Its own business dependencies must still be **Use Case protocols** (e.g. `WarmUpServerConnectionUseCase`); like a ViewModel it must NOT depend on a Repository or gateway directly.
- Keep it a coordinator, not a god object: it routes and sequences (open/close, start/select session, warm-up) but contains no STT/LLM/TTS logic — that stays in Use Cases.

## 5. TDD (Test-Driven Development) Specification
When requested to implement new features, strictly follow the **Red-Green-Refactor** cycle:
1. **Red:** Write a failing unit test first.
2. **Green:** Write the minimal production code required to make the test pass.
3. **Refactor:** Clean up the code while ensuring all tests remain green, keeping SOLID and Clean Architecture intact.

### Testing Rules
- Use the `Swift Testing` framework for all test suites.
- Mandatory **Dependency Injection (DI)** via initializers for Mock objects. Global states and Singletons are strictly prohibited in tests.
- Structure test cases using the **Given-When-Then** pattern.
- ViewModel tests must cover all state mutations; Use Case tests must cover both success and comprehensive error-handling paths.

## 6. Swift 6 & Concurrency Rules
Both the app target and `VoiceAgentKit` build in Swift 6 language mode (full data-race safety). They differ ONLY in **default actor isolation**, and that difference is intentional — do not try to "unify" it:

### 6.1 Two isolation regimes
- **App target — MainActor-by-default.** Built with `SWIFT_VERSION = 6.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Every unannotated declaration is implicitly `@MainActor`, which is the right default for Views, ViewModels, and the App Coordinator. Consequently, any type that must live **off** the main actor — pure domain entities, SwiftData `@Model` classes, store/repository types used inside an `actor`/`@ModelActor`, and `static` helpers — MUST be explicitly marked `nonisolated` (e.g. `nonisolated struct ChatMessage`, `@Model nonisolated final class SessionRecord`). Omitting it silently pins data to the main actor and breaks off-main use.
- **VoiceAgentKit — nonisolated-by-default.** Each target sets `.swiftLanguageMode(.v6)` with no `defaultIsolation`, so declarations are nonisolated unless they opt in. Kit ports (`AudioRecording`, `SpeechRecognizing`, `LLMResponding`, …) and their entities stay isolation-free so they compose from any context; hardware/shared mutable state is protected with `actor` (e.g. `AudioEngineRecorder`).

### 6.2 Rules that apply to both
- Adhere fully to Swift 6 data-race safety; complete concurrency checking is on in every target.
- Completely ban `DispatchQueue` and completion-handler closures; use `async/await` exclusively. Inside an `async` method, never call bare `NSLock.lock()/unlock()` — use `lock.withLock { }`.
- Always check for task cancellation (`Task.isCancelled`) when bridging asynchronous code via `Task`.
- In the app target, rely on the MainActor default for UI-bound types rather than re-annotating; reach for `@MainActor` explicitly only where the default does not already apply.
- Protect mutable shared state using `actor` (or, for UI state, the MainActor). Ensure every type crossing a concurrency boundary conforms to `Sendable`.

## 7. AI Response Requirements
- Briefly outline your architectural design approach before presenting the implementation code.
- Always provide the production code alongside its corresponding Protocol, Mock, and Swift Testing implementation.
- If a user request violates SOLID principles or Clean Architecture dependency rules, **directly reject the request**, explain the violation, and propose a compliant alternative.

## 8. Commenting Rules
- **Zero Inline Comments:** Absolutely NO inline comments (`//`) allowed. Code must be completely self-documenting through clean naming, small functions, and strict type safety.
- **Use DocC for Public APIs Only:** Only write standard Swift `///` documentation for public Protocols, methods, and Actors inside the SPM modules to define API contracts.

## 9. Localization (i18n) & Logging Language
- **Supported Languages:** English (`en`, base/development region) and Traditional Chinese (`zh-Hant`) ONLY.
- **All user-facing text MUST be localized.** Every string rendered on screen — UI labels, status text, button titles, alerts, and `Info.plist` usage descriptions (e.g. `NSMicrophoneUsageDescription`) — must be defined in a String Catalog (`.xcstrings`). NEVER hard-code display strings inside Views or ViewModels.
- **ViewModels expose semantic state, not localized strings.** Surface an enum/state (e.g. `RecorderStatus`) and map it to a `LocalizedStringKey` in the View layer, keeping Presentation logic testable and locale-independent.
- **Logs are English ONLY.** All `os.Logger` / diagnostic messages must be written in English and must never be localized.