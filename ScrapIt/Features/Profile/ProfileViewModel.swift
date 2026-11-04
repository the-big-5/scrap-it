import Foundation
import Observation

@Observable
final class ProfileViewModel {
    let currentUser: UserProfile

    init(currentUser: UserProfile) {
        self.currentUser = currentUser
    }

    var displayName: String {
        currentUser.name
    }

    func scrapbookCountText(_ count: Int) -> String {
        "\(count) Shared Scrapbook\(count == 1 ? "" : "s")"
    }

    var statusText: String {
        "Profile shelf design in progress"
    }
}
