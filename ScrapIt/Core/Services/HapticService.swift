import CoreHaptics
import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class HapticService {
    static let shared = HapticService()

    private(set) var isSupported: Bool = false
    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?

    /// Whether the continuous upload hum is currently active
    var isContinuousHumming: Bool {
        continuousPlayer != nil
    }

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
                    self?.continuousPlayer = nil
                    try? self?.engine?.start()
                }
            }
            newEngine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in
                    self?.continuousPlayer = nil
                }
            }
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

    /// Strong punchy micro-tick emitted when stepping knurled ribs
    func playRatchetTick() {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.95)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.90)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        playPattern(events: [event])
    }

    /// Snap impact upon reaching a lens value on the zoom wheel
    func playSnapFeedback() {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.70)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.65)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        playPattern(events: [event])
    }

    /// Heavy, firm mechanical thud on hitting the min or max zoom
    func playHardStopThud() {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.95)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        playPattern(events: [event])
    }

    /// Crisp mechanical shutter click simulating physical shutter actuation and release
    func playShutterClick() {
        let openIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.90)
        let openSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.85)
        let openEvent = CHHapticEvent(eventType: .hapticTransient, parameters: [openIntensity, openSharpness], relativeTime: 0)

        let closeIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.65)
        let closeSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.70)
        let closeEvent = CHHapticEvent(eventType: .hapticTransient, parameters: [closeIntensity, closeSharpness], relativeTime: 0.05)

        playPattern(events: [openEvent, closeEvent])
    }

    /// Single ultra-sharp, maximum-strength mechanical dial click (change 058)
    func playDialDecrement() {
        stopContinuousHum()
        guard isSupported else {
            let feedback = UIImpactFeedbackGenerator(style: .rigid)
            feedback.prepare()
            feedback.impactOccurred(intensity: 1.0)
            return
        }
        do {
            resumeEngine()
            // Single ultra-sharp, peak-power mechanical transient click
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            let clickEvent1 = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
            let clickEvent2 = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)

            let pattern = try CHHapticPattern(events: [clickEvent1, clickEvent2], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            let feedback = UIImpactFeedbackGenerator(style: .rigid)
            feedback.prepare()
            feedback.impactOccurred(intensity: 1.0)
        }
    }

    /// Gentle pulsed vibration emitted during upload/sync with periodic gaps (change 058)
    func startContinuousHum() {
        guard isSupported else { return }
        resumeEngine()
        guard continuousPlayer == nil else { return }
        do {
            var events: [CHHapticEvent] = []
            let pulseDuration = 0.12
            let gapDuration = 0.28
            let period = pulseDuration + gapDuration
            for time in stride(from: 0.0, to: 30.0, by: period) {
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.20)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.18)
                let event = CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [intensity, sharpness],
                    relativeTime: time,
                    duration: pulseDuration
                )
                events.append(event)
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            continuousPlayer = try engine?.makeAdvancedPlayer(with: pattern)
            continuousPlayer?.loopEnabled = true
            try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
        } catch {
            continuousPlayer = nil
        }
    }

    /// Stops the continuous upload vibration hum (change 058)
    func stopContinuousHum() {
        do {
            try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
        } catch {}
        continuousPlayer = nil
    }
}
