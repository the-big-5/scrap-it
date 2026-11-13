import SwiftUI
import UIKit

/// Transform applied to a single book spine during horizontal shelf ripple interaction (change 128).
struct BookshelfSpineTransform: Equatable {
    var liftY: CGFloat
    var scale: CGFloat
    var tiltDegrees: Double

    static let identity = BookshelfSpineTransform(liftY: 0, scale: 1, tiltDegrees: 0)
}

/// Pure proximity ripple math across a horizontal shelf row (change 128).
enum BookshelfRippleMath {
    static func transform(
        touchX: CGFloat?,
        spineMidX: CGFloat,
        slotPitch: CGFloat,
        reduceMotion: Bool
    ) -> BookshelfSpineTransform {
        guard !reduceMotion, let touchX, slotPitch > 0 else {
            return .identity
        }
        let radius = slotPitch * 2.4
        let delta = spineMidX - touchX
        let normalized = min(abs(delta) / radius, 1)
        guard normalized < 1 else { return .identity }

        let cosine = cos(normalized * .pi / 2)
        let weight = cosine * sqrt(cosine)
        let tiltDirection = max(-1, min(1, delta / radius))
        return BookshelfSpineTransform(
            liftY: -14 * weight,
            scale: 1 + 0.08 * weight,
            tiltDegrees: Double(tiltDirection) * 5.5 * Double(weight)
        )
    }

    static func hoveredSlot(touchX: CGFloat?, slotMidXs: [CGFloat], slotWidth: CGFloat) -> Int? {
        guard let touchX, slotWidth > 0, !slotMidXs.isEmpty else { return nil }
        var bestIndex: Int?
        var bestDistance = slotWidth * 0.75
        for (index, midX) in slotMidXs.enumerated() {
            let distance = abs(touchX - midX)
            if distance <= bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }
}

/// Non-invalidating global-frame store for shelf spines so scroll & ripple updates never re-trigger SwiftUI layout.
@MainActor
final class BookshelfFrameStore {
    private var frames: [UUID: CGRect] = [:]

    func update(id: UUID, frame: CGRect) {
        guard frame.width > 0, frame.height > 0 else { return }
        frames[id] = frame
    }

    func frame(for id: UUID) -> CGRect? {
        frames[id]
    }
}

/// Wooden shelf plank asset from Figma (`1515:31687` / `1300:36435`).
struct WoodShelfPlank: View {
    var body: some View {
        Image("WoodShelf")
            .resizable()
            .aspectRatio(349.0 / 25.0, contentMode: .fit)
            .shadow(color: .black.opacity(0.4), radius: 2.5, x: 0, y: 4)
    }
}

/// One shelf row holding up to 12 vertical scrapbook spines resting on `WoodShelfPlank` (Figma `1300:36434`).
struct BookshelfRowView: View {
    let items: [BookshelfItem]
    var frameStore: BookshelfFrameStore?
    var hiddenScrapbookID: UUID?
    let onOpen: (Scrapbook) -> Void
    let onDelete: (Scrapbook) -> Void

    @State private var activeTouchX: CGFloat?
    @State private var lastHoveredSlot: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let spineSpacing: CGFloat = 3.5

    var body: some View {
        VStack(spacing: -1) {
            GeometryReader { rowGeometry in
                let slotsCount = CGFloat(ProfileViewModel.booksPerShelf)
                let totalSpacing = Self.spineSpacing * (slotsCount - 1)
                let slotWidth = max((rowGeometry.size.width - totalSpacing) / slotsCount, 1)
                let slotPitch = slotWidth + Self.spineSpacing
                let slotMidXs = (0..<ProfileViewModel.booksPerShelf).map { index in
                    CGFloat(index) * slotPitch + slotWidth / 2
                }

                HStack(alignment: .bottom, spacing: Self.spineSpacing) {
                    ForEach(0..<ProfileViewModel.booksPerShelf, id: \.self) { slot in
                        if items.indices.contains(slot) {
                            let entry = items[slot]
                            let ripple = BookshelfRippleMath.transform(
                                touchX: activeTouchX,
                                spineMidX: slotMidXs[slot],
                                slotPitch: slotPitch,
                                reduceMotion: reduceMotion
                            )
                            let isHiddenForReader = hiddenScrapbookID == entry.id

                            Button {
                                onOpen(entry.scrapbook)
                            } label: {
                                BookSpineView(scrapbook: entry.scrapbook)
                            }
                            .buttonStyle(BookshelfSpineButtonStyle(reduceMotion: reduceMotion))
                            .scaleEffect(ripple.scale, anchor: .bottom)
                            .rotationEffect(.degrees(ripple.tiltDegrees), anchor: .bottom)
                            .offset(y: ripple.liftY)
                            .opacity(isHiddenForReader ? 0 : 1)
                            .zIndex(ripple.liftY < -1 ? 2 : 0)
                            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: ripple)
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .global)
                            } action: { newFrame in
                                frameStore?.update(id: entry.id, frame: newFrame)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    onDelete(entry.scrapbook)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        } else {
                            Color.clear
                                .aspectRatio(BookSpineView.aspectRatio, contentMode: .fit)
                        }
                    }
                }
                .overlay {
                    ShelfHorizontalRippleOverlay(
                        onChanged: { x in
                            activeTouchX = x
                            let hovered = BookshelfRippleMath.hoveredSlot(
                                touchX: x,
                                slotMidXs: slotMidXs,
                                slotWidth: slotWidth
                            )
                            if let hovered, hovered != lastHoveredSlot, items.indices.contains(hovered) {
                                lastHoveredSlot = hovered
                                if !reduceMotion {
                                    let feedback = UIImpactFeedbackGenerator(style: .light)
                                    feedback.impactOccurred(intensity: 0.45)
                                }
                            }
                        },
                        onEnded: {
                            lastHoveredSlot = nil
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.68)) {
                                activeTouchX = nil
                            }
                        }
                    )
                }
            }
            .aspectRatio(
                (CGFloat(ProfileViewModel.booksPerShelf) * BookSpineView.aspectRatio)
                    + (Self.spineSpacing * CGFloat(ProfileViewModel.booksPerShelf - 1)) / 147.84,
                contentMode: .fit
            )
            .padding(.horizontal, 13)

            WoodShelfPlank()
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: 420)
    }
}

