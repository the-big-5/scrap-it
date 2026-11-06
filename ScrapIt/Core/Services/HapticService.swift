import CoreHaptics
import Foundation
import Observation

@Observable
@MainActor
final class HapticService {
    static let shared = HapticService()

    private(set) var isSupported: Bool = false
    private var engine: CHHapticEngine?

    init() {
        self.isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if isSupported {
            setupEngine()
        }
    }

    private func setupEngine() {
        guard isSupported else { return }
        do {
            let newEngine = try CHHapticEngine()
            newEngine.resetHandler = { [weak self] in
                Task { @MainActor in
                    try? self?.engine?.start()
                }
            }
            newEngine.stoppedHandler = { _ in }
            try newEngine.start()
            self.engine = newEngine
        } catch {
            self.engine = nil
        }
    }

    private func resumeEngine() {
        guard isSupported else { return }
        if engine == nil {
            setupEngine()
        } else {
            try? engine?.start()
        }
    }

    private func playPattern(events: [CHHapticEvent]) {
        guard isSupported else { return }
        resumeEngine()
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Safe fallback if haptics cannot be played
        }
    }

    // MARK: - Analog Camera Haptic Patterns

    /// Crisp micro-tick emitted when rolling knurled ribs
    func playRatchetTick() {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        playPattern(events: [event])
    }

    /// Snap impact upon settling into a zoom stop (0.5×, 1.0×, 2.0×)
    func playSnapFeedback() {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.70)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.65)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        playPattern(events: [event])
    }

    /// Heavy, firm mechanical thud on colliding with 0.5× or 2.0× hard endstops
    func playHardStopThud() {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.95)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        playPattern(events: [event])
    }
}
