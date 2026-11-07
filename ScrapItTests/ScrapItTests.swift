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
            for: UserProfile.self, Scrapbook.self, ScrapPhoto.self, CaptureSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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

        router.path = [.scrapbookGrid(UUID())]
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
        #expect(router.path == [.scrapbookGrid(newer.id)])
    }
}
