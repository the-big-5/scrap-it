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

    private var onOrientationChanged: ((RollCameraOrientation.DeviceOrientation) -> Void)?
    private var onSideChanged: ((RollCameraOrientation.LandscapeSide) -> Void)?
    private var notificationObserver: (any NSObjectProtocol)?

    func start(onOrientationChanged: @escaping (RollCameraOrientation.DeviceOrientation) -> Void) {
        stop()
        self.onOrientationChanged = onOrientationChanged

        // Immediate initial check if device orientation is already known
        if let initial = RollCameraOrientation.deviceOrientation(for: UIDevice.current.orientation) {
            onOrientationChanged(initial)
        }

        // 1. CoreMotion Device Motion (sensor-fused gravity vector, resistant to jitter).
        // Operates even when iOS Portrait Orientation Lock is active in Control Center.
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
                guard let motion else { return }
                if let orientation = RollCameraOrientation.deviceOrientation(
                    accelerationX: motion.gravity.x,
                    accelerationY: motion.gravity.y,
                    accelerationZ: motion.gravity.z
                ) {
                    Task { @MainActor [weak self] in
                        self?.onOrientationChanged?(orientation)
                        if let side = orientation.landscapeSide {
                            self?.onSideChanged?(side)
                        }
                    }
                }
            }
        } else if motionManager.isAccelerometerAvailable {
            // Fallback for hardware without device motion gyro fusion
            motionManager.accelerometerUpdateInterval = 0.1
            motionManager.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
                guard let data else { return }
                if let orientation = RollCameraOrientation.deviceOrientation(
                    accelerationX: data.acceleration.x,
                    accelerationY: data.acceleration.y,
                    accelerationZ: data.acceleration.z
                ) {
                    Task { @MainActor [weak self] in
                        self?.onOrientationChanged?(orientation)
                        if let side = orientation.landscapeSide {
                            self?.onSideChanged?(side)
                        }
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
            if let orientation = RollCameraOrientation.deviceOrientation(for: UIDevice.current.orientation) {
                self?.onOrientationChanged?(orientation)
                if let side = orientation.landscapeSide {
                    self?.onSideChanged?(side)
                }
            }
        }
    }

    func start(onSideChanged: @escaping (RollCameraOrientation.LandscapeSide) -> Void) {
        self.onSideChanged = onSideChanged
        start { [weak self] orientation in
            if let side = orientation.landscapeSide {
                self?.onSideChanged?(side)
            }
        }
        self.onSideChanged = onSideChanged
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
        onOrientationChanged = nil
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
