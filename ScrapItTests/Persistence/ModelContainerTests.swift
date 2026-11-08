import Foundation
import SwiftData
import Testing
@testable import ScrapIt

@MainActor
struct ModelContainerTests {
    /// CloudKit rejects schemas with non-optional attributes without defaults, `.unique`,
    /// or non-optional relationships. Loading with CloudKit on proves the models are compatible.
    @Test func schemaLoadsWithCloudKitEnabled() throws {
        let configuration = ModelConfiguration(
            schema: ScrapIt.schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .automatic
        )
        _ = try ModelContainer(for: ScrapIt.schema, configurations: configuration)
    }

    /// Change 012: only the profile syncs to iCloud; rolls, scrapbooks and photos stay on the phone
    /// (013: scrapbook pages, items and sticker sheets too).
    @Test func onlyTheProfileSyncsToICloud() throws {
        let configurations = ScrapIt.storeConfigurations(profileCloudKit: .automatic, inMemory: true)
        #expect(configurations.count == 2)
        #expect(configurations.contains { $0.schema?.entities.map(\.name) == ["UserProfile"] })
        let local = try #require(configurations.first { $0.name == "Rolls" })
        #expect(Set(local.schema?.entities.map(\.name) ?? []) == [
            "Scrapbook", "ScrapPhoto", "CaptureSession", "ScrapbookPage", "ScrapbookItem", "StickerSheet"
        ])
        #expect(local.cloudKitContainerIdentifier == nil)
    }

    @Test func dataSurvivesReopeningTheStore() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelContainerTests-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let configuration = ModelConfiguration(schema: ScrapIt.schema, url: url, cloudKitDatabase: .none)

        do {
            let container = try ModelContainer(for: ScrapIt.schema, configurations: configuration)
            container.mainContext.insert(UserProfile(appleUserID: "apple-123", name: "Ana"))
            try container.mainContext.save()
        }

        let reopened = try ModelContainer(for: ScrapIt.schema, configurations: configuration)
        let profiles = try reopened.mainContext.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.map(\.appleUserID) == ["apple-123"])
    }
}
