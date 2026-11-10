import Foundation
import SwiftData

@Model
final class UserProfile {
    var appleUserID: String = ""
    var name: String = ""
    var bio: String = ""
    var email: String?
    var hasCustomName: Bool = false
    @Attribute(.externalStorage) var avatarData: Data?
    var createdAt: Date = Date.now

    init(
        appleUserID: String,
        name: String,
        bio: String = "",
        email: String? = nil,
        hasCustomName: Bool = false,
        avatarData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.appleUserID = appleUserID
        self.name = name
        self.bio = bio
        self.email = email
        self.hasCustomName = hasCustomName
        self.avatarData = avatarData
        self.createdAt = createdAt
    }
}
