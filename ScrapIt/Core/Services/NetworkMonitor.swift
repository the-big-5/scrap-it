import Network
import Observation

/// Reports whether the device has a usable network connection.
protocol NetworkStatusProviding: AnyObject {
    /// Last known status. `false` until the first update arrives.
    var isOnline: Bool { get }
    /// Waits for the first status update, then returns the current status.
    func currentStatus() async -> Bool
}

@Observable
final class NetworkMonitor: NetworkStatusProviding {
    private(set) var isOnline = false

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var hasStatus = false
    @ObservationIgnored private var waiters: [CheckedContinuation<Bool, Never>] = []

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

    private func update(_ online: Bool) {
        isOnline = online
        hasStatus = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume(returning: online) }
    }
}
