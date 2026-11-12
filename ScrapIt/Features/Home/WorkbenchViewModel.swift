import Foundation
import Observation
import SwiftData

@Observable
final class WorkbenchViewModel {
    private static let folderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private let modelContext: ModelContext
    @ObservationIgnored private weak var navigator: (any Navigator)?
    private let sessionStore: SessionStore
    private let deletedScrapbooks: DeletedScrapbookList
    private let toolboxTransitionDelay: Duration

    private var scrapbooksRevision: Int = 0
    @ObservationIgnored private var toolboxTask: Task<Void, Never>?

    var isCameraActive: Bool = false {
        didSet {
            syncTabBarVisibility()
        }
    }

    var isToolboxActive: Bool = false {
        didSet {
            syncTabBarVisibility()
        }
    }

    var scrapbookPendingRemoval: Scrapbook?

    /// Return transition phase when navigating back from camera (change 086).
    var cameraReturnPhase: CameraReturnPhase {
        navigator?.cameraReturnPhase ?? .idle
    }

    var cameraReturnAngle: Double {
        navigator?.cameraReturnAngle ?? 0.0
    }

    func animateCameraReturnToIdle() {
        navigator?.animateCameraReturnToIdle()
    }

    func finishCameraReturn() {
        navigator?.finishCameraReturn()
    }

    init(
        modelContext: ModelContext,
        navigator: (any Navigator)? = nil,
        sessionStore: SessionStore,
        deletedScrapbooks: DeletedScrapbookList = .standard,
        toolboxTransitionDelay: Duration = .milliseconds(900)
    ) {
        self.modelContext = modelContext
        self.navigator = navigator
        self.sessionStore = sessionStore
        self.deletedScrapbooks = deletedScrapbooks
        self.toolboxTransitionDelay = toolboxTransitionDelay
    }

    var scrapbooks: [Scrapbook] {
        _ = scrapbooksRevision
        let descriptor = FetchDescriptor<Scrapbook>(
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func reloadScrapbooks() {
        scrapbooksRevision &+= 1
    }

    func toggleCamera() {
        guard !isToolboxActive else { return }
        isCameraActive.toggle()
    }

    func dismissCamera() {
        isCameraActive = false
    }

    func activateToolbox() {
        guard !isCameraActive, !isToolboxActive else { return }
        isToolboxActive = true
        toolboxTask?.cancel()
        toolboxTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if self.toolboxTransitionDelay > .zero {
                    try await Task.sleep(for: self.toolboxTransitionDelay)
                }
                guard !Task.isCancelled, self.isToolboxActive else { return }
                self.isToolboxActive = false
                self.toolboxTask = nil
                self.navigator?.push(.deskCollection(.scrapbooks))
            } catch {
                // Cancelled before navigation completed.
            }
        }
    }

    func cancelToolboxTransition() {
        toolboxTask?.cancel()
        toolboxTask = nil
        if isToolboxActive {
            isToolboxActive = false
        }
    }

    func startCreateRoll() {
        isCameraActive = false
        navigator?.setStack([.createRollSetup])
    }

    func startJoinRoll() {
        isCameraActive = false
        navigator?.setStack([.joinRoll])
    }

    func startCreateRollFromCollection() {
        navigator?.setStack([.createRollSetup])
    }

    func closeCollection() {
        if let navigator, !navigator.path.isEmpty {
            navigator.path.removeLast()
        }
    }

    func openTutorial() {
        // Stub for upcoming tutorial flow
    }

    func openScrapbook(_ scrapbook: Scrapbook) {
        sessionStore.activeScrapbook = scrapbook
        navigator?.push(.scrapbook(scrapbook.id))
    }

    func openLatestScrapbook() {
        if let latest = scrapbooks.first {
            openScrapbook(latest)
        }
    }

    // MARK: - Resume Editing Collection Helpers

    func folderTheme(at index: Int) -> FolderCardTheme {
        let themes = FolderCardTheme.allCases
        return themes[index % themes.count]
    }

    func formattedDate(for scrapbook: Scrapbook) -> String {
        Self.folderDateFormatter.string(from: scrapbook.createdDate)
    }

    func previewPhotos(for scrapbook: Scrapbook) -> [FolderPreviewPhoto] {
        let photos = (scrapbook.photos ?? []).sorted {
            if $0.timestamp != $1.timestamp {
                return $0.timestamp < $1.timestamp
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        guard !photos.isEmpty else { return [] }

        var rng = SeededUUIDGenerator(uuid: scrapbook.id)
        let maxCount = min(4, photos.count)
        let count = Int.random(in: 1...maxCount, using: &rng)
        return photos.shuffled(using: &rng)
            .prefix(count)
            .map { FolderPreviewPhoto(id: $0.id, data: $0.imageData) }
    }

    func requestRemoveFromDevice(_ scrapbook: Scrapbook) {
        scrapbookPendingRemoval = scrapbook
    }

    func confirmRemoveFromDevice() {
        guard let scrapbook = scrapbookPendingRemoval else { return }
        scrapbookPendingRemoval = nil

        ScrapbookLocalDeletionService.deleteLocalCopy(
            of: scrapbook,
            modelContext: modelContext,
            deletedScrapbooks: deletedScrapbooks
        )
        reloadScrapbooks()
    }

    private func syncTabBarVisibility() {
        navigator?.isTabBarHidden = isCameraActive || isToolboxActive
    }
}

private struct SeededUUIDGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(uuid: UUID) {
        let b = uuid.uuid
        let hi = UInt64(b.0)
            | (UInt64(b.1) << 8)
            | (UInt64(b.2) << 16)
            | (UInt64(b.3) << 24)
            | (UInt64(b.4) << 32)
            | (UInt64(b.5) << 40)
            | (UInt64(b.6) << 48)
            | (UInt64(b.7) << 56)
        let lo = UInt64(b.8)
            | (UInt64(b.9) << 8)
            | (UInt64(b.10) << 16)
            | (UInt64(b.11) << 24)
            | (UInt64(b.12) << 32)
            | (UInt64(b.13) << 40)
            | (UInt64(b.14) << 48)
            | (UInt64(b.15) << 56)
        let mixed = hi ^ (lo &* 0x9E3779B97F4A7C15)
        self.state = mixed == 0 ? 0x9E3779B97F4A7C15 : mixed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
