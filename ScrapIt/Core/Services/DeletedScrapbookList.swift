import Foundation

/// Rolls whose scrapbook the user deleted on this device (change 013). The background restore (012)
/// skips them so a deleted scrapbook does not come back. Cloud data is kept; a new phone restores it [Open].
nonisolated struct DeletedScrapbookList: @unchecked Sendable {
    static let standard = DeletedScrapbookList(defaults: .standard)
    private static let key = "deletedScrapbookSessionIDs"

    let defaults: UserDefaults

    var sessionIDs: Set<UUID> {
        Set((defaults.stringArray(forKey: Self.key) ?? []).compactMap(UUID.init(uuidString:)))
    }

    func contains(_ sessionID: UUID) -> Bool {
        sessionIDs.contains(sessionID)
    }

    func add(_ sessionID: UUID) {
        var ids = sessionIDs
        ids.insert(sessionID)
        defaults.set(ids.map(\.uuidString).sorted(), forKey: Self.key)
    }
}
