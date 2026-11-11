import SwiftUI

/// The scrapbook as an open book on the desk (change 025, Figma 1444:23742 / 1518:30319). Drag the book to turn a
/// page like a real book (a new spread past the last one), tap it to zoom into the spread. Back asks first; Done has
/// no action yet.
struct ScrapbookBookView: View {
    let viewModel: ScrapbookViewModel
    /// Shared with the edit view so the spread zooms from the book into the editor.
    let namespace: Namespace.ID
    /// Page turn progress: 0 = still, -1 = right page turned over to the left (next spread), 1 = left page turned
    /// over to the right (previous spread).
    @State private var turn: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Figma frame width.
    private static let designWidth: CGFloat = 402
    static let spreadMatchID = "spread"

    var body: some View {
        ZStack {
            desk
            VStack(spacing: 0) {
                HStack {
                    // Reading a finished book: back to the closed book (change 026).
                    BackCircleButton {
                        if viewModel.isBookEditable {
                            viewModel.requestBack()
                        } else {
                            viewModel.closeReadOnlyBook()
                        }
                    }
                        .accessibilityLabel("Back")
                    Spacer()
                }
                .padding(.horizontal, 22)
                Spacer()
                if viewModel.isBookEditable {
                    Button("Done", action: viewModel.finishScrapbook)
                        .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
                        .padding(.horizontal, 22)
                        .padding(.bottom, 24)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.showsPageHint)
    }

    private var desk: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / Self.designWidth
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack {
                Image("DeskWood")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .accessibilityHidden(true)

                BookCuttingMat()
                    .frame(width: 927 * scale, height: 697 * scale)
                    .position(x: (-263 + 927 / 2) * scale, y: center.y)
                    .accessibilityHidden(true)

                book(scale: scale)
                    .position(x: center.x, y: center.y + 3 * scale)

                if viewModel.showsPageHint && viewModel.isBookEditable {
                    PageHintTooltip(onClose: viewModel.dismissPageHint)
                        .frame(width: 306 * scale)
                        .position(x: center.x, y: center.y + (bookHeight(scale: scale) / 2) + 84 * scale)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Book

    private func pageWidth(scale: CGFloat) -> CGFloat { 357.6 * scale / 2 - 7.4 * scale }
    private func bookHeight(scale: CGFloat) -> CGFloat { pageWidth(scale: scale) * 4 / 3 + 9.5 * scale }

    private func spreadPages(at index: Int) -> [ScrapbookPage] {
        let spreads = viewModel.spreads
        return spreads.indices.contains(index) ? spreads[index] : []
    }

    private func book(scale: CGFloat) -> some View {
        let pageWidth = pageWidth(scale: scale)
        let pageSize = CGSize(width: pageWidth, height: pageWidth * 4 / 3)
        let current = spreadPages(at: viewModel.spreadIndex)
        let next = spreadPages(at: viewModel.spreadIndex + 1)
        let previous = spreadPages(at: viewModel.spreadIndex - 1)
        // Under the turning leaf: the page that's revealed on the side it leaves.
        let baseLeft = turn > 0 ? previous.first : current.first
        let baseRight = turn < 0 ? next.last : current.last
        return ZStack {
            HStack(spacing: 0) {
                pageFace(baseLeft)
                pageFace(baseRight)
            }
            .matchedGeometryEffect(id: Self.spreadMatchID, in: namespace)
            .frame(width: pageSize.width * 2, height: pageSize.height)

            if turn < 0 {
                // Turning forward: the right page swings over the spine to the left; its back is the next left page.
                leaf(front: current.last, back: next.first, size: pageSize,
                     angle: Double(turn) * 180, anchor: .leading)
                    .offset(x: pageWidth / 2)
            } else if turn > 0 {
                // Turning back: the left page swings over to the right; its back is the previous right page.
                leaf(front: current.first, back: previous.last, size: pageSize,
                     angle: Double(turn) * 180, anchor: .trailing)
                    .offset(x: -pageWidth / 2)
            }
        }
        .padding(.horizontal, 7.4 * scale)
        .padding(.vertical, 4.75 * scale)
        // Cover: plain navy for now; the cover design isn't ready [Open].
        .background(
            RoundedRectangle(cornerRadius: 4.7 * scale)
                .fill(LinearGradient(colors: [Color(red: 0.17, green: 0.22, blue: 0.47), Color(red: 0.12, green: 0.15, blue: 0.34)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color(red: 41 / 255, green: 26 / 255, blue: 10 / 255).opacity(0.35), radius: 2, y: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard turn == 0, viewModel.isBookEditable else { return }
            viewModel.openSpread()
        }
        .gesture(turnGesture(pageWidth: pageWidth))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pages \(viewModel.spreadIndex * 2 + 1) and \(viewModel.spreadIndex * 2 + 2)")
        .accessibilityHint("Tap to decorate. Swipe for other pages.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { viewModel.openSpread() }
        .accessibilityAdjustableAction { direction in
            viewModel.swipeSpread(by: direction == .increment ? 1 : -1)
        }
    }

    /// One page of the book, read only (touches go to the book). A missing page (past the last spread) is blank paper.
    @ViewBuilder
    private func pageFace(_ page: ScrapbookPage?) -> some View {
        Group {
            if let page {
                ScrapbookPageView(page: page, photos: viewModel.photosByID, photoAspect: viewModel.photoAspect(for:))
            } else {
                PageBackgroundView(background: viewModel.pages.last?.pageBackground ?? .cream)
            }
        }
        .scrapbookPageEdgeShadow()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    /// The page being turned: it rotates around the spine; past halfway its back (the page behind) shows. It darkens
    /// as it stands up, like a real leaf catching less light.
    private func leaf(front: ScrapbookPage?, back: ScrapbookPage?, size: CGSize,
                      angle: Double, anchor: UnitPoint) -> some View {
        let showsBack = abs(angle) > 90
        let shade = sin(abs(angle) * .pi / 180) * 0.35
        return ZStack {
            if showsBack {
                pageFace(back)
                    .scaleEffect(x: -1, y: 1)
            } else {
                pageFace(front)
            }
            Color.black.opacity(shade).allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height)
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), anchor: anchor, perspective: 0.45)
        .shadow(color: .black.opacity(shade * 0.8), radius: 8, x: anchor == .leading ? -4 : 4)
    }

    /// The page follows the finger; let go past a third (or with a flick) and it falls over, otherwise it settles back.
    private func turnGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                viewModel.dismissPageHint()
                var progress = value.translation.width / (pageWidth * 2)
                // No previous spread: the left page doesn't lift.
                if viewModel.spreadIndex == 0 { progress = min(progress, 0) }
                turn = max(-1, min(1, progress))
            }
            .onEnded { value in
                let flick = value.predictedEndTranslation.width / (pageWidth * 2)
                let goesForward = turn < 0 && (turn < -0.33 || flick < -0.6)
                let goesBack = turn > 0 && (turn > 0.33 || flick > 0.6)
                guard goesForward || goesBack else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { turn = 0 }
                    return
                }
                withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.32)) {
                    turn = goesForward ? -1 : 1
                } completion: {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        viewModel.swipeSpread(by: goesForward ? 1 : -1)
                        turn = 0
                    }
                }
            }
    }
}

/// The green cutting mat under the book, drawn from the Figma layers (grid, rulers, numbers) in its
/// 927 × 697 design space.
private struct BookCuttingMat: View {
    private static let size = CGSize(width: 927.126, height: 697)
    private static let line = Color(red: 254 / 255, green: 254 / 255, blue: 253 / 255)

