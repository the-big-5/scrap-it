//
//  ScrapItTests.swift
//  ScrapItTests
//
//  Created by Olifian Lepin on 03/11/26.
//

import Foundation
import SwiftData
import Testing
@testable import ScrapIt

@MainActor
struct ScrapItTests {
    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ScrapIt.schema,
            configurations: ModelConfiguration(UUID().uuidString, schema: ScrapIt.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    @Test func appRouterParsesValidJoinCode() {
        let code = AppRouter.parseJoinCode(from: URL(string: "scrapit://join?code=n4b13l")!)
        #expect(code == "N4B13L")
    }

    @Test func appRouterRejectsInvalidJoinURL() {
        #expect(AppRouter.parseJoinCode(from: URL(string: "scrapit://join?code=ABC")!) == nil)
        #expect(AppRouter.parseJoinCode(from: URL(string: "scrapit://other")!) == nil)
    }

    @Test func appRouterTracksTabBarVisibility() {
        let router = AppRouter()

        #expect(router.shouldShowTabBar)
        router.isTabBarHidden = true
        #expect(!router.shouldShowTabBar)
        router.selectedTab = .profile
        #expect(router.shouldShowTabBar)
        router.selectedTab = .home
        router.isTabBarHidden = false
        #expect(router.shouldShowTabBar)

        router.path = [.createRollSetup, .createRollFilter]
        #expect(!router.shouldShowTabBar)

        router.path = [.scrapbook(UUID())]
        #expect(!router.shouldShowTabBar)

        router.popToRoot()
        #expect(router.shouldShowTabBar)
    }

    @Test func workbenchAndProfileViewModelsFetchScrapbooksFromContext() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let router = AppRouter()
        let store = SessionStore(modelContext: context)
        let user = UserProfile(appleUserID: "apple-1", name: "Ana")

        let workbenchVM = WorkbenchViewModel(modelContext: context, navigator: router, sessionStore: store)
        let profileVM = ProfileViewModel(modelContext: context, currentUser: user)

        #expect(workbenchVM.scrapbooks.isEmpty)
        #expect(profileVM.scrapbooksCount == 0)
        #expect(profileVM.scrapbookCountText == "0 Shared Scrapbooks")

        workbenchVM.toggleCamera()
        #expect(router.isTabBarHidden)
        workbenchVM.dismissCamera()
        #expect(!router.isTabBarHidden)

        let older = Scrapbook(title: "Trip 1", createdDate: .now.addingTimeInterval(-100))
        let newer = Scrapbook(title: "Trip 2", createdDate: .now)
        context.insert(older)
        context.insert(newer)
        try context.save()

        #expect(workbenchVM.scrapbooks.count == 2)
        #expect(profileVM.scrapbooksCount == 2)
        #expect(profileVM.scrapbookCountText == "2 Shared Scrapbooks")

        workbenchVM.openLatestScrapbook()
        #expect(store.activeScrapbook?.id == newer.id)
        #expect(router.path == [.scrapbook(newer.id)])
    }

    @Test func realtimeEventEncodingAndDecoding() throws {
        let itemPayload = ScrapbookItemPayload(
            id: UUID(),
            photoID: UUID(),
            stickerID: nil,
            centerX: 0.45,
            centerY: 0.55,
            width: 0.38,
            rotation: 0.12,
            zIndex: 3,
            loopEnabled: true,
            maskData: "mask".data(using: .utf8)
        )

        let event = ScrapbookEvent(
            type: .itemPlaced,
            pageIndex: 1,
            senderID: "user-123",
            item: itemPayload
        )

        let encoded = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(ScrapbookEvent.self, from: encoded)

        #expect(decoded.type == .itemPlaced)
        #expect(decoded.pageIndex == 1)
        #expect(decoded.senderID == "user-123")
        #expect(decoded.item?.id == itemPayload.id)
        #expect(decoded.item?.centerX == 0.45)
        #expect(decoded.item?.maskData == itemPayload.maskData)

        let presence = CollaboratorPresence(
            id: "user-456",
            name: "Fikri",
            colorHex: "#27AE60",
            currentPageIndex: 2
        )
        let presenceData = try JSONEncoder().encode(presence)
        let decodedPresence = try JSONDecoder().decode(CollaboratorPresence.self, from: presenceData)
        #expect(decodedPresence.name == "Fikri")
        #expect(decodedPresence.currentPageIndex == 2)

        let washiPayload = ScrapbookItemPayload(
            id: UUID(),
            centerX: 0.5,
            centerY: 0.5,
            width: 0.3,
            rotation: 0.1,
            zIndex: 2,
            letterID: "A",
            text: "Aloha",
            textColor: "#112233",
            washiID: "washi-1",
            washiLength: 0.4,
            tearSeed: 42,
            drawingData: Data("ink".utf8)
        )
        let richEvent = ScrapbookEvent(
            type: .itemCutUndone,
            pageIndex: 1,
            senderID: "user-123",
            loopEnabled: false,
            restoredItem: washiPayload,
            removedPieceIDs: [UUID(), UUID()],
            text: "Aloha",
            textColor: "#112233",
            stickerSetID: "travel"
        )
        let richData = try JSONEncoder().encode(richEvent)
        let decodedRich = try JSONDecoder().decode(ScrapbookEvent.self, from: richData)
        #expect(decodedRich.type == .itemCutUndone)
        #expect(decodedRich.loopEnabled == false)
        #expect(decodedRich.restoredItem?.washiID == "washi-1")
        #expect(decodedRich.restoredItem?.tearSeed == 42)
        #expect(decodedRich.restoredItem?.drawingData == Data("ink".utf8))
        #expect(decodedRich.removedPieceIDs?.count == 2)
        #expect(decodedRich.stickerSetID == "travel")
    }

