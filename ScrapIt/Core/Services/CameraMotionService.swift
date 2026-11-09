import CoreMotion
import Foundation
import UIKit

/// Monitors physical device orientation via CoreMotion accelerometer
/// even when iOS system Portrait Orientation Lock is active.
@MainActor
final class CameraMotionService {
    private let motionManager = CMMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.scrapit.cameramotion"
        q.qualityOfService = .userInteractive
        return q
    }()

    private var onSideChanged: ((RollCameraOrientation.LandscapeSide) -> Void)?
    private var notificationObserver: (any NSObjectProtocol)?

    func start(onSideChanged: @escaping (RollCameraOrientation.LandscapeSide) -> Void) {
        stop()
        self.onSideChanged = onSideChanged

        // Immediate initial check if device orientation is already known
        if let initialSide = RollCameraOrientation.landscapeSide(for: UIDevice.current.orientation) {
            onSideChanged(initialSide)
        }

        // 1. CoreMotion Device Motion (sensor-fused gravity vector, resistant to jitter).
        // Operates even when iOS Portrait Orientation Lock is active in Control Center.
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
                guard let motion else { return }
                if let side = RollCameraOrientation.landscapeSide(
                    accelerationX: motion.gravity.x,
                    accelerationY: motion.gravity.y,
                    accelerationZ: motion.gravity.z
                ) {
                    Task { @MainActor [weak self] in
                        self?.onSideChanged?(side)
                    }
                }
            }
        } else if motionManager.isAccelerometerAvailable {
            // Fallback for hardware without device motion gyro fusion
            motionManager.accelerometerUpdateInterval = 0.1
            motionManager.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
                guard let data else { return }
                if let side = RollCameraOrientation.landscapeSide(
                    accelerationX: data.acceleration.x,
                    accelerationY: data.acceleration.y,
                    accelerationZ: data.acceleration.z
                ) {
                    Task { @MainActor [weak self] in
                        self?.onSideChanged?(side)
                    }
                }
            }
        }

        // 2. UIDevice notification fallback (for Simulator and when Orientation Lock is OFF)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        notificationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if let side = RollCameraOrientation.landscapeSide(for: UIDevice.current.orientation) {
                self?.onSideChanged?(side)
            }
        }
    }

    func stop() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        if motionManager.isAccelerometerActive {
            motionManager.stopAccelerometerUpdates()
        }
        if let notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
            self.notificationObserver = nil
        }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        onSideChanged = nil
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
        motionManager.stopAccelerometerUpdates()
        if let notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
        }
    }
}
