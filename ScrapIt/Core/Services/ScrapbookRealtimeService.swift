import Foundation
import Supabase

// MARK: - Payloads

struct ScrapbookItemPayload: Codable, Sendable, Equatable {
    let id: UUID
    let photoID: UUID?
    let stickerID: String?
    let centerX: Double
    let centerY: Double
    let width: Double
    let rotation: Double
    let zIndex: Int
    let loopEnabled: Bool
    let maskData: Data?
    let letterID: String?
    let text: String?
    let textColor: String?
    let washiID: String?
    let washiLength: Double?
    let tearSeed: Int?
    let drawingData: Data?

    init(
        id: UUID,
        photoID: UUID? = nil,
        stickerID: String? = nil,
        centerX: Double,
        centerY: Double,
        width: Double,
        rotation: Double,
        zIndex: Int,
        loopEnabled: Bool = true,
        maskData: Data? = nil,
        letterID: String? = nil,
        text: String? = nil,
        textColor: String? = nil,
        washiID: String? = nil,
        washiLength: Double? = nil,
        tearSeed: Int? = nil,
        drawingData: Data? = nil
    ) {
        self.id = id
        self.photoID = photoID
        self.stickerID = stickerID
        self.centerX = centerX
        self.centerY = centerY
        self.width = width
        self.rotation = rotation
        self.zIndex = zIndex
        self.loopEnabled = loopEnabled
        self.maskData = maskData
        self.letterID = letterID
        self.text = text
        self.textColor = textColor
        self.washiID = washiID
        self.washiLength = washiLength
        self.tearSeed = tearSeed
        self.drawingData = drawingData
    }
}

struct CollaboratorPresence: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let colorHex: String
    var currentPageIndex: Int
    var lastActive: Date
    var avatarData: Data?

    init(
        id: String,
        name: String,
        colorHex: String,
        currentPageIndex: Int,
        lastActive: Date = .now,
        avatarData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.currentPageIndex = currentPageIndex
        self.lastActive = lastActive
        self.avatarData = avatarData
    }
}

enum ScrapbookEventType: String, Codable, Sendable {
    case itemPlaced = "item_placed"
    case itemTransformed = "item_transformed"
    case itemTextUpdated = "item_text_updated"
    case itemCut = "item_cut"
    case itemCutUndone = "item_cut_undone"
    case itemRemoved = "item_removed"
    case pageBackground = "page_background"
    case drawingUpdated = "drawing_updated"
    case stickerSheetReset = "sticker_sheet_reset"
    case pageAdded = "page_added"
    case pageDeleted = "page_deleted"
    case pageMoved = "page_moved"
    /// Change 026: a member finished editing (`memberID`), the host locked the scrapbook, the cover color changed
    /// (`coverColor`). Cover items use the item events with page index -1 (front) and -2 (spine).
    case editingDone = "editing_done"
    case scrapbookLocked = "scrapbook_locked"
    case coverColor = "cover_color"
}

struct ScrapbookEvent: Codable, Sendable, Equatable {
    let type: ScrapbookEventType
    let pageIndex: Int
    let senderID: String
    let item: ScrapbookItemPayload?
    let itemID: UUID?
    let centerX: Double?
    let centerY: Double?
    let width: Double?
    let rotation: Double?
    let zIndex: Int?
    let loopEnabled: Bool?
    let maskData: Data?
    let newPieces: [ScrapbookItemPayload]?
    let restoredItem: ScrapbookItemPayload?
    let removedPieceIDs: [UUID]?
    let background: String?
    let drawingData: Data?
    let text: String?
    let textColor: String?
    let stickerSetID: String?
    let targetPageIndex: Int?
    let memberID: String?
    let coverColor: String?

    init(
        type: ScrapbookEventType,
        pageIndex: Int,
        senderID: String,
        item: ScrapbookItemPayload? = nil,
        itemID: UUID? = nil,
        centerX: Double? = nil,
        centerY: Double? = nil,
        width: Double? = nil,
        rotation: Double? = nil,
        zIndex: Int? = nil,
        loopEnabled: Bool? = nil,
        maskData: Data? = nil,
        newPieces: [ScrapbookItemPayload]? = nil,
        restoredItem: ScrapbookItemPayload? = nil,
        removedPieceIDs: [UUID]? = nil,
        background: String? = nil,
        drawingData: Data? = nil,
        text: String? = nil,
        textColor: String? = nil,
        stickerSetID: String? = nil,
        targetPageIndex: Int? = nil,
        memberID: String? = nil,
        coverColor: String? = nil
    ) {
        self.type = type
        self.pageIndex = pageIndex
        self.senderID = senderID
        self.item = item
        self.itemID = itemID
        self.centerX = centerX
        self.centerY = centerY
        self.width = width
        self.rotation = rotation
        self.zIndex = zIndex
        self.loopEnabled = loopEnabled
        self.maskData = maskData
        self.newPieces = newPieces
        self.restoredItem = restoredItem
        self.removedPieceIDs = removedPieceIDs
        self.background = background
        self.drawingData = drawingData
        self.text = text
        self.textColor = textColor
        self.stickerSetID = stickerSetID
        self.targetPageIndex = targetPageIndex
        self.memberID = memberID
        self.coverColor = coverColor
    }
}

// MARK: - Protocol

protocol ScrapbookRealtimeProviding: AnyObject, Sendable {
    func connect(
        rollCode: String,
        currentUser: CollaboratorPresence,
        onEvent: @escaping @MainActor @Sendable (ScrapbookEvent) -> Void,
        onPresenceUpdate: @escaping @MainActor @Sendable ([CollaboratorPresence]) -> Void
    ) async
    func broadcastEvent(_ event: ScrapbookEvent) async
    func updatePresence(pageIndex: Int) async
    func disconnect() async
}