    @Test func scrapbookViewModelAppliesRemoteRealtimeEvents() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let store = SessionStore(modelContext: context)
        let router = AppRouter()

        let scrapbook = Scrapbook(title: "Vacation", sourceSessionID: UUID())
        context.insert(scrapbook)
        try context.save()

        let mockRealtime = MockScrapbookRealtimeService()
        let user = UserProfile(appleUserID: "host-user", name: "Host")

        let viewModel = ScrapbookViewModel(
            modelContext: context,
            navigator: router,
            sessionStore: store,
            scrapbookID: scrapbook.id,
            currentUser: user,
            realtimeService: mockRealtime
        )
        await viewModel.connectRealtime()

        #expect(viewModel.pages.count == 1)
        #expect(viewModel.currentPage?.pageBackground == .cream)

        // 1. Simulate remote page added
        mockRealtime.simulateIncomingEvent(ScrapbookEvent(
            type: .pageAdded,
            pageIndex: 1,
            senderID: "remote-user",
            background: PageBackground.kraft.rawValue
        ))
        #expect(viewModel.pages.count == 2)
        #expect(viewModel.pages[1].pageBackground == .kraft)

        // 2. Simulate remote item placed on page 0
        let itemID = UUID()
        let remoteItem = ScrapbookItemPayload(
            id: itemID,
            photoID: UUID(),
            centerX: 0.3,
            centerY: 0.4,
            width: 0.5,
            rotation: 0.0,
            zIndex: 1
        )
        mockRealtime.simulateIncomingEvent(ScrapbookEvent(
            type: .itemPlaced,
            pageIndex: 0,
            senderID: "remote-user",
            item: remoteItem
        ))
        #expect(viewModel.pages[0].allItems.count == 1)
        #expect(viewModel.pages[0].allItems.first?.id == itemID)
        #expect(viewModel.pages[0].allItems.first?.centerX == 0.3)

        // 3. Simulate remote item transformed
        mockRealtime.simulateIncomingEvent(ScrapbookEvent(
            type: .itemTransformed,
            pageIndex: 0,
            senderID: "remote-user",
            itemID: itemID,
            centerX: 0.75,
            centerY: 0.85,
            width: 0.6,
            rotation: 0.25,
            zIndex: 4
        ))
        #expect(viewModel.pages[0].allItems.first?.centerX == 0.75)
        #expect(viewModel.pages[0].allItems.first?.zIndex == 4)

        // 4. Simulate remote background change
        mockRealtime.simulateIncomingEvent(ScrapbookEvent(
            type: .pageBackground,
            pageIndex: 0,
            senderID: "remote-user",
            background: PageBackground.grid.rawValue
        ))
        #expect(viewModel.pages[0].pageBackground == .grid)

        // 5. Simulate remote drawing updated
        let sampleDrawingData = "sample-strokes".data(using: .utf8)
        mockRealtime.simulateIncomingEvent(ScrapbookEvent(
            type: .drawingUpdated,
            pageIndex: 0,
            senderID: "remote-user",
            drawingData: sampleDrawingData
        ))
        #expect(viewModel.pages[0].drawingData == sampleDrawingData)

        // 6. Simulate remote collaborator presence update
        let peerPresence = [
            CollaboratorPresence(id: "remote-user", name: "Ana", colorHex: "#E50935", currentPageIndex: 1)
        ]
        mockRealtime.simulateIncomingPresence(peerPresence)
        #expect(viewModel.activeCollaborators.count == 1)
        #expect(viewModel.activeCollaborators.first?.name == "Ana")
        #expect(viewModel.activeCollaborators.first?.currentPageIndex == 1)
    }
}

final class MockScrapbookRealtimeService: ScrapbookRealtimeProviding, @unchecked Sendable {
    var connectedRollCode: String?
    var currentUser: CollaboratorPresence?
    var broadcastedEvents: [ScrapbookEvent] = []
    var eventHandler: (@MainActor @Sendable (ScrapbookEvent) -> Void)?
    var presenceHandler: (@MainActor @Sendable ([CollaboratorPresence]) -> Void)?

    func connect(
        rollCode: String,
        currentUser: CollaboratorPresence,
        onEvent: @escaping @MainActor @Sendable (ScrapbookEvent) -> Void,
        onPresenceUpdate: @escaping @MainActor @Sendable ([CollaboratorPresence]) -> Void
    ) async {
        self.connectedRollCode = rollCode
        self.currentUser = currentUser
        self.eventHandler = onEvent
        self.presenceHandler = onPresenceUpdate
    }

    func broadcastEvent(_ event: ScrapbookEvent) async {
        broadcastedEvents.append(event)
    }

    func updatePresence(pageIndex: Int) async {
        currentUser?.currentPageIndex = pageIndex
    }

    func disconnect() async {
        connectedRollCode = nil
        eventHandler = nil
        presenceHandler = nil
    }

    @MainActor
    func simulateIncomingEvent(_ event: ScrapbookEvent) {
        eventHandler?(event)
    }

    @MainActor
    func simulateIncomingPresence(_ presences: [CollaboratorPresence]) {
        presenceHandler?(presences)
    }
}
