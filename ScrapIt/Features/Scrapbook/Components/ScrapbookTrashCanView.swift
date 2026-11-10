import SwiftUI

/// Floating drag-to-trash target that appears above the bottom tray when dragging an item.
/// Its lid hinges open with a spring when the dragged item hovers inside the drop zone.
struct ScrapbookTrashCanView: View {
    let isOpen: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isOpen ? Color.red : Color(white: 0.14, opacity: 0.88))
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(isOpen ? 0.9 : 0.3), lineWidth: isOpen ? 2 : 1)
                }
                .shadow(color: .black.opacity(isOpen ? 0.38 : 0.25), radius: isOpen ? 12 : 6, y: 4)

            VStack(spacing: 1.5) {
                TrashCanLidShape()
                    .fill(Color.white)
                    .frame(width: 24, height: 6.5)
                    .rotationEffect(.degrees(isOpen ? -34 : 0), anchor: UnitPoint(x: 0.12, y: 1.0))
                    .offset(x: isOpen ? -1 : 0, y: isOpen ? -3.5 : 0)

                TrashCanBinShape()
                    .fill(Color.white, style: FillStyle(eoFill: true))
                    .frame(width: 19, height: 19)
                    .rotationEffect(.degrees(isOpen ? 3 : 0), anchor: .bottom)
            }
        }
        .frame(width: 64, height: 64)
        .scaleEffect(isOpen ? 1.18 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isOpen)
        .allowsHitTesting(false)
        .accessibilityLabel("Delete item")
    }
}

private struct TrashCanLidShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let handleWidth = rect.width * 0.34
        let handleHeight = rect.height * 0.48
        let handleRect = CGRect(
            x: (rect.width - handleWidth) / 2,
            y: 0,
            width: handleWidth,
            height: handleHeight + 1
        )
        path.addRoundedRect(in: handleRect, cornerSize: CGSize(width: 1.5, height: 1.5))

        let barHeight = rect.height * 0.48
        let barRect = CGRect(
            x: 0,
            y: rect.height - barHeight,
            width: rect.width,
            height: barHeight
        )
        path.addRoundedRect(in: barRect, cornerSize: CGSize(width: barHeight / 2, height: barHeight / 2))
        return path
    }
}

private struct TrashCanBinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset: CGFloat = 2
        let topLeft = CGPoint(x: 0, y: 0)
        let topRight = CGPoint(x: rect.width, y: 0)
        let bottomRight = CGPoint(x: rect.width - inset, y: rect.height)
        let bottomLeft = CGPoint(x: inset, y: rect.height)
        let corner: CGFloat = 2.5

        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: CGPoint(x: bottomRight.x + 0.3, y: rect.height - corner))
        path.addQuadCurve(to: CGPoint(x: bottomRight.x - corner, y: rect.height), control: bottomRight)
        path.addLine(to: CGPoint(x: bottomLeft.x + corner, y: rect.height))
        path.addQuadCurve(to: CGPoint(x: bottomLeft.x - 0.3, y: rect.height - corner), control: bottomLeft)
        path.closeSubpath()

        // Three even-odd cutout slats inside the bin body.
        let ribWidth: CGFloat = 1.8
        let ribTop = rect.height * 0.22
        let ribBottom = rect.height * 0.78
        for xCenter in [rect.width * 0.28, rect.width * 0.5, rect.width * 0.72] {
            let rib = CGRect(
                x: xCenter - ribWidth / 2,
                y: ribTop,
                width: ribWidth,
                height: ribBottom - ribTop
            )
            path.addRoundedRect(in: rib, cornerSize: CGSize(width: ribWidth / 2, height: ribWidth / 2))
        }

        return path
    }
}
