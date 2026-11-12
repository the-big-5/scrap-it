import Foundation
import SwiftData

/// Deletes a scrapbook's local copy, roll photos, and session while preserving shared CloudKit data for collaborators.
enum ScrapbookLocalDeletionService {
    static func deleteLocalCopy(
        of scrapbook: Scrapbook,
        modelContext: ModelContext,
        deletedScrapbooks: DeletedScrapbookList = .standard
    ) {
        var photoIDs = (scrapbook.photos ?? []).map(\.id)
        if let sessionID = scrapbook.sourceSessionID {
            deletedScrapbooks.add(sessionID)
            let photos = (try? modelContext.fetch(
                FetchDescriptor<ScrapPhoto>(predicate: #Predicate { $0.sourceSessionID == sessionID })
            )) ?? []
            for photo in photos {
                photoIDs.append(photo.id)
                modelContext.delete(photo)
            }
            let sessions = (try? modelContext.fetch(
                FetchDescriptor<CaptureSession>(predicate: #Predicate { $0.id == sessionID })
            )) ?? []
            for session in sessions {
                modelContext.delete(session)
            }
        }
        modelContext.delete(scrapbook)
        try? modelContext.save()
        LiveMovieFileCache.remove(photoIDs: photoIDs)
    }
}
