import Foundation

enum SessionStatus: String, Codable {
    case waiting
    case live
    case ended

    private var progressionRank: Int {
        switch self {
        case .waiting: 0
        case .live: 1
        case .ended: 2
        }
    }

    /// Enforces monotonic forward progression (`waiting` → `live` → `ended`).
    static func latest(_ current: SessionStatus, _ incoming: SessionStatus) -> SessionStatus {
        incoming.progressionRank >= current.progressionRank ? incoming : current
    }
}
