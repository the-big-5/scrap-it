import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import ScrapIt

@MainActor
struct BookshelfReaderTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: ScrapIt.schema,
            configurations: ModelConfiguration(
                UUID().uuidString,
                schema: ScrapIt.schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
    }

    // MARK: - BookshelfRippleMath

    @Test func rippleMathReturnsIdentityWhenIdleOrReduceMotion() {
        let idle = BookshelfRippleMath.transform(touchX: nil, spineMidX: 50, slotPitch: 27, reduceMotion: false)
        #expect(idle == .identity)

        let reduced = BookshelfRippleMath.transform(touchX: 50, spineMidX: 50, slotPitch: 27, reduceMotion: true)
        #expect(reduced == .identity)
    }

    @Test func rippleMathLiftsCenterSpineAndTiltsNeighborsOutward() {
        let pitch: CGFloat = 28
        let touchX: CGFloat = 100

        let center = BookshelfRippleMath.transform(touchX: touchX, spineMidX: 100, slotPitch: pitch, reduceMotion: false)
        #expect(center.liftY == -14)
        #expect(center.scale > 1.07)
        #expect(center.tiltDegrees == 0)

        let leftNeighbor = BookshelfRippleMath.transform(touchX: touchX, spineMidX: 72, slotPitch: pitch, reduceMotion: false)
        let rightNeighbor = BookshelfRippleMath.transform(touchX: touchX, spineMidX: 128, slotPitch: pitch, reduceMotion: false)
        #expect(leftNeighbor.liftY < 0 && leftNeighbor.liftY > center.liftY)
        #expect(rightNeighbor.liftY == leftNeighbor.liftY)
        #expect(leftNeighbor.tiltDegrees < 0)
        #expect(rightNeighbor.tiltDegrees > 0)

        let farAway = BookshelfRippleMath.transform(touchX: touchX, spineMidX: 250, slotPitch: pitch, reduceMotion: false)
        #expect(farAway == .identity)
    }

    @Test func hoveredSlotFindsNearestSpineWithinTolerance() {
        let mids: [CGFloat] = [12, 40, 68, 96]
        #expect(BookshelfRippleMath.hoveredSlot(touchX: 41, slotMidXs: mids, slotWidth: 24) == 1)
        #expect(BookshelfRippleMath.hoveredSlot(touchX: 160, slotMidXs: mids, slotWidth: 24) == nil)
        #expect(BookshelfRippleMath.hoveredSlot(touchX: nil, slotMidXs: mids, slotWidth: 24) == nil)
    }

    // MARK: - BookPullOutMath

    @Test func pullOutMathInterpolatesArcAndCoverSwap() {
        let source = CGRect(x: 40, y: 400, width: 24, height: 150)
        let targetSize = CGSize(width: 340, height: 468)
        let targetCenter = CGPoint(x: 201, y: 454)

        let startCenter = BookPullOutMath.center(
            progress: 0,
            source: CGPoint(x: source.midX, y: source.midY),
            target: targetCenter
        )
        #expect(startCenter == CGPoint(x: 52, y: 475))
        #expect(!BookPullOutMath.showsFrontCover(progress: 0.2))
        #expect(BookPullOutMath.yawDegrees(progress: 0.21) > 40)

        let midCenter = BookPullOutMath.center(
            progress: 0.5,
            source: CGPoint(x: source.midX, y: source.midY),
            target: targetCenter,
            arcLift: 20
        )
        #expect(midCenter.y < (475 + 454) / 2)
        #expect(BookPullOutMath.showsFrontCover(progress: 0.5))

        let endSize = BookPullOutMath.size(progress: 1, source: source.size, target: targetSize)
        #expect(endSize == targetSize)
        #expect(abs(BookPullOutMath.yawDegrees(progress: 1)) < 0.001)
    }

    // MARK: - BookCoverHingeMath

    @Test func coverHingeMathCentersClosedCoverAndOpenSpread() {
        let closedW: CGFloat = 340
        let closedH: CGFloat = 468
        let openW: CGFloat = 600
        let openH: CGFloat = 400

        #expect(BookCoverHingeMath.halfWidth(progress: 0, closedWidth: closedW, openSpreadWidth: openW) == closedW)
        #expect(BookCoverHingeMath.bookHeight(progress: 0, closedHeight: closedH, openSpreadHeight: openH) == closedH)
        #expect(BookCoverHingeMath.rightHalfCenterOffsetX(progress: 0, closedWidth: closedW, openSpreadWidth: openW) == 0)
        #expect(BookCoverHingeMath.hingeAngleDegrees(progress: 0) == 0)
        #expect(!BookCoverHingeMath.showsInsideLeft(hingeAngleDegrees: -45))
        #expect(BookCoverHingeMath.spreadRevealOpacity(progress: 0) == 0)

        #expect(BookCoverHingeMath.hingeAngleDegrees(progress: 0.5) == -90)
        #expect(BookCoverHingeMath.showsInsideLeft(hingeAngleDegrees: -120))
        #expect(BookCoverHingeMath.hingeShadowOpacity(progress: 0.5) > 0.25)

        #expect(BookCoverHingeMath.halfWidth(progress: 1, closedWidth: closedW, openSpreadWidth: openW) == 300)
        #expect(BookCoverHingeMath.bookHeight(progress: 1, closedHeight: closedH, openSpreadHeight: openH) == openH)
        #expect(BookCoverHingeMath.rightHalfCenterOffsetX(progress: 1, closedWidth: closedW, openSpreadWidth: openW) == 150)
        #expect(BookCoverHingeMath.hingeAngleDegrees(progress: 1) == -180)
        #expect(BookCoverHingeMath.spreadRevealOpacity(progress: 1) == 1)
    }

    // MARK: - BookshelfReaderLayout

    @Test func readerLayoutScalesProportionallyForPhoneAndIPad() {
        let phoneCover = BookshelfReaderLayout.closedCoverSize(
            for: CGSize(width: 402, height: 874),
            isPad: false
        )
        #expect(abs((phoneCover.width / phoneCover.height) - (340.0 / 468.0)) < 0.01)

        let padPortraitSpread = BookshelfReaderLayout.spreadScale(
            for: CGSize(width: 820, height: 1180),
            isPad: true
        )
        let padLandscapeSpread = BookshelfReaderLayout.spreadScale(
            for: CGSize(width: 1180, height: 820),
            isPad: true
        )
        #expect(padPortraitSpread > 1.5)
        #expect(padLandscapeSpread > 1.5)
        #expect(ScrapbookInteractiveSpreadBook.spreadWidth(scale: padLandscapeSpread) <= 1180 * 0.85)
    }

    // MARK: - ProfileViewModel Reader Flow

    @Test func profileViewModelOpensAndClosesShelfReaderAndClearsOnDelete() throws {
        let user = UserProfile(appleUserID: "apple-1", name: "Olifian Lepin")
        context.insert(user)

        let book = Scrapbook(title: "Bali '27", memberIDs: ["apple-1"], memberNames: ["Olifian Lepin"])
        book.isLocked = true
        context.insert(book)
        try context.save()

        let vm = ProfileViewModel(
            modelContext: context,
            currentUser: user,
            deletedScrapbooks: DeletedScrapbookList(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        )
        vm.reload()

        let expectedFrame = CGRect(x: 40, y: 375, width: 24, height: 148)
        vm.shelfFrameStore.update(id: book.id, frame: expectedFrame)
        vm.openFromShelf(book)

        #expect(vm.openedScrapbook?.id == book.id)
        #expect(vm.openedBookSourceFrame == expectedFrame)
        #expect(vm.isReaderBackdropBlurred)

        vm.finishClosingShelfReader()
        #expect(vm.openedScrapbook == nil)
        #expect(vm.openedBookSourceFrame == nil)
        #expect(!vm.isReaderBackdropBlurred)

        // Deleting while reader is open closes the reader cleanly and removes the book from the shelf.
        vm.openFromShelf(book)
        vm.requestDelete(book)
        vm.confirmDelete()

        #expect(vm.openedScrapbook == nil)
        #expect(!vm.isReaderBackdropBlurred)
        #expect(vm.shelfRows.isEmpty)
    }

    @Test("Locked and shelf reader spreads turn freely forward and backward within book bounds")
    func spreadTurnClamping() {
        // First spread in a read-only multi-spread book can turn forward (< 0) but not backward (> 0).
        #expect(
            ScrapbookSpreadTurnMath.clampedProgress(
                rawProgress: -0.45,
                spreadIndex: 0,
                spreadCount: 3,
                isAtAddPageSpread: false,
                isBookEditable: false,
                showsAddPagePrompt: false
            ) == -0.45
        )
        #expect(
            ScrapbookSpreadTurnMath.clampedProgress(
                rawProgress: 0.45,
                spreadIndex: 0,
                spreadCount: 3,
                isAtAddPageSpread: false,
                isBookEditable: false,
                showsAddPagePrompt: false
            ) == 0
        )

        // Middle spread turns in both directions.
        #expect(
            ScrapbookSpreadTurnMath.clampedProgress(
                rawProgress: -0.5,
                spreadIndex: 1,
                spreadCount: 3,
                isAtAddPageSpread: false,
                isBookEditable: false,
                showsAddPagePrompt: false
            ) == -0.5
        )
        #expect(
            ScrapbookSpreadTurnMath.clampedProgress(
                rawProgress: 0.5,
                spreadIndex: 1,
                spreadCount: 3,
                isAtAddPageSpread: false,
                isBookEditable: false,
                showsAddPagePrompt: false
            ) == 0.5
        )

        // Final spread without add-page prompt stops forward turns while allowing backward turns.
        #expect(
            ScrapbookSpreadTurnMath.clampedProgress(
                rawProgress: -0.4,
                spreadIndex: 2,
                spreadCount: 3,
                isAtAddPageSpread: false,
                isBookEditable: false,
                showsAddPagePrompt: false
            ) == 0
        )
        #expect(
            ScrapbookSpreadTurnMath.clampedProgress(
                rawProgress: 0.6,
                spreadIndex: 2,
                spreadCount: 3,
                isAtAddPageSpread: false,
                isBookEditable: false,
                showsAddPagePrompt: false
            ) == 0.6
        )

        // Editable book on last spread with add-page prompt CAN advance into add-page spread, then stops there.
        #expect(
            ScrapbookSpreadTurnMath.clampedProgress(
                rawProgress: -0.5,
                spreadIndex: 2,
                spreadCount: 3,
                isAtAddPageSpread: false,
                isBookEditable: true,
                showsAddPagePrompt: true
            ) == -0.5
        )
        #expect(
            ScrapbookSpreadTurnMath.clampedProgress(
                rawProgress: -0.5,
                spreadIndex: 3,
                spreadCount: 3,
                isAtAddPageSpread: true,
                isBookEditable: true,
                showsAddPagePrompt: true
            ) == 0
        )
    }
}
