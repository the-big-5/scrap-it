import Foundation
import Observation
import SwiftData

@Observable
final class ScrapbookViewModel {
    @ObservationIgnored private weak var navigator: (any Navigator)?
    @ObservationIgnored private let sessionStore: SessionStore

    init(navigator: (any Navigator)? = nil, sessionStore: SessionStore = SessionStore()) {
        self.navigator = navigator
        self.sessionStore = sessionStore
    }

    func scrapbook(id: UUID, in scrapbooks: [Scrapbook]) -> Scrapbook? {
        scrapbooks.first(where: { $0.id == id }) ?? sessionStore.activeScrapbook
    }

    func title(for scrapbook: Scrapbook?) -> String {
        scrapbook?.title ?? "Shared Scrapbook"
    }

    func sortedPhotos(of scrapbook: Scrapbook) -> [ScrapPhoto] {
        scrapbook.photos.sorted(by: { $0.timestamp < $1.timestamp })
    }

    func dateText(for scrapbook: Scrapbook) -> String {
        scrapbook.createdDate.formatted(date: .abbreviated, time: .shortened)
    }

    func coOwnersText(for scrapbook: Scrapbook, fallbackName: String) -> String {
        let names = scrapbook.memberNames.isEmpty
            ? fallbackName
            : scrapbook.memberNames.joined(separator: ", ")
        return "Co-owners: \(names)"
    }

    func timeText(for photo: ScrapPhoto) -> String {
        photo.timestamp.formatted(date: .omitted, time: .shortened)
    }

    func commitCaption(modelContext: ModelContext) {
        try? modelContext.save()
    }

    func goBack() {
        navigator?.popToRoot()
    }
}
