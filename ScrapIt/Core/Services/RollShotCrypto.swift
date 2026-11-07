import CryptoKit
import Foundation

/// Everything about one shot, sealed into a single encrypted blob for the public database (change 012).
/// Nothing about the shot is stored in readable fields.
nonisolated struct RollShotPayload: Codable, Equatable, Sendable {
    var shotID: UUID
    var sessionID: UUID
    var authorID: String
    var authorName: String
    var caption: String
    var timestamp: Date
    var photo: Data
    var livePhotoMovie: Data?
}

nonisolated enum RollShotCryptoError: Error {
    case badKey
}

/// AES-GCM with a random 256-bit roll key. The key lives only in the roll's room (members-only CKShare).
nonisolated enum RollShotCrypto {
    static func newRollKey() -> Data {
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    }

    static func seal(_ payload: RollShotPayload, key: Data) throws -> Data {
        guard key.count == 32 else { throw RollShotCryptoError.badKey }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let plain = try encoder.encode(payload)
        let box = try AES.GCM.seal(plain, using: SymmetricKey(data: key))
        guard let combined = box.combined else { throw RollShotCryptoError.badKey }
        return combined
    }

    static func open(_ sealed: Data, key: Data) throws -> RollShotPayload {
        guard key.count == 32 else { throw RollShotCryptoError.badKey }
        let box = try AES.GCM.SealedBox(combined: sealed)
        let plain = try AES.GCM.open(box, using: SymmetricKey(data: key))
        return try PropertyListDecoder().decode(RollShotPayload.self, from: plain)
    }
}
