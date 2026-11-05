import Foundation
import SwiftData

@Model
final class UserProfile {
    var appleUserID: String = ""
    var name: String = ""
    @Attribute(.externalStorage) var avatarData: Data?
    var createdAt: Date = Date.now

    init(appleUserID: String, name: String, avatarData: Data? = nil, createdAt: Date = .now) {
        self.appleUserID = appleUserID
        self.name = name
        self.avatarData = avatarData
        self.createdAt = createdAt
    }
}
