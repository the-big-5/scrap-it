import SwiftUI

/// The sticker sheet opened large in the middle of the page from the Stickers tray (change 022, Figma 1306:54411,
/// camera POC). Stickers are peeled off this sheet and stuck on the page outside it.
///
/// A sticker's touch area is separate from its image, because the image is hidden while dragged and a hidden
/// view can't be touched (iOS would cancel its gesture; brief K10).
struct StickerSheetOverlay: View {
    let set: StickerSet
    let sheet: StickerSheet
    let controller: StickerDragController
    let pageSize: CGSize
    let onClose: () -> Void
    let onNewSheet: () -> Void

    var body: some View {
        let remaining = sheet.remainingCount(in: set)
        ZStack {
            // Dims the page; a tap outside the sheet puts the sheet back in the tray.
            Color.black.opacity(0.08)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard controller.session == nil else { return }
                    onClose()
                }

            VStack(spacing: 12) {
                sheetView
                if remaining == 0 {
                    Button("Take a New Sheet", action: onNewSheet)
                        .buttonStyle(.borderedProminent)
                        .tint(TrayStyle.leather)
                }
            }
            // Fades while a sticker is carried off, so the page underneath shows.
            .opacity(controller.isOverPage ? 0.4 : 1)
            .animation(.easeInOut(duration: 0.2), value: controller.isOverPage)
        }
    }

    /// 83% of the page width, not tilted (the sticker positions on the sheet use a straight box).
    private var sheetView: some View {
        let width = min(pageSize.width * 0.83, pageSize.height * 0.8 * set.sheetSize.width / set.sheetSize.height)
        let height = width * set.sheetSize.height / set.sheetSize.width
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
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
        .onFrameChange(in: .named(StickerDragController.coordinateSpace)) { frame in
            controller.sheetFrame = frame
        }
    }
}

/// One sticker still on the sheet.
private struct StickerOnSheet: View {
    let set: StickerSet
    let sticker: StickerDefinition
    let scale: CGFloat
    let controller: StickerDragController

    /// Goes back to `false` also when the system cancels the gesture (no `onEnded`).
    @GestureState private var isDragging = false

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: sticker.frame.width * scale, height: sticker.frame.height * scale)
            .overlay {
                Image(sticker.assetName)
                    .resizable()
                    // Hidden while dragged; the glue mark on the sheet shows.
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
            .accessibilityLabel(sticker.name)
    }
}
