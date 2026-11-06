# 007: Inject ModelContext into ViewModels and Services (Remove View Pollution)
Status: Done

## Why
Currently, 8 SwiftUI Views declare `@Environment(\.modelContext) private var modelContext` solely to forward it into ViewModel and Service action methods (e.g. `startRollCapture(modelContext:)`, `commitCaption(modelContext:)`, `handleAppleSignInSuccess(..., modelContext:)`).
This causes multiple architectural problems:
1. Violates the "Dumb View" rule in `spec/tech.md`: Views are forced to know about persistence mechanics and manage database handles.
2. Pollutes ViewModel and Service API signatures with unnecessary `(modelContext: ModelContext)` parameters.
3. Leaks persistence through multiple layers down into backend services like `CloudKitSessionService`.
4. Clutters unit tests, requiring mock contexts to be passed into individual method calls rather than at initialization.

Fix: Inject `ModelContext` once during initialization into `AuthViewModel`, `SessionStore`, `CloudKitSessionService`, `RollFlowViewModel`, and `ScrapbookViewModel`. Remove `@Environment(\.modelContext)` from all feature views and remove `modelContext` parameters from action method signatures.

## Touches
tech.md (Code structure / ViewModels dependency injection note)

## Changes
- MODIFIED `AuthViewModel`:
  - `modelContext: ModelContext` injected via `init(modelContext: ...)` and stored as private property
  - Remove `modelContext` parameter from `restoreExistingSession()`, `handleAppleSignInSuccess()`, `saveProfile()`, and private helpers
- MODIFIED `SessionStore`:
  - `modelContext: ModelContext` injected via `init(modelContext: ...)`
  - Remove `modelContext` parameter from `finalizeActiveSession()` and `attachSessionPhotos()`
- MODIFIED `CloudKitSessionService`:
  - `modelContext: ModelContext` injected via `init(modelContext: ...)`
  - Remove `modelContext` parameter from `createSession()`, `joinRoll()`, `saveOfflinePhoto()`, `syncPendingOfflinePhotos()`, and `updateQueuedCount()`
- MODIFIED `RollFlowViewModel`:
  - `modelContext: ModelContext` injected via `init(modelContext: ...)`
  - Passes `modelContext` to internal `CloudKitSessionService`
  - Remove `modelContext` parameter from `createRoll()`, `startRollCapture()`, `capturePhoto()`, `cameraDidAppear()`, `simulateHostDisconnect()`, `finalizeSessionAndOpenScrapbook()`, `handleIncomingURL()`
- MODIFIED `ScrapbookViewModel`:
  - `modelContext: ModelContext` injected via `init(modelContext: ...)`
  - Remove `modelContext` parameter from `commitCaption()`
- MODIFIED `RootView` and `MainTabView`:
  - `RootView` obtains `modelContext` from the environment and passes it to `AuthViewModel` and `MainTabView`
  - `MainTabView` receives `modelContext: ModelContext` in its initializer and injects it into `SessionStore`, `RollFlowViewModel`, and `ScrapbookViewModel`
- REMOVED `@Environment(\.modelContext)` and simplified method calls in:
  - `WelcomeSignInView`
  - `CreateRollFilterView`
  - `CreateRollLobbyView`
  - `CaptureSessionView`
  - `JoinRollView`
  - `ScrapbookPhotoCard`
- MODIFIED `AuthViewModelTests`:
  - Passes in-memory `context` to `AuthViewModel` initializer; removes `modelContext` from method invocations

## Tasks
- [x] Update `SessionStore` to accept `modelContext` in `init` and remove `modelContext` parameters from its methods
- [x] Update `CloudKitSessionService` to accept `modelContext` in `init` and remove `modelContext` parameters from its methods
- [x] Update `AuthViewModel` to accept `modelContext` in `init` and remove `modelContext` parameters from its methods
- [x] Update `RollFlowViewModel` to accept `modelContext` in `init` and remove `modelContext` parameters from its methods
- [x] Update `ScrapbookViewModel` to accept `modelContext` in `init` and remove `modelContext` parameters from its methods
- [x] Update `RootView` and `MainTabView` to inject `modelContext` into ViewModels and services
- [x] Remove `@Environment(\.modelContext)` and clean up method calls in all 6 feature views (`WelcomeSignInView`, `CreateRollFilterView`, `CreateRollLobbyView`, `CaptureSessionView`, `JoinRollView`, `ScrapbookPhotoCard`)
- [x] Update `AuthViewModelTests` and any other affected tests to match the new initializers and method signatures
- [x] Build and verify all unit tests pass in Xcode / Simulator

## Out of scope
- Refactoring `MainTabView` navigation structure or removing retained feature ViewModels (Problem 1, to be addressed in a subsequent change file)
- Introducing repository protocols/layers (keeping to direct constructor injection per Option 1)
- SwiftData schema or model property changes
- Any visual design or flow behavior changes
