import CoreGraphics
import Foundation
import Observation
import SwiftData

struct BookshelfItem: Identifiable {
    let scrapbook: Scrapbook
    var id: UUID { scrapbook.id }
}

@Observable
final class ProfileViewModel {
    static let emptyScrapbooksText = "Your scrapbooks appear here after a roll ends."
    static let emptyBookshelfText = "Your bookshelf is waiting!"
    static let booksPerShelf = 12
    static let emptyBioText = "No bio yet"
    static let unavailableEmailText = "Not provided"

    private let modelContext: ModelContext
    let currentUser: UserProfile
    @ObservationIgnored private weak var navigator: (any Navigator)?
    private let deletedScrapbooks: DeletedScrapbookList
    private let imageLoader: ScrapbookImageLoader
    @ObservationIgnored private let onSignOut: () -> Void
    @ObservationIgnored private let avatarProcessor: (Data) -> Data?

    /// Newest first (change 013).
    private(set) var scrapbooks: [Scrapbook] = []
    /// Waiting for the delete confirmation.
    var scrapbookPendingDeletion: Scrapbook?
    /// Scrapbook currently opened in the blurred-bookshelf reader overlay (change 128).
    private(set) var openedScrapbook: Scrapbook?
    /// Captured global screen frame of the tapped spine so pull-out starts from its shelf slot (change 128).
    private(set) var openedBookSourceFrame: CGRect?
    /// Non-invalidating global-frame store updated during shelf layout and scroll (change 128).
    @ObservationIgnored let shelfFrameStore = BookshelfFrameStore()
    /// Drives background blur on `ProfileView` while the bookshelf reader is open or animating out.
    var isReaderBackdropBlurred = false

    // MARK: - Edit Profile draft state (change 044)
    var draftName: String = ""
    var draftBio: String = ""
    var draftAvatarData: Data?
    var isShowingSignOutConfirmation = false

    init(
        modelContext: ModelContext,
        currentUser: UserProfile,
        navigator: (any Navigator)? = nil,
        deletedScrapbooks: DeletedScrapbookList = .standard,
        imageLoader: ScrapbookImageLoader = .shared,
        onSignOut: @escaping () -> Void = {},
        avatarProcessor: @escaping (Data) -> Data? = { ProfileAvatarProcessor.process($0) }
    ) {
        self.modelContext = modelContext
        self.currentUser = currentUser
        self.navigator = navigator
        self.deletedScrapbooks = deletedScrapbooks
        self.imageLoader = imageLoader
        self.onSignOut = onSignOut
        self.avatarProcessor = avatarProcessor
    }

    var displayName: String {
        currentUser.name
    }

