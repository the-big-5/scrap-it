import Observation
import SwiftUI
import UIKit

/// A polaroid or letter being dragged from the second tray onto the page (change 022, camera POC).
/// Presentation only: whether it's placed is decided by the editor ViewModel through `onDrop`.
/// All points are in window coordinates (`.global`), because the gesture comes from UIKit (`ScrollPanProbe`).
/// A drag only begins when the finger moves up, so the tray can still scroll sideways.
@Observable
final class TrayDragController {
    enum Payload: Hashable {
        case photo(id: UUID, aspectRatio: CGFloat)
        case letter(LetterDefinition)
    }

    private(set) var payload: Payload?
    private(set) var location: CGPoint = .zero
    private(set) var lift: CGFloat = 0
    private(set) var isOverPage = false
    private(set) var opacity: Double = 1

    /// The page frame in global coordinates.
    @ObservationIgnored var pageFrame: CGRect = .zero
    /// Each tray item's frame (global), to find which item a drag starts on.
    @ObservationIgnored var itemFrames: [Payload: CGRect] = [:]
    /// Called when dropped over the page with the center normalized to the page (0–1). `false` = cancelled.
    @ObservationIgnored var onDrop: ((Payload, CGPoint) -> Bool)?
    @ObservationIgnored private var startLocation: CGPoint = .zero
    @ObservationIgnored private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    @ObservationIgnored private let softHaptic = UIImpactFeedbackGenerator(style: .soft)

    /// Preview size: small over the tray, its placed size over the page.
    var displaySize: CGSize {
        guard let payload else { return .zero }
        let pageWidth = pageFrame.width > 0 ? pageFrame.width : 300
        switch payload {
        case .photo(_, let ratio):
            let width = isOverPage ? pageWidth * 0.45 : 56
            return CGSize(width: width, height: width / max(ratio, 0.1))
        case .letter(let letter):
            let height = isOverPage ? pageWidth * LetterCatalog.placedHeight : 60
            return CGSize(width: height * letter.aspectRatio, height: height)
        }
    }

    func payload(at point: CGPoint) -> Payload? {
        itemFrames.first { $0.value.insetBy(dx: -4, dy: -4).contains(point) }?.key
    }

    /// Starts dragging the tray item at this point. `false` when there is none.
    func begin(at point: CGPoint) -> Bool {
        guard payload == nil, let found = payload(at: point) else { return false }
        payload = found
        location = point
        startLocation = point
        isOverPage = false
        opacity = 1
        lift = 0
        lightHaptic.impactOccurred()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            lift = 1
        }
        return true
    }

    func move(to location: CGPoint) {
        guard payload != nil else { return }
        withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.86)) {
            self.location = location
        }
        let over = pageFrame.contains(location)
        if over != isOverPage {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isOverPage = over
            }
        }
    }

    func end(cancelled: Bool) {
        guard let payload else { return }
        let frame = pageFrame
        let point = CGPoint(x: (location.x - frame.minX) / max(frame.width, 1),
                            y: (location.y - frame.minY) / max(frame.height, 1))
        if !cancelled, isOverPage, frame.contains(location), onDrop?(payload, point) == true {
            softHaptic.impactOccurred()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                lift = 0
            } completion: {
                self.finish()
            }
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isOverPage = false
                location = startLocation
                opacity = 0
            } completion: {
                self.finish()
            }
        }
    }

    private func finish() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            payload = nil
            isOverPage = false
        }
    }
}

/// The item being dragged from the tray, drawn above the page and the trays.
struct TrayDragLayer: View {
    let controller: TrayDragController

    var body: some View {
        GeometryReader { geometry in
            let origin = geometry.frame(in: .global).origin
            content(offset: origin)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func content(offset: CGPoint) -> some View {
        if let payload = controller.payload {
            let size = controller.displaySize
            Group {
                switch payload {
                case .photo(let id, _):
                    PolaroidPreview(photoID: id, size: size)
                case .letter(let letter):
                    Image(letter.assetName)
                        .resizable()
                        .frame(width: size.width, height: size.height)
                }
            }
            .scaleEffect(1 + 0.08 * controller.lift)
            .shadow(color: .black.opacity(0.15 + 0.2 * controller.lift), radius: 2 + 10 * controller.lift, y: 2 + 8 * controller.lift)
            .opacity(controller.opacity)
            .position(x: controller.location.x - offset.x, y: controller.location.y - offset.y)
        }
    }
}

/// A photo with a white print frame; uses the tray's already loaded thumbnail.
private struct PolaroidPreview: View {
    let photoID: UUID
    let size: CGSize

    var body: some View {
        let inset = size.width * ScrapbookItemLayout.frameInsetRatio
        Color(white: 0.85)
            .overlay {
                if let image = ScrapbookImageLoader.shared.cachedImage(for: photoID, pixelSize: PhotoTray.thumbnailPixelSize) {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .padding(inset)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}
