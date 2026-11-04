import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var appleUserID: String
    var name: String
    @Attribute(.externalStorage) var avatarData: Data?
    var createdAt: Date

    init(appleUserID: String, name: String, avatarData: Data? = nil, createdAt: Date = .now) {
        self.appleUserID = appleUserID
        self.name = name
        self.avatarData = avatarData
        self.createdAt = createdAt
    }
}
