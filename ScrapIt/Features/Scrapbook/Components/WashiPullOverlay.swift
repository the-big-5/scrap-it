import SwiftUI
import UIKit

/// Washi mode over the page (change 022, Figma 1306:56097, camera POC): put a finger at the start, pull, then
/// lift to tear. The tape comes out straight from the start point and the roll follows the finger.
struct WashiPullOverlay: View {
    let style: WashiStyle
    let pageSize: CGSize
    /// Shown until the pull starts; `nil` after the first time in this scrapbook.
    let hint: String?
    /// Start and end (page coordinates) and the tear seed. `false` when it couldn't be placed.
    let onTear: (CGPoint, CGPoint, Int) -> Bool

    @State private var start: CGPoint?
    @State private var end: CGPoint = .zero
    @State private var seed = Int.random(in: 0..<Int(Int32.max))
    @State private var lastTickLength: CGFloat = 0
    @State private var rollScale: CGFloat = 1
    private let tick = UISelectionFeedbackGenerator()

    private var tapeWidth: CGFloat { pageSize.width * WashiCatalog.tapeWidth }

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .gesture(pull)

            if let start {
                let dx = end.x - start.x, dy = end.y - start.y
                let length = hypot(dx, dy)
                let angle = atan2(dy, dx)
                WashiTapeView(style: style, tearSeed: seed, isTornAtEnd: false)
                    .frame(width: max(length, 1), height: tapeWidth)
                    .rotationEffect(.radians(angle))
                    .position(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                    .allowsHitTesting(false)
                Image(style.rollAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: tapeWidth * 1.15)
                    // The roll spins with the pulled length.
                    .rotationEffect(.radians(angle - .pi / 2 + Double(length / tapeWidth)))
                    .scaleEffect(rollScale)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
                    .position(end)
                    .allowsHitTesting(false)
            } else if let hint {
                ScrapbookHintCapsule(text: hint)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 10)
                    .transition(.opacity)
            }
        }
    }

    private var pull: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if start == nil {
                    start = value.startLocation
                    lastTickLength = 0
                    tick.prepare()
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { rollScale = 1.08 }
                }
                end = value.location
                let length = hypot(end.x - value.startLocation.x, end.y - value.startLocation.y)
                // Like the sound of tape being pulled: a light tick every ±20 pt.
                if abs(length - lastTickLength) >= 20 {
                    lastTickLength = length
                    tick.selectionChanged()
                }
            }
            .onEnded { value in
                guard let start else { return }
                let finish = value.location
                let length = hypot(finish.x - start.x, finish.y - start.y)
                if length >= WashiCatalog.minimumLength * pageSize.width, onTear(start, finish, seed) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    seed = Int.random(in: 0..<Int(Int32.max))
                }
                // The roll bounces back a little.
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { rollScale = 1 }
                self.start = nil
            }
    }
}

/// A tool hint over the top of the page (change 022). Touches go through.
struct ScrapbookHintCapsule: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.regularMaterial))
            .padding(.horizontal, 12)
            .allowsHitTesting(false)
    }
}
