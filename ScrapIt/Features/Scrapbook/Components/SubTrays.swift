import SwiftUI

/// A second tray that scrolls sideways (change 022, camera POC). With `drag`, items can be dragged up onto the page.
struct SubTrayScroll<Content: View>: View {
    var drag: TrayDragController?
    @ViewBuilder let content: () -> Content

    var body: some View {
        TrayScroll(contentBottom: TrayStyle.subTrayContentBottom) {
            content()
        } probe: {
            if let drag {
                ScrollPanProbe(
                    direction: .up,
                    canBegin: { drag.begin(at: $0) },
                    onChanged: { location, _ in drag.move(to: location) },
                    onEnded: { _, _, cancelled in drag.end(cancelled: cancelled) }
                )
            }
        }
    }
}

// MARK: - Photos

/// This roll's photos as small polaroids, newest on the left (Figma 1306:49859). Tap adds to the page;
/// drag up to drop.
struct PhotoTray: View {
    static let thumbnailPixelSize = 400

    /// Newest first.
    let photos: [ScrapPhoto]
    let aspectRatio: (ScrapPhoto) -> CGFloat
    let controller: TrayDragController
    let onAdd: (UUID) -> Void

    var body: some View {
        if photos.isEmpty {
            SubTrayScroll {
                Text("Photos from this roll appear here.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
        } else {
            SubTrayScroll(drag: controller) {
                ForEach(photos, id: \.id) { photo in
                    let payload = TrayDragController.Payload.photo(id: photo.id, aspectRatio: aspectRatio(photo))
                    TrayDraggable(payload: payload, controller: controller, onTap: { onAdd(photo.id) }) {
                        PolaroidThumb(photo: photo, aspectRatio: aspectRatio(photo))
                    }
                }
            }
        }
    }
}

private struct PolaroidThumb: View {
    /// Long side of the photo inside the polaroid; the short side follows the photo's own ratio.
    static let longSide: CGFloat = 52

    let photo: ScrapPhoto
    /// Width / height of the photo.
    let aspectRatio: CGFloat
    @State private var image: UIImage?

    private var size: CGSize {
        aspectRatio >= 1
            ? CGSize(width: Self.longSide, height: Self.longSide / aspectRatio)
            : CGSize(width: Self.longSide * aspectRatio, height: Self.longSide)
    }

    /// Random tilt, the same every time for the same photo (±6°).
    private var angle: Double {
        let sum = photo.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(sum % 13) - 6
    }

    var body: some View {
        Color(white: 0.85)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .padding(.horizontal, 4)
            .padding(.top, 4)
            .padding(.bottom, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(alignment: .topLeading) {
                if photo.livePhotoMovieData != nil {
                    Image(systemName: "livephoto")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 1)
                        .padding(6)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            .rotationEffect(.degrees(angle))
            // Only the polaroids on screen are loaded.
            .task(id: photo.id) {
                image = await ScrapbookImageLoader.shared.image(for: photo.id, data: photo.imageData,
                                                                pixelSize: PhotoTray.thumbnailPixelSize)
            }
    }
}

// MARK: - Letters

/// Cut-out letters A–Z and 0–9 (Figma 1306:49157).
struct LetterTray: View {
    let controller: TrayDragController
    let onAdd: (LetterDefinition) -> Void

    var body: some View {
        SubTrayScroll(drag: controller) {
            ForEach(LetterCatalog.letters) { letter in
                TrayDraggable(payload: .letter(letter), controller: controller, onTap: { onAdd(letter) }) {
                    Image(letter.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 62)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                }
                .accessibilityLabel("Letter \(letter.character)")
            }
        }
    }
}

/// A tray item that can be tapped or dragged onto the page. The drag is handled by `ScrollPanProbe` in
/// `SubTrayScroll`; this item only reports its frame so the dragged item can be found.
private struct TrayDraggable<Content: View>: View {
    let payload: TrayDragController.Payload
    let controller: TrayDragController
    let onTap: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .opacity(controller.payload == payload ? 0.35 : 1)
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap()
            }
            .onFrameChange(in: .global) { frame in
                controller.itemFrames[payload] = frame
            }
            .onDisappear {
                controller.itemFrames[payload] = nil
            }
    }
}

// MARK: - Washi

/// 4 washi rolls (Figma 1306:49648). The picked roll is raised while washi mode is on.
struct WashiTray: View {
    let selectedID: String?
    let onSelect: (WashiStyle) -> Void

    var body: some View {
        SubTrayScroll {
            ForEach(WashiCatalog.styles) { style in
                let isSelected = selectedID == style.id
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(style)
                } label: {
                    Image(style.rollAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 64)
                        .scaleEffect(isSelected ? 1.1 : 1)
                        .offset(y: isSelected ? -6 : 0)
                        .shadow(color: .black.opacity(isSelected ? 0.4 : 0.2), radius: isSelected ? 5 : 2, y: 2)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Washi tape")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: selectedID)
    }
}

// MARK: - Stickers

/// The two sticker sheets, Travel and Fun (Figma 1306:50103).
struct StickerTray: View {
    let sheets: [(set: StickerSet, sheet: StickerSheet?)]
    /// The set whose sheet is open on the page.
    let openSetID: String?
    let onToggle: (StickerSet) -> Void

    var body: some View {
        SubTrayScroll {
            ForEach(Array(sheets.enumerated()), id: \.element.set.id) { index, entry in
                let isOpen = openSetID == entry.set.id
                Button { onToggle(entry.set) } label: {
                    StickerSheetThumbnail(set: entry.set, sheet: entry.sheet, height: 74)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -4 : 3))
                        .scaleEffect(isOpen ? 1.08 : 1)
                        .offset(y: isOpen ? -6 : 0)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(entry.set.name) sticker sheet")
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: openSetID)
    }
}

/// A small sticker sheet: the empty sheet plus the stickers not used yet.
struct StickerSheetThumbnail: View {
    let set: StickerSet
    let sheet: StickerSheet?
    let height: CGFloat

    var body: some View {
        let scale = height / set.sheetSize.height
        ZStack(alignment: .topLeading) {
            Image(set.sheetAssetName)
                .resizable()
            ForEach(set.stickers) { sticker in
                if sheet?.isUsed(sticker) != true {
                    Image(sticker.assetName)
                        .resizable()
                        .frame(width: sticker.frame.width * scale, height: sticker.frame.height * scale)
                        .position(x: sticker.frame.midX * scale, y: sticker.frame.midY * scale)
                }
            }
        }
        .frame(width: set.sheetSize.width * scale, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