// MARK: - No-Op Service

final class NoopScrapbookRealtimeService: ScrapbookRealtimeProviding {
    init() {}
    func connect(
        rollCode: String,
        currentUser: CollaboratorPresence,
        onEvent: @escaping @MainActor @Sendable (ScrapbookEvent) -> Void,
        onPresenceUpdate: @escaping @MainActor @Sendable ([CollaboratorPresence]) -> Void
    ) async {}
    func broadcastEvent(_ event: ScrapbookEvent) async {}
    func updatePresence(pageIndex: Int) async {}
    func disconnect() async {}
}

// MARK: - Supabase Implementation

final class SupabaseScrapbookRealtimeService: ScrapbookRealtimeProviding, @unchecked Sendable {
    static let eventName = "scrapbook_event"
    static let presenceName = "scrapbook_presence"

    private let client: SupabaseClient
    private var activeChannel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    private var pendingBroadcastTask: Task<Void, Never>?
    private var activeConnectionID: UUID?
    private var currentUser: CollaboratorPresence?
    private var peers: [String: CollaboratorPresence] = [:]

    init(config: SupabaseConfig) {
        let anonKey = config.anonKey
        self.client = SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    autoRefreshToken: false,
                    accessToken: { anonKey }
                )
            )
        )
    }

    func connect(
        rollCode: String,
        currentUser: CollaboratorPresence,
        onEvent: @escaping @MainActor @Sendable (ScrapbookEvent) -> Void,
        onPresenceUpdate: @escaping @MainActor @Sendable ([CollaboratorPresence]) -> Void
    ) async {
        let normalizedCode = rollCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalizedCode.isEmpty else { return }

        await disconnect()

        let connectionID = UUID()
        activeConnectionID = connectionID
        self.currentUser = currentUser
        peers.removeAll()

        let topic = "scrapbook:\(normalizedCode)"
        let channel = client.channel(topic) { config in
            config.broadcast.receiveOwnBroadcasts = false
        }
        let eventStream = channel.broadcastStream(event: Self.eventName)
        let presenceStream = channel.broadcastStream(event: Self.presenceName)

        activeChannel = channel
        listenTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { [weak self] in
                    for await message in eventStream {
                        guard !Task.isCancelled,
                              self?.activeConnectionID == connectionID,
                              let event = Self.decodeEvent(from: message) else {
                            continue
                        }
                        if event.senderID != currentUser.id {
                            await onEvent(event)
                        }
                    }
                }

                group.addTask { [weak self] in
                    for await message in presenceStream {
                        guard !Task.isCancelled,
                              let self,
                              self.activeConnectionID == connectionID,
                              let presence = Self.decodePresence(from: message) else {
                            continue
                        }
                        guard presence.id != currentUser.id else { continue }
                        let allCollaborators: [CollaboratorPresence] = await MainActor.run {
                            self.peers[presence.id] = presence
                            return Array(self.peers.values)
                                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                        }
                        await onPresenceUpdate(allCollaborators)
                    }
                }
            }
        }

        do {
            try await channel.subscribeWithError()
            await broadcastPresence(currentUser)
        } catch {
            if activeConnectionID == connectionID {
                listenTask?.cancel()
                listenTask = nil
                activeChannel = nil
                activeConnectionID = nil
                await client.removeChannel(channel)
            }
        }
    }

    func broadcastEvent(_ event: ScrapbookEvent) async {
        guard let channel = activeChannel else { return }
        let previousTask = pendingBroadcastTask
        let sendTask = Task {
            await previousTask?.value
            if channel.status == .subscribed {
                try? await channel.broadcast(event: Self.eventName, message: event)
            } else {
                try? await channel.httpSend(event: Self.eventName, message: event)
            }
        }
        pendingBroadcastTask = sendTask
        await sendTask.value
    }

    func updatePresence(pageIndex: Int) async {
        guard var current = currentUser else { return }
        current.currentPageIndex = pageIndex
        current.lastActive = .now
        currentUser = current
        await broadcastPresence(current)
    }

    private func broadcastPresence(_ presence: CollaboratorPresence) async {
        guard let channel = activeChannel else { return }
        let previousTask = pendingBroadcastTask
        let sendTask = Task {
            await previousTask?.value
            if channel.status == .subscribed {
                try? await channel.broadcast(event: Self.presenceName, message: presence)
            } else {
                try? await channel.httpSend(event: Self.presenceName, message: presence)
            }
        }
        pendingBroadcastTask = sendTask
        await sendTask.value
    }

    func disconnect() async {
        activeConnectionID = nil
        listenTask?.cancel()
        listenTask = nil
        let inFlight = pendingBroadcastTask
        pendingBroadcastTask = nil
        await inFlight?.value
        guard let channel = activeChannel else { return }
        activeChannel = nil
        await client.removeChannel(channel)
    }

    nonisolated static func decodeEvent(from message: JSONObject) -> ScrapbookEvent? {
        if let nested = message["payload"],
           let decoded = try? nested.decode(as: ScrapbookEvent.self) {
            return decoded
        }
        return try? message.decode(as: ScrapbookEvent.self)
    }

    nonisolated static func decodePresence(from message: JSONObject) -> CollaboratorPresence? {
        if let nested = message["payload"],
           let decoded = try? nested.decode(as: CollaboratorPresence.self) {
            return decoded
        }
        return try? message.decode(as: CollaboratorPresence.self)
    }
}
