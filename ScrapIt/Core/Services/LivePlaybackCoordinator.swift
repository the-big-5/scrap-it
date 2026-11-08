import Foundation
import Observation
import UIKit

/// When Live Photos on scrapbook pages may play (change 013, POC rules): app active and not in
/// Low Power Mode. Per item, the editor also needs the page visible, motion on and no gesture.
@Observable
final class LivePlaybackCoordinator {
    static let shared = LivePlaybackCoordinator()

    private(set) var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    private(set) var isAppActive = true

    var allowsPlayback: Bool {
        isAppActive && !isLowPowerMode
    }

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                }
            },
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isAppActive = true }
            },
            center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isAppActive = false }
            }
        ]
    }
}
