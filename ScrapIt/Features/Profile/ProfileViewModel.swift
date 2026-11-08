import CoreGraphics
import Foundation
import Observation
import SwiftData

@Observable
final class ProfileViewModel {
    static let emptyScrapbooksText = "Your scrapbooks appear here after a roll ends."

    private let modelContext: ModelContext
    let currentUser: UserProfile
    @ObservationIgnored private weak var navigator: (any Navigator)?
    private let deletedScrapbooks: DeletedScrapbookList
    private let imageLoader: ScrapbookImageLoader

    /// Newest first (change 013).
    private(set) var scrapbooks: [Scrapbook] = []
    /// Waiting for the delete confirmation.
    var scrapbookPendingDeletion: Scrapbook?

    init(
        modelContext: ModelContext,
        currentUser: UserProfile,
        navigator: (any Navigator)? = nil,
        deletedScrapbooks: DeletedScrapbookList = .standard,
        imageLoader: ScrapbookImageLoader = .shared
    ) {
        self.modelContext = modelContext
        self.currentUser = currentUser
        self.navigator = navigator
        self.deletedScrapbooks = deletedScrapbooks
        self.imageLoader = imageLoader
    }

    var displayName: String {
        currentUser.name
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
