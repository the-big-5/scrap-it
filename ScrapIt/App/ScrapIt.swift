import SwiftData
import SwiftUI

@main
struct ScrapIt: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(
            for: [
                UserProfile.self,
                Scrapbook.self,
                ScrapPhoto.self,
                CaptureSession.self
            ]
        )
    }
}
