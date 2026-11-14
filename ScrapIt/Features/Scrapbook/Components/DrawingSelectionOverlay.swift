import SwiftUI

/// The selected pencil drawing (change 150), over its page: its strokes and the selection box of the other items.
/// Drag moves it, the corner handle resizes / rotates with one finger, two fingers pinch / rotate; long press
/// offers "Remove from Page". Only the box and the handle take touches. The values are sent when the gesture ends.
struct DrawingSelectionOverlay: View {
    let selection: DrawingSelection
    /// The page as shown (points).
    let pageSize: CGSize
    let isOverTrash: Bool
    /// Finger location in page points while dragging (for the trashcan).
    let onDragChanged: (CGPoint) -> Void
    /// Translation (page points), scale, rotation (radians).
    let onCommit: (CGSize, CGFloat, Double) -> Void
    let onCancel: () -> Void
    let onRemove: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var scaleFactor: CGFloat = 1
    @State private var rotationDelta: Angle = .zero

    private static let space = "drawingSelection"
    private static let handleTouchSize: CGFloat = 44

    /// The drawing's box in page points, at rest.
    private var box: CGRect {
        let points = pageSize.height / ScrapbookPage.canvasSize.height
        let bounds = selection.bounds
        return CGRect(x: bounds.minX * points, y: bounds.minY * points,
                      width: bounds.width * points, height: bounds.height * points)
    }

    var body: some View {
        let box = box
        let anchor = UnitPoint(x: box.midX / max(pageSize.width, 1), y: box.midY / max(pageSize.height, 1))
        ZStack(alignment: .topLeading) {
            Color.clear

            // The selected strokes, following the gesture live.
            ScrapbookDrawingImage(data: selection.selectedData)
                .frame(width: pageSize.width, height: pageSize.height)
                .scaleEffect(scaleFactor * (isOverTrash ? 0.62 : 1), anchor: anchor)
                .rotationEffect(rotationDelta, anchor: anchor)
                .offset(dragOffset)
                .opacity(isOverTrash ? 0.72 : 1)
                .allowsHitTesting(false)

            Rectangle()
                .stroke(Color.accentColor, lineWidth: 2)
                .frame(width: box.width * scaleFactor + 8, height: box.height * scaleFactor + 8)
                .contentShape(Rectangle())
                .overlay(alignment: .bottomTrailing) {
                    resizeHandle
                        .offset(x: Self.handleTouchSize / 2, y: Self.handleTouchSize / 2)
                }
                .contextMenu {
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove from Page", systemImage: "trash")
                    }
                }
                .gesture(editGesture)
                .rotationEffect(rotationDelta)
                .position(x: box.midX + dragOffset.width, y: box.midY + dragOffset.height)
                .opacity(isOverTrash ? 0 : 1)
                .accessibilityLabel("Drawing")
                .accessibilityAction(named: "Remove from Page", onRemove)
        }
        .frame(width: pageSize.width, height: pageSize.height)
        .coordinateSpace(name: Self.space)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isOverTrash)
        .onDisappear(perform: onCancel)
    }

    private var editGesture: some Gesture {
        let drag = DragGesture(coordinateSpace: .named(Self.space))
            .onChanged { value in
                dragOffset = value.translation
                onDragChanged(value.location)
            }
        let magnify = MagnifyGesture().onChanged { scaleFactor = $0.magnification }
        let rotate = RotateGesture().onChanged { rotationDelta = $0.rotation }
        return drag.simultaneously(with: magnify).simultaneously(with: rotate)
            .onEnded { _ in commit() }
    }

    /// One finger on the corner: away from / toward the center resizes, around it rotates (as for items).
    private var resizeHandle: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
            .overlay {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 24, height: 24)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .frame(width: Self.handleTouchSize, height: Self.handleTouchSize)
            .contentShape(Circle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        let center = CGPoint(x: box.midX, y: box.midY)
                        let start = CGVector(dx: value.startLocation.x - center.x, dy: value.startLocation.y - center.y)
                        let current = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
                        let startDistance = hypot(start.dx, start.dy)
                        guard startDistance > 1 else { return }
                        scaleFactor = hypot(current.dx, current.dy) / startDistance
                        rotationDelta = .radians(atan2(current.dy, current.dx) - atan2(start.dy, start.dx))
                    }
                    .onEnded { _ in commit() }
            )
            .accessibilityLabel("Resize and rotate")
    }

    private func commit() {
        onCommit(dragOffset, scaleFactor, rotationDelta.radians)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            dragOffset = .zero
            scaleFactor = 1
            rotationDelta = .zero
        }
    }
}
