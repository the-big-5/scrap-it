import Foundation
import Observation
import SwiftData

@Observable
final class ProfileViewModel {
    private let modelContext: ModelContext
    let currentUser: UserProfile

    init(modelContext: ModelContext, currentUser: UserProfile) {
        self.modelContext = modelContext
        self.currentUser = currentUser
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
}
