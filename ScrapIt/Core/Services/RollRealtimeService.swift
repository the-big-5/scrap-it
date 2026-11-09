import Foundation
import Supabase

nonisolated struct RollSlotBroadcast: Codable, Sendable, Equatable {
    let slotsUsed: Int
}

protocol RollSlotRealtimeProviding: AnyObject {
    func connect(
        rollCode: String,
        onSlotUpdate: @escaping @MainActor @Sendable (Int) -> Void,
        onRollEnded: (@MainActor @Sendable () -> Void)?
    ) async
    func broadcastSlotCount(_ slotsUsed: Int) async
    func broadcastRollEnded() async
    func disconnect() async
}

extension RollSlotRealtimeProviding {
    func connect(
        rollCode: String,
        onSlotUpdate: @escaping @MainActor @Sendable (Int) -> Void
    ) async {
        await connect(rollCode: rollCode, onSlotUpdate: onSlotUpdate, onRollEnded: nil)
    }
}

final class NoopRollSlotRealtimeService: RollSlotRealtimeProviding {
    func connect(
        rollCode: String,
        onSlotUpdate: @escaping @MainActor @Sendable (Int) -> Void,
        onRollEnded: (@MainActor @Sendable () -> Void)? = nil
    ) async {}

    func broadcastSlotCount(_ slotsUsed: Int) async {}

    func broadcastRollEnded() async {}

    func disconnect() async {}
}

final class SupabaseRollSlotRealtimeService: RollSlotRealtimeProviding {
    static let slotTakenEvent = "slot_taken"
    static let rollEndedEvent = "roll_ended"

    private let client: SupabaseClient
    private var activeChannel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    private var pendingBroadcastTask: Task<Void, Never>?
    private var activeConnectionID: UUID?

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
        onSlotUpdate: @escaping @MainActor @Sendable (Int) -> Void,
        onRollEnded: (@MainActor @Sendable () -> Void)? = nil
    ) async {
        let normalizedCode = rollCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalizedCode.isEmpty else { return }

        await disconnect()

        let connectionID = UUID()
        activeConnectionID = connectionID

        let topic = "roll:\(normalizedCode)"
        let channel = client.channel(topic) { config in
            config.broadcast.receiveOwnBroadcasts = false
        }
        let stream = channel.broadcastStream(event: Self.slotTakenEvent)
        let rollEndedStream = channel.broadcastStream(event: Self.rollEndedEvent)

        activeChannel = channel
        listenTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { [weak self] in
                    for await message in stream {
                        guard !Task.isCancelled,
                              self?.activeConnectionID == connectionID,
                              let payload = Self.decodeSlotBroadcast(from: message) else {
                            continue
                        }
                        onSlotUpdate(payload.slotsUsed)
                    }
                }
                if let onRollEnded {
                    group.addTask { [weak self] in
                        for await _ in rollEndedStream {
                            guard !Task.isCancelled,
                                  self?.activeConnectionID == connectionID else {
                                continue
                            }
                            onRollEnded()
                        }
                    }
                }
            }
        }

        do {
            try await channel.subscribeWithError()
        } catch {
            // Fall back silently to CloudKit polling when offline or unreachable.
            if activeConnectionID == connectionID {
                listenTask?.cancel()
                listenTask = nil
                activeChannel = nil
                activeConnectionID = nil
                await client.removeChannel(channel)
            }
        }
    }

    func broadcastSlotCount(_ slotsUsed: Int) async {
        guard let channel = activeChannel else { return }
        let payload = RollSlotBroadcast(slotsUsed: slotsUsed)
        let previousTask = pendingBroadcastTask
        let sendTask = Task {
            await previousTask?.value
            if channel.status == .subscribed {
                try? await channel.broadcast(event: Self.slotTakenEvent, message: payload)
            } else {
                try? await channel.httpSend(event: Self.slotTakenEvent, message: payload)
            }
        }
        pendingBroadcastTask = sendTask
        await sendTask.value
    }

    func broadcastRollEnded() async {
        guard let channel = activeChannel else { return }
        let previousTask = pendingBroadcastTask
        let sendTask = Task {
            await previousTask?.value
            let emptyPayload: [String: String] = ["status": "ended"]
            if channel.status == .subscribed {
                try? await channel.broadcast(event: Self.rollEndedEvent, message: emptyPayload)
            } else {
                try? await channel.httpSend(event: Self.rollEndedEvent, message: emptyPayload)
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

    nonisolated static func decodeSlotBroadcast(from message: JSONObject) -> RollSlotBroadcast? {
        if let nested = message["payload"],
           let decoded = try? nested.decode(as: RollSlotBroadcast.self) {
            return decoded
        }
        return try? message.decode(as: RollSlotBroadcast.self)
    }

    nonisolated static func decodeSlotBroadcast(from jsonData: Data) -> RollSlotBroadcast? {
        guard let object = try? JSONDecoder().decode(JSONObject.self, from: jsonData) else {
            return nil
        }
        return decodeSlotBroadcast(from: object)
    }
}
