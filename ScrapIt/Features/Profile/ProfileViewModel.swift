import CoreGraphics
import Foundation
import Observation
import SwiftData

struct BookSpineStyle: Equatable, Sendable {
    let backgroundHex: UInt32
    let titleHex: UInt32

    /// Exact 12-color book spine palette from Figma `1300:36434` (`1515:30880`..`1515:31233`).
    static let palette: [BookSpineStyle] = [
        BookSpineStyle(backgroundHex: 0xFFFFFF, titleHex: 0x000000),
        BookSpineStyle(backgroundHex: 0xD68D8D, titleHex: 0x000000),
        BookSpineStyle(backgroundHex: 0x3045CC, titleHex: 0xFFFFFF),
        BookSpineStyle(backgroundHex: 0xFAE8C3, titleHex: 0x000000),
        BookSpineStyle(backgroundHex: 0xFFE0C9, titleHex: 0x000000),
        BookSpineStyle(backgroundHex: 0xE1803B, titleHex: 0x000000),
        BookSpineStyle(backgroundHex: 0x2A241F, titleHex: 0xB6B6B6),
        BookSpineStyle(backgroundHex: 0x32AEBE, titleHex: 0x000000),
        BookSpineStyle(backgroundHex: 0x4A161A, titleHex: 0xFFFFFF),
        BookSpineStyle(backgroundHex: 0xCE6A82, titleHex: 0x000000),
        BookSpineStyle(backgroundHex: 0xFAE8C3, titleHex: 0xFFFFFF),
        BookSpineStyle(backgroundHex: 0x1B344E, titleHex: 0xFFFFFF)
    ]
}

struct BookshelfItem: Identifiable {
    let scrapbook: Scrapbook
    let style: BookSpineStyle
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
        scrapbooks = (try? modelContext.fetch(descriptor)) ?? []
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

    func openCreateRoll() {
        navigator?.push(.createRollSetup)
    }

    /// Groups scrapbooks into wooden shelf rows of up to `booksPerShelf` (12) spines, cycling deterministically across the 12 Figma colors.
    var shelfRows: [[BookshelfItem]] {
        guard !scrapbooks.isEmpty else { return [] }
        return stride(from: 0, to: scrapbooks.count, by: Self.booksPerShelf).map { start in
            let end = min(start + Self.booksPerShelf, scrapbooks.count)
            return (start..<end).map { index in
                BookshelfItem(scrapbook: scrapbooks[index], style: spineStyle(at: index))
            }
        }
    }

    func spineStyle(at index: Int) -> BookSpineStyle {
        BookSpineStyle.palette[abs(index) % BookSpineStyle.palette.count]
    }

    func requestDelete(_ scrapbook: Scrapbook) {
        scrapbookPendingDeletion = scrapbook
    }

    /// Deletes the scrapbook, its pages / items / drawings, the roll's photos and session on this device,
    /// and remembers the roll so the background restore (012) does not bring it back here.
    /// Cloud data is kept (friends still need it).
    func confirmDelete() {
        guard let scrapbook = scrapbookPendingDeletion else { return }
        scrapbookPendingDeletion = nil

        var photoIDs = (scrapbook.photos ?? []).map(\.id)
        if let sessionID = scrapbook.sourceSessionID {
            deletedScrapbooks.add(sessionID)
            let photos = (try? modelContext.fetch(FetchDescriptor<ScrapPhoto>(predicate: #Predicate { $0.sourceSessionID == sessionID }))) ?? []
            for photo in photos {
                photoIDs.append(photo.id)
                modelContext.delete(photo)
            }
            let sessions = (try? modelContext.fetch(FetchDescriptor<CaptureSession>(predicate: #Predicate { $0.id == sessionID }))) ?? []
            for session in sessions {
                modelContext.delete(session)
            }
        }
        modelContext.delete(scrapbook)
        try? modelContext.save()
        LiveMovieFileCache.remove(photoIDs: photoIDs)
        reload()
    }
}
