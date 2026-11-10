import UIKit

/// Extra running time from iOS (about 30 s) when the app goes to the background in the middle of `work`
/// (change 020): a shot's slot claim, slot broadcast and the start of its upload still finish after the user
/// leaves the app right after taking a photo. Long-lived CloudKit saves then go on without the app.
enum BackgroundTime {
    static func keepAlive(_ name: String, while work: () async -> Void) async {
        let application = UIApplication.shared
        var taskID = UIBackgroundTaskIdentifier.invalid
        taskID = application.beginBackgroundTask(withName: name) {
            // Out of time: iOS suspends the app; the work resumes when it is opened again.
            application.endBackgroundTask(taskID)
            taskID = .invalid
        }
        await work()
        if taskID != .invalid {
            application.endBackgroundTask(taskID)
        }
    }
}