    var body: some View {
        Canvas { context, size in
            let sx = size.width / Self.size.width
            let sy = size.height / Self.size.height
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
                Path(CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy))
            }
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(red: 45 / 255, green: 119 / 255, blue: 87 / 255), location: 0),
                    .init(color: Color(red: 45 / 255, green: 119 / 255, blue: 88 / 255), location: 0.58),
                    .init(color: Color(red: 32 / 255, green: 110 / 255, blue: 80 / 255), location: 1),
                ]),
                center: CGPoint(x: size.width * 0.494, y: size.height * 0.495),
                startRadius: 0, endRadius: max(size.width, size.height) * 0.6
            ))
            // Grid.
            for x in stride(from: 29.8, through: 831.2, by: 72.8456) {
                context.fill(rect(x, 49.67, 1.656, 604.29), with: .color(Self.line.opacity(0.45)))
            }
            for y in stride(from: 112.58, through: 622.6, by: 72.8456) {
                context.fill(rect(29.8, y, 867.52, 1.656), with: .color(Self.line.opacity(0.45)))
            }
            context.fill(rect(29.8, 39.73, 2.483, 617.53), with: .color(Self.line.opacity(0.72)))
            // Rulers: ticks every 18.2 (long every 4th) and the numbers 1–9.
            let rulerX: CGFloat = 130.79
            for index in 0...33 {
                let x = rulerX + 44.7 + CGFloat(index) * 18.2114
                let isLong = index.isMultiple(of: 4)
                context.fill(rect(x, 1.65, 1.656, isLong ? 14.9 : 8.278), with: .color(Self.line.opacity(0.72)))
                context.fill(rect(x, isLong ? 688.72 : 692.03, 1.656, isLong ? 8.278 : 4.967), with: .color(Self.line.opacity(0.72)))
            }
            for number in 1...9 {
                let x = rulerX + 38.08 + CGFloat(number - 1) * 72.8456 + 6
                for y: CGFloat in [16.56 + 15, 658.92 + 15] {
                    context.draw(
                        Text("\(number)").font(.system(size: 24.8 * sy)).foregroundColor(Self.line.opacity(0.9)),
                        at: CGPoint(x: x * sx, y: y * sy)
                    )
                }
            }
        }
        .overlay {
            Rectangle().stroke(.black.opacity(0.2), lineWidth: 6).blur(radius: 10).clipped()
        }
    }
}

/// "More pages to fill!" under the book (Figma 1518:30522), with a pointer to the book.
private struct PageHintTooltip: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(DSColor.Kraft.lightActive.color)
                .frame(width: 24, height: 17)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 10) {
                    Text("More pages to fill!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DSColor.Brand.primary.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, -10)
                    .padding(.trailing, -10)
                    .accessibilityLabel("Close")
                }
                Text("You can swipe to another page and decorate it too.")
                    .font(.system(size: 14))
                    .foregroundStyle(DSColor.Brand.primary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background(DSColor.Kraft.lightActive.color, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
