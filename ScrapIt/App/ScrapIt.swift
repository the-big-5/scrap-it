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
        CaptureSession.self,
        ScrapbookPage.self,
        ScrapbookItem.self,
        StickerSheet.self
    ])

    /// Synced to the user's private iCloud (change 006): only the profile (change 012).
    static let profileSchema = Schema([UserProfile.self])
    /// Local only (change 012): rolls, scrapbooks and photos. Their cloud copy is the encrypted public
    /// `RollShot` records, restored by `ScrapbookArchiveSync`, so they never fill the user's iCloud.
    static let rollSchema = Schema([
        Scrapbook.self, ScrapPhoto.self, CaptureSession.self,
        ScrapbookPage.self, ScrapbookItem.self, StickerSheet.self
    ])

    /// The profile keeps the default store name, so existing sign-ins survive the split.
    static func storeConfigurations(
        profileCloudKit: ModelConfiguration.CloudKitDatabase,
        inMemory: Bool = false
    ) -> [ModelConfiguration] {
        [
            ModelConfiguration(schema: profileSchema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: profileCloudKit),
            ModelConfiguration("Rolls", schema: rollSchema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        ]
    }

    /// The profile syncs to the user's private CloudKit database (first container in the entitlements;
    /// Development environment when run from Xcode). Without an iCloud account it stays local.
    /// Falls back to local-only stores so the app never crashes on a CloudKit setup problem.
    static func makeModelContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: storeConfigurations(profileCloudKit: .automatic))
        } catch {
            do {
                return try ModelContainer(for: schema, configurations: storeConfigurations(profileCloudKit: .none))
            } catch {
                fatalError("Could not create the SwiftData container: \(error)")
            }
        }
    }
}
