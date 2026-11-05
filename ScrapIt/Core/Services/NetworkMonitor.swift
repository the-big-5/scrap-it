import Network
import Observation

/// Reports whether the device has a usable network connection.
protocol NetworkStatusProviding: AnyObject {
    /// Last known status. `false` until the first update arrives.
    var isOnline: Bool { get }
    /// Waits for the first status update, then returns the current status.
    func currentStatus() async -> Bool
    /// Returns once the device is online (right away if it already is).
    func waitUntilOnline() async
}

@Observable
final class NetworkMonitor: NetworkStatusProviding {
    private(set) var isOnline = false

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var hasStatus = false
    @ObservationIgnored private var waiters: [CheckedContinuation<Bool, Never>] = []
    @ObservationIgnored private var onlineWaiters: [CheckedContinuation<Void, Never>] = []

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                self?.update(online)
            }
        }
        monitor.start(queue: DispatchQueue(label: "ScrapIt.NetworkMonitor"))
    }

    deinit {
        monitor.cancel()
    }

    func currentStatus() async -> Bool {
        if hasStatus { return isOnline }
        return await withCheckedContinuation { waiters.append($0) }
    }

    func waitUntilOnline() async {
        if hasStatus && isOnline { return }
        await withCheckedContinuation { onlineWaiters.append($0) }
    }

    private func update(_ online: Bool) {
        isOnline = online
        hasStatus = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume(returning: online) }
        if online {
            let pendingOnline = onlineWaiters
            onlineWaiters.removeAll()
            pendingOnline.forEach { $0.resume() }
        }
    }
}
