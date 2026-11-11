import Foundation
import ImageIO
import SwiftData
import Testing
import UIKit
@testable import ScrapIt

@MainActor
struct ProfileViewModelTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: ScrapIt.schema,
            configurations: ModelConfiguration(UUID().uuidString, schema: ScrapIt.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    private func makeTestImageData(width: Int, height: Int) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { ctx in
            UIColor.systemBrown.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.pngData()!
    }

    @Test func emptyBioAndMissingEmailUseFallbacks() {
        let user = UserProfile(appleUserID: "apple-1", name: "Olifian Lepin")
        context.insert(user)
        let vm = ProfileViewModel(modelContext: context, currentUser: user)

        #expect(vm.displayName == "Olifian Lepin")
        #expect(!vm.hasBio)
        #expect(vm.bioText == ProfileViewModel.emptyBioText)
        #expect(vm.emailText == ProfileViewModel.unavailableEmailText)
    }

    @Test func openEditProfilePopulatesDraftAndPushesRoute() {
        let avatar = makeTestImageData(width: 100, height: 100)
        let user = UserProfile(
            appleUserID: "apple-1",
            name: "Olifian Lepin",
            bio: "Lifelong Learner",
            email: "lepiinn@gmail.com",
            avatarData: avatar
        )
        context.insert(user)
        let router = AppRouter()
        let vm = ProfileViewModel(modelContext: context, currentUser: user, navigator: router)

        vm.openEditProfile()

        #expect(router.path == [.editProfile])
        #expect(vm.draftName == "Olifian Lepin")
        #expect(vm.draftBio == "Lifelong Learner")
        #expect(vm.draftAvatarData == avatar)
        #expect(vm.emailText == "lepiinn@gmail.com")
    }

    @Test func saveProfileChangesUpdatesNameBioAvatarMarksCustomNameAndPops() {
        let user = UserProfile(appleUserID: "apple-1", name: "Ana", email: "ana@example.com")
        context.insert(user)
        let router = AppRouter()
        let vm = ProfileViewModel(modelContext: context, currentUser: user, navigator: router)
        let rawAvatar = makeTestImageData(width: 400, height: 400)

        vm.openEditProfile()
        vm.draftName = "  Olifian Lepin  "
        vm.draftBio = "  Lifelong Learner  "
        vm.setDraftAvatar(rawData: rawAvatar)
        vm.saveProfileChanges()

        #expect(user.name == "Olifian Lepin")
        #expect(user.hasCustomName)
        #expect(user.bio == "Lifelong Learner")
        #expect(user.avatarData != nil)
        #expect(user.email == "ana@example.com")
        #expect(router.path.isEmpty)
    }

    @Test func blankDraftNamePreservesExistingName() {
        let user = UserProfile(appleUserID: "apple-1", name: "Ana")
        context.insert(user)
        let router = AppRouter()
        let vm = ProfileViewModel(modelContext: context, currentUser: user, navigator: router)

        vm.openEditProfile()
        vm.draftName = "   \n  "
        vm.draftBio = "Updated bio"
        vm.saveProfileChanges()

        #expect(user.name == "Ana")
        #expect(!user.hasCustomName)
        #expect(user.bio == "Updated bio")
        #expect(router.path.isEmpty)
    }

    @Test func cancelEditProfileDiscardsDraftAndPops() {
        let user = UserProfile(appleUserID: "apple-1", name: "Ana", bio: "Original")
        context.insert(user)
        let router = AppRouter()
        let vm = ProfileViewModel(modelContext: context, currentUser: user, navigator: router)

        vm.openEditProfile()
        vm.draftName = "Changed"
        vm.draftBio = "Changed bio"
        vm.cancelEditProfile()

        #expect(user.name == "Ana")
        #expect(user.bio == "Original")
        #expect(router.path.isEmpty)
    }

    @Test func removeDraftAvatarClearsAvatarOnSave() {
        let initialAvatar = makeTestImageData(width: 120, height: 120)
        let user = UserProfile(appleUserID: "apple-1", name: "Ana", avatarData: initialAvatar)
        context.insert(user)
        let router = AppRouter()
        let vm = ProfileViewModel(modelContext: context, currentUser: user, navigator: router)

        vm.openEditProfile()
        #expect(vm.hasDraftAvatar)
        vm.removeDraftAvatar()
        #expect(!vm.hasDraftAvatar)
        vm.saveProfileChanges()

        #expect(user.avatarData == nil)
    }

    @Test func signOutRequiresConfirmationAndInvokesCallback() {
        let user = UserProfile(appleUserID: "apple-1", name: "Ana")
        context.insert(user)
        var signedOutCount = 0
        let vm = ProfileViewModel(
            modelContext: context,
            currentUser: user,
            onSignOut: { signedOutCount += 1 }
        )

        vm.requestSignOut()
        #expect(vm.isShowingSignOutConfirmation)
        #expect(signedOutCount == 0)

        vm.confirmSignOut()
        #expect(!vm.isShowingSignOutConfirmation)
        #expect(signedOutCount == 1)
    }

    @Test func avatarProcessorDownsamplesLargeImageToJPEG() {
        let raw = makeTestImageData(width: 1200, height: 900)
        let processed = ProfileAvatarProcessor.process(raw)

        #expect(processed != nil)
        let source = CGImageSourceCreateWithData(processed! as CFData, nil)
        let props = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
        let width = props?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = props?[kCGImagePropertyPixelHeight] as? Int ?? 0
        #expect(max(width, height) <= ProfileAvatarProcessor.maxPixelSize)
    }

    @Test func emptyShelfAndCreateRollPushesSetupRoute() {
        let user = UserProfile(appleUserID: "apple-1", name: "Ana")
        context.insert(user)
        let router = AppRouter()
        let vm = ProfileViewModel(modelContext: context, currentUser: user, navigator: router)

        vm.reload()
        #expect(vm.shelfRows.isEmpty)

        vm.openCreateRoll()
        #expect(router.path == [.createRollSetup])
    }

    @Test func shelfRowsChunkTwelveBooksPerShelf() throws {
        let user = UserProfile(appleUserID: "apple-1", name: "Ana")
        context.insert(user)
        for index in 0..<14 {
            let book = Scrapbook(
                title: "Book \(index)",
                createdDate: Date(timeIntervalSince1970: TimeInterval(index))
            )
            context.insert(book)
        }
        try context.save()

        let router = AppRouter()
        let vm = ProfileViewModel(modelContext: context, currentUser: user, navigator: router)
        vm.reload()

        #expect(vm.shelfRows.count == 2)
        #expect(vm.shelfRows[0].count == 12)
        #expect(vm.shelfRows[1].count == 2)

        let firstBook = vm.shelfRows[0][0].scrapbook
        vm.open(firstBook)
        #expect(router.path == [.scrapbook(firstBook.id)])

        vm.requestDelete(firstBook)
        vm.confirmDelete()
        #expect(vm.shelfRows.count == 2)
        #expect(vm.shelfRows[0].count == 12)
        #expect(vm.shelfRows[1].count == 1)
    }
}
