# AI Assistant iOS Project Guidelines

## 1. Core Stack & Technology
- **UI Framework:** SwiftUI (utilizing `@Observable`)
- **Architecture:** Clean Architecture + MVVM
- **Language Version:** Swift 6 (Strict Concurrency & Data Race Safety enforced)
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

## 4. SPM Modular Architecture (Strictly Enforced)
The project strictly implements Clean Architecture across local SPM modules to ensure decoupling. Do NOT place Core Domain or Data logic in the Main App target. 

### 4.1 VoiceAgentKit (Local SPM)
This package contains the core infrastructure and domain logic, divided into specialized targets:
- **`VoiceCore` Target:** Handles hardware audio dependencies (`AVFoundation`, `AVAudioEngine`). Encapsulates VAD (Voice Activity Detection), audio capturing, and TTS playback. Must ensure thread-safe hardware access via `actor`.
- **`AICore` Target:** Pure stateless networking layer. Handles STT (Fast-Whisper via HTTP) and LLM (OpenAI SSE streams). Strictly no UI or `AVFoundation` imports here.
- **`VisionCore` Target:** Handles `AVCaptureSession` and Face Detection (Google ML Kit).

### 4.2 Main App Target (Presentation Only)
- Acts solely as the Composition Root and Presentation Layer.
- Houses SwiftUI Views and `@Observable` ViewModels.
- ViewModels orchestrate the pipeline by importing the SPM targets (`VoiceCore`, `AICore`) via abstract protocols.

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
- Adhere fully to Swift 6 data race safety rules. Complete concurrency checking must be enabled.
- Completely ban `DispatchQueue` and completion handler closures; use `async/await` exclusively.
- Always check for task cancellation (`Task.isCancelled`) when bridging asynchronous code via `Task`.
- Explicitly decorate all UI-bound classes and methods with `@MainActor`.
- Protect mutable shared state using `actor` or `@MainActor` to prevent data races. Ensure all types passing through concurrency boundaries conform to `Sendable`.

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