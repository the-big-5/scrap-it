import Observation
import SwiftUI
import UIKit

/// Peel-and-drag animation state for one sticker going from the sheet to the page (change 013, POC).
/// Presentation only: whether the sticker is placed is decided by the editor ViewModel through `onPlace`.
/// Per-frame values (finger position, tilt) are read only by `StickerDragLayer`.
@Observable
final class StickerDragController {
    struct Session {
        let set: StickerSet
        let sticker: StickerDefinition
        let homeCenter: CGPoint
        let homeWidth: CGFloat
        let grabOffset: CGSize
        let start: CGPoint
    }

    static let coordinateSpace = "scrapbookScreen"

    private(set) var session: Session?
    private(set) var isOverPage = false

    private(set) var location: CGPoint = .zero
    private(set) var lift: CGFloat = 0
    private(set) var tilt: Double = 0
    private(set) var pressScale: CGFloat = 1
    private(set) var displayWidth: CGFloat = 0

    @ObservationIgnored var pageFrame: CGRect = .zero
    @ObservationIgnored var sheetFrame: CGRect = .zero
    @ObservationIgnored var panelTop: CGFloat = .infinity
    /// Sticker dropped on the page (center, width, rotation in radians). `false` = back to the sheet.
    @ObservationIgnored var onPlace: ((StickerDefinition, CGPoint, CGFloat, Double) -> Bool)?

    @ObservationIgnored private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    @ObservationIgnored private let softHaptic = UIImpactFeedbackGenerator(style: .soft)
    @ObservationIgnored private var isFinishing = false
    @ObservationIgnored private var dropThresholdY: CGFloat = .infinity

    var activeStickerID: String? { session?.sticker.id }

    var center: CGPoint {
        guard let session else { return .zero }
        let scale = session.homeWidth > 0 ? displayWidth / session.homeWidth : 1
        return CGPoint(x: location.x - session.grabOffset.width * scale,
                       y: location.y - session.grabOffset.height * scale)
    }

    var flatten: CGFloat {
        guard let session else { return 1 }
        return min(1, hypot(location.x - session.start.x, location.y - session.start.y) / 140)
    }

    var peelAxis: (x: CGFloat, y: CGFloat, z: CGFloat) {
        guard let session else { return (0, 1, 0) }
        let length = max(hypot(session.grabOffset.width, session.grabOffset.height), 1)
        return (x: session.grabOffset.height / length, y: -session.grabOffset.width / length, z: 0)
    }

    var peelAnchor: UnitPoint {
        guard let session, session.homeWidth > 0 else { return .center }
        let height = session.homeWidth / session.sticker.aspectRatio
        return UnitPoint(x: 0.5 + session.grabOffset.width / session.homeWidth,
                         y: 0.5 + session.grabOffset.height / height)
    }


    func begin(_ sticker: StickerDefinition, in set: StickerSet, at finger: CGPoint) {
        guard session == nil, !isFinishing, sheetFrame.width > 0 else { return }
        let scale = sheetFrame.width / set.sheetSize.width
        let home = CGPoint(x: sheetFrame.minX + sticker.frame.midX * scale,
                           y: sheetFrame.minY + sticker.frame.midY * scale)
        session = Session(set: set, sticker: sticker, homeCenter: home,
                          homeWidth: sticker.frame.width * scale,
                          grabOffset: CGSize(width: finger.x - home.x, height: finger.y - home.y),
                          start: finger)
        dropThresholdY = panelTop - 20
        location = finger
        displayWidth = sticker.frame.width * scale
        lift = 0
        tilt = 0
        pressScale = 1
        isOverPage = false
        lightHaptic.impactOccurred()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            lift = 1
        }
    }

    func move(to finger: CGPoint, velocity: CGSize) {
        guard let session, !isFinishing else { return }
        withAnimation(.interactiveSpring(response: 0.16, dampingFraction: 0.86)) {
            location = finger
            tilt = Double(max(-8, min(8, velocity.width / 140)))
        }
        let overPage = finger.y < dropThresholdY
        if overPage != isOverPage {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isOverPage = overPage
                displayWidth = overPage ? pageWidth(for: session) : session.homeWidth
            }
        }
    }

    func end(at finger: CGPoint) {
        guard let session, !isFinishing else { return }
        isFinishing = true
        let stickerCenter = center
        if isOverPage, pageFrame.contains(stickerCenter) {
            stick(session, at: stickerCenter)
        } else {
            returnHome(session)
        }
    }

    func cancel() {
        guard let session, !isFinishing else { return }
        isFinishing = true
        returnHome(session)
    }


    private func stick(_ session: Session, at stickerCenter: CGPoint) {
        let rotation = Double.random(in: -8...8)
        let width = displayWidth
        withAnimation(.spring(response: 0.16, dampingFraction: 0.9)) {
            lift = 0
            pressScale = 0.94
            tilt = rotation
        }
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            softHaptic.impactOccurred()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                pressScale = 1
            }
            try? await Task.sleep(for: .milliseconds(220))
            let placed = onPlace?(session.sticker, stickerCenter, width, rotation * .pi / 180) ?? false
            if placed {
                finish()
            } else {
                returnHome(session)
            }
        }
    }

    private func returnHome(_ session: Session) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
            isOverPage = false
            displayWidth = session.homeWidth
            location = CGPoint(x: session.homeCenter.x + session.grabOffset.width,
                               y: session.homeCenter.y + session.grabOffset.height)
            lift = 0
            tilt = 0
            pressScale = 1
        } completion: {
            self.lightHaptic.impactOccurred()
            self.finish()
        }
    }

    private func finish() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            session = nil
            isOverPage = false
        }
        isFinishing = false
    }

    private func pageWidth(for session: Session) -> CGFloat {
        guard pageFrame.width > 0 else { return session.homeWidth }
        let width = session.sticker.frame.width / session.set.sheetSize.width * pageFrame.width
        return max(width, ScrapbookItem.minWidth * pageFrame.width)
    }
}

/// The sticker being dragged, drawn above the page and the panel.
struct StickerDragLayer: View {
    let controller: StickerDragController

    var body: some View {
        if let session = controller.session {
            let lift = controller.lift
            let peel = 25 * lift * (1 - controller.flatten)
            Image(session.sticker.assetName)
                .resizable()
                .frame(width: controller.displayWidth,
                       height: controller.displayWidth / session.sticker.aspectRatio)
                .drawingGroup()
                .rotation3DEffect(.degrees(peel), axis: controller.peelAxis,
                                  anchor: controller.peelAnchor, perspective: 0.55)
                .scaleEffect((1 + 0.1 * lift) * controller.pressScale)
                .rotationEffect(.degrees(controller.tilt))
                .shadow(color: .black.opacity(0.12 + 0.2 * lift), radius: 1 + 12 * lift, y: 1 + 9 * lift)
                .position(controller.center)
                .allowsHitTesting(false)
        }
    }
}