/// Press bounce, lift, shadow depth, and light haptic feedback when touching a shelf spine (change 128).
private struct BookshelfSpineButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 1.05 : 1.0, anchor: .bottom)
            .offset(y: configuration.isPressed ? (reduceMotion ? -2 : -7) : 0)
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.24 : 0.08),
                radius: configuration.isPressed ? 6 : 1,
                y: configuration.isPressed ? 4 : 1
            )
            .animation(
                reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.24, dampingFraction: 0.65),
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, pressed in
                guard pressed, !reduceMotion else { return }
                let feedback = UIImpactFeedbackGenerator(style: .light)
                feedback.prepare()
                feedback.impactOccurred(intensity: 0.55)
            }
    }
}

/// Attaches a horizontal `UIPanGestureRecognizer` directly to the enclosing `UIScrollView` (matching `ScrollPanProbe`),
/// keeping taps, `.contextMenu` long-presses, and vertical scrolling completely intact (change 128).
private struct ShelfHorizontalRippleOverlay: UIViewRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    func makeUIView(context: Context) -> RippleProbeView {
        let view = RippleProbeView()
        view.coordinator = context.coordinator
        context.coordinator.probeView = view
        return view
    }

    func updateUIView(_ uiView: RippleProbeView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.probeView = uiView
    }

    static func dismantleUIView(_ uiView: RippleProbeView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class RippleProbeView: UIView {
        weak var coordinator: Coordinator?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            var ancestor = superview
            while let current = ancestor, !(current is UIScrollView) {
                ancestor = current.superview
            }
            if let scrollView = ancestor as? UIScrollView {
                coordinator?.install(on: scrollView)
            }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void
        var onEnded: () -> Void
        weak var probeView: RippleProbeView?
        private weak var pan: UIPanGestureRecognizer?

        init(onChanged: @escaping (CGFloat) -> Void, onEnded: @escaping () -> Void) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        func install(on scrollView: UIScrollView) {
            guard pan?.view !== scrollView else { return }
            teardown()
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            scrollView.addGestureRecognizer(recognizer)
            scrollView.panGestureRecognizer.require(toFail: recognizer)
            pan = recognizer
        }

        func teardown() {
            if let pan {
                pan.view?.removeGestureRecognizer(pan)
            }
            pan = nil
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let probeView,
                  probeView.window != nil
            else {
                return false
            }
            let velocity = pan.velocity(in: probeView)
            guard abs(velocity.x) > 12, abs(velocity.x) > abs(velocity.y) * 1.25 else {
                return false
            }
            let current = pan.location(in: probeView)
            let translation = pan.translation(in: probeView)
            let start = CGPoint(x: current.x - translation.x, y: current.y - translation.y)
            return probeView.bounds.insetBy(dx: 0, dy: -8).contains(start)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let probeView else { return }
            switch recognizer.state {
            case .began, .changed:
                let x = recognizer.location(in: probeView).x
                onChanged(x)
            case .ended, .cancelled, .failed:
                onEnded()
            default:
                break
            }
        }
    }
}

/// A scrapbook's spine as made in Edit Cover (change 103): the spine art in the cover color with the spine's items
/// (pencil, stickers, text) on top. Nothing on it when the spine was never decorated.
struct BookSpineView: View {
    static let aspectRatio: CGFloat = 23.68 / 147.84

    let scrapbook: Scrapbook

    var body: some View {
        ZStack {
            BookSpineArt(colorHex: scrapbook.displayedCoverColorHex)
            if let spine = scrapbook.coverPage(.spine) {
                ScrapbookPageView(page: spine, photos: [:], photoAspect: { _ in nil },
                                  aspectRatio: ScrapbookPage.Role.spine.aspectRatio, drawsBackground: false)
                    .allowsHitTesting(false)
            }
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(scrapbook.title)
    }
}
