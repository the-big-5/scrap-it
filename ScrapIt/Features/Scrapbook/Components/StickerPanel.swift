import SwiftUI

/// Sticker sheet panel at the bottom of the editor (change 013, POC; stickers may change with the design).
/// Not a modal sheet, so stickers can be dragged straight onto the page. Collapsing only slides it down
/// (its content stays), otherwise a sticker being dragged would vanish and iOS would cancel the gesture.
struct StickerPanel: View {
    private static let maxSheetHeight: CGFloat = 300
    private static let collapsedVisibleHeight: CGFloat = 22

    let set: StickerSet
    let sheet: StickerSheet
    let controller: StickerDragController
    @Binding var isCollapsed: Bool
    let onClose: () -> Void
    let onNewSheet: () -> Void

    @State private var panelHeight: CGFloat = 0

    var body: some View {
        let remaining = sheet.remainingCount(in: set)
        let collapsed = isCollapsed || controller.isOverPage

        VStack(spacing: 10) {
            Capsule()
                .fill(.secondary)
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            HStack {
                Text(set.name)
                    .font(.headline)
                Text("\(remaining) of \(set.stickers.count) left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close sticker sheet")
            }
            .padding(.horizontal, 4)

            sheetView

            if remaining == 0 {
                Button("Take a New Sheet", action: onNewSheet)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
        .onFrameChange(in: .named(StickerDragController.coordinateSpace)) { frame in
            panelHeight = frame.height
            if !(isCollapsed || controller.isOverPage) { controller.panelTop = frame.minY }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isCollapsed { isCollapsed = false }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 40 { isCollapsed = true }
                    if value.translation.height < -40 { isCollapsed = false }
                }
        )
        .offset(y: collapsed ? max(panelHeight - Self.collapsedVisibleHeight, 0) : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: collapsed)
    }

    private var sheetView: some View {
        let height = Self.maxSheetHeight
        let width = height * set.sheetSize.width / set.sheetSize.height
        let scale = width / set.sheetSize.width

        return ZStack(alignment: .topLeading) {
            Image(set.sheetAssetName)
                .resizable()
                .frame(width: width, height: height)

            ForEach(set.stickers) { sticker in
                if !sheet.isUsed(sticker) {
                    StickerOnSheet(set: set, sticker: sticker, scale: scale, controller: controller)
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
        .onFrameChange(in: .named(StickerDragController.coordinateSpace)) { frame in
            if !(isCollapsed || controller.isOverPage) { controller.sheetFrame = frame }
        }
    }
}

/// A sticker still on the sheet. The touch area is separate from the image: the image hides while
/// dragging, and a hidden view would lose its gesture.
private struct StickerOnSheet: View {
    let set: StickerSet
    let sticker: StickerDefinition
    let scale: CGFloat
    let controller: StickerDragController

    @GestureState private var isDragging = false

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: sticker.frame.width * scale, height: sticker.frame.height * scale)
            .overlay {
                Image(sticker.assetName)
                    .resizable()
                    .opacity(controller.activeStickerID == sticker.id ? 0 : 1)
                    .allowsHitTesting(false)
            }
            .position(x: sticker.frame.midX * scale, y: sticker.frame.midY * scale)
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named(StickerDragController.coordinateSpace))
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in
                        if controller.session == nil {
                            controller.begin(sticker, in: set, at: value.startLocation)
                        }
                        guard controller.activeStickerID == sticker.id else { return }
                        controller.move(to: value.location, velocity: value.velocity)
                    }
                    .onEnded { value in
                        guard controller.activeStickerID == sticker.id else { return }
                        controller.end(at: value.location)
                    }
            )
            .onChange(of: isDragging) { _, dragging in
                if !dragging && controller.activeStickerID == sticker.id {
                    controller.cancel()
                }
            }
    }
}
