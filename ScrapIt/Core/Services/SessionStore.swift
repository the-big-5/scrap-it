import Foundation
import Observation
import SwiftData

/// Shared state for the current roll and its resulting scrapbook, injected into the Roll,
/// Scrapbook and Home ViewModels so those features never import each other.
@Observable
final class SessionStore {
    var activeSession: CaptureSession?
    var activeScrapbook: Scrapbook?

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Ends the active session and creates (or reuses) the shared scrapbook for it.
    @discardableResult
    func finalizeActiveSession() -> Scrapbook? {
        guard let session = activeSession else { return nil }
        session.status = .ended
        if session.endTime == nil {
            session.endTime = .now
        }

        let sessionID = session.id
        let existingDescriptor = FetchDescriptor<Scrapbook>(
            predicate: #Predicate { $0.sourceSessionID == sessionID }
        )
        if let existing = (try? modelContext.fetch(existingDescriptor))?.first {
            attachSessionPhotos(to: existing, sessionID: sessionID)
            activeScrapbook = existing
            return existing
        }

        let scrapbook = Scrapbook(
            title: session.name,
            createdDate: .now,
            memberIDs: session.participantIDs,
            memberNames: session.participantNames,
            sourceSessionID: session.id
        )
        modelContext.insert(scrapbook)
        session.createdScrapbookID = scrapbook.id

        attachSessionPhotos(to: scrapbook, sessionID: sessionID)
        try? modelContext.save()

        activeScrapbook = scrapbook
        return scrapbook
    }

    private func attachSessionPhotos(
        to scrapbook: Scrapbook,
        sessionID: UUID
    ) {
        let photoDescriptor = FetchDescriptor<ScrapPhoto>(
            predicate: #Predicate { $0.sourceSessionID == sessionID },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        if let sessionPhotos = try? modelContext.fetch(photoDescriptor) {
            for photo in sessionPhotos {
                if !(scrapbook.photos ?? []).contains(where: { $0.id == photo.id }) {
                    scrapbook.photos = (scrapbook.photos ?? []) + [photo]
                }
            }
            if scrapbook.coverPhotoData == nil, let first = sessionPhotos.first {
                scrapbook.coverPhotoData = first.imageData
            }
        }
    }
}