    var hasBio: Bool {
        !currentUser.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var bioText: String {
        hasBio ? currentUser.bio : Self.emptyBioText
    }

    var avatarData: Data? {
        currentUser.avatarData
    }

    var emailText: String {
        let trimmed = currentUser.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return Self.unavailableEmailText
    }

    var hasDraftAvatar: Bool {
        draftAvatarData != nil
    }

    var scrapbooksCount: Int {
        let descriptor = FetchDescriptor<Scrapbook>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    var scrapbookCountText: String {
        scrapbookCountText(scrapbooksCount)
    }

    func scrapbookCountText(_ count: Int) -> String {
        "\(count) Shared Scrapbook\(count == 1 ? "" : "s")"
    }

    var statusText: String {
        "Profile shelf design in progress"
    }

    // MARK: - Edit Profile (change 044)

    func openEditProfile() {
        prepareEditDraft()
        navigator?.push(.editProfile)
    }

    func prepareEditDraft() {
        draftName = currentUser.name
        draftBio = currentUser.bio
        draftAvatarData = currentUser.avatarData
        isShowingSignOutConfirmation = false
    }

    func setDraftAvatar(rawData: Data) {
        if let processed = avatarProcessor(rawData) {
            draftAvatarData = processed
        }
    }

    func removeDraftAvatar() {
        draftAvatarData = nil
    }

    func saveProfileChanges() {
        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextName = trimmedName.isEmpty ? currentUser.name : trimmedName
        let trimmedBio = draftBio.trimmingCharacters(in: .whitespacesAndNewlines)

        if nextName != currentUser.name {
            currentUser.name = nextName
            currentUser.hasCustomName = true
        }
        currentUser.bio = trimmedBio
        currentUser.avatarData = draftAvatarData
        try? modelContext.save()
        popEditProfile()
    }

    func cancelEditProfile() {
        popEditProfile()
    }

    func requestSignOut() {
        isShowingSignOutConfirmation = true
    }

    func confirmSignOut() {
        isShowingSignOutConfirmation = false
        onSignOut()
    }

    private func popEditProfile() {
        if let navigator, !navigator.path.isEmpty {
            navigator.path.removeLast()
        }
    }

    // MARK: - Scrapbooks (change 013)

    func reload() {
        let descriptor = FetchDescriptor<Scrapbook>(sortBy: [SortDescriptor(\.createdDate, order: .reverse)])
        // The shelf holds saved scrapbooks only; the rest are in Resume Editing (change 125).
        scrapbooks = ((try? modelContext.fetch(descriptor)) ?? []).filter(\.isLocked)
    }

    func coverPage(of scrapbook: Scrapbook) -> ScrapbookPage? {
        scrapbook.sortedPages.first
    }

    func pageCountText(for scrapbook: Scrapbook) -> String {
        let count = max(scrapbook.sortedPages.count, 1)
        return "\(count) page\(count == 1 ? "" : "s")"
    }

    func photosByID(of scrapbook: Scrapbook) -> [UUID: ScrapPhoto] {
        Dictionary((scrapbook.photos ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func photoAspect(for item: ScrapbookItem, in scrapbook: Scrapbook) -> CGFloat? {
        guard let photoID = item.photoID, let photo = (scrapbook.photos ?? []).first(where: { $0.id == photoID }) else {
            return nil
        }
        return imageLoader.aspectRatio(for: photoID, data: photo.imageData)
    }

    func open(_ scrapbook: Scrapbook) {
        navigator?.push(.scrapbook(scrapbook.id))
    }

    /// Opens the tapped book in the playful blurred-bookshelf reader overlay (change 128).
    func openFromShelf(_ scrapbook: Scrapbook) {
        openedBookSourceFrame = shelfFrameStore.frame(for: scrapbook.id)
        openedScrapbook = scrapbook
        isReaderBackdropBlurred = true
    }

    /// Finishes tearing down the reader overlay once its closing animation finishes (change 128).
    func finishClosingShelfReader() {
        openedScrapbook = nil
        openedBookSourceFrame = nil
        isReaderBackdropBlurred = false
    }

    func openCreateRoll() {
        navigator?.push(.createRollSetup)
    }

    /// Groups scrapbooks into wooden shelf rows of up to `booksPerShelf` (12) spines; each spine is the one made in Edit Cover (change 103).
    var shelfRows: [[BookshelfItem]] {
        guard !scrapbooks.isEmpty else { return [] }
        return stride(from: 0, to: scrapbooks.count, by: Self.booksPerShelf).map { start in
            let end = min(start + Self.booksPerShelf, scrapbooks.count)
            return (start..<end).map { index in
                BookshelfItem(scrapbook: scrapbooks[index])
            }
        }
    }

    func requestDelete(_ scrapbook: Scrapbook) {
        scrapbookPendingDeletion = scrapbook
    }

    /// Deletes the scrapbook, its pages / items / drawings, the roll's photos and session on this device,
    /// and remembers the roll so the background restore (012) does not bring it back here.
    /// Cloud data is kept (friends still need it).
    func confirmDelete() {
        guard let scrapbook = scrapbookPendingDeletion else { return }
        let deletedID = scrapbook.id
        scrapbookPendingDeletion = nil
        if openedScrapbook?.id == deletedID {
            finishClosingShelfReader()
        }

        ScrapbookLocalDeletionService.deleteLocalCopy(
            of: scrapbook,
            modelContext: modelContext,
            deletedScrapbooks: deletedScrapbooks
        )
        reload()
    }
}
