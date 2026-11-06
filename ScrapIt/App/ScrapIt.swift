import SwiftData
import SwiftUI

@main
struct ScrapIt: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let modelContainer = ScrapIt.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }

    static let schema = Schema([
        UserProfile.self,
        Scrapbook.self,
        ScrapPhoto.self,
        CaptureSession.self
    ])

    /// Syncs to the user's private CloudKit database (first container in the entitlements;
    /// Development environment when run from Xcode). Without an iCloud account the data stays local.
    /// Falls back to a local-only store so the app never crashes on a CloudKit setup problem.
    static func makeModelContainer() -> ModelContainer {
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            )
        } catch {
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .none)
                )
            } catch {
                fatalError("Could not create the SwiftData container: \(error)")
            }
        }
    }
}
