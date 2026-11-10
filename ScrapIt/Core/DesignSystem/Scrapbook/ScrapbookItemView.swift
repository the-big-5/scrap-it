import SwiftUI

/// One item on a page: photo, sticker, letter, text, washi or drawing layer (change 022). With `actions` it can be
/// dragged, pinched and rotated; the new values are only sent when the gesture ends (POC). The ViewModel decides
/// clamping and snapping. A drawing layer covers the whole page and lets touches through.
struct ScrapbookItemView: View {
    @Environment(\.displayScale) private var displayScale

    let item: ScrapbookItem
    let photo: ScrapPhoto?
    let photoAspect: CGFloat?
    let pageSize: CGSize
    let isSelected: Bool
    let shouldPlay: (Bool) -> Bool
    let actions: ScrapbookItemActions?
    /// The drawing layer being drawn is hidden; the live canvas replaces it.
    var isHidden = false
    /// Shrinks and dims the element while hovering over the trash drop zone.
    var isOverTrash = false

    @State private var image: UIImage?
    @State private var movieURL: URL?
    @State private var dragOffset: CGSize = .zero
    @State private var scaleFactor: CGFloat = 1
    @State private var rotationDelta: Angle = .zero
    @State private var isInteracting = false

    private var isEditable: Bool { actions != nil }
    private var isLive: Bool { photo?.livePhotoMovieData != nil }

    private var mask: ItemMaskShape { ItemMaskShape(points: item.maskPolygon) }

    private var normalizedWidth: CGFloat {
        let range = item.widthRange
        return min(max(item.width * scaleFactor, range.lowerBound), range.upperBound)
    }

    private var photoSize: CGSize {
        let width = normalizedWidth * pageSize.width
        return CGSize(width: width, height: width / ScrapbookItemLayout.aspectRatio(of: item, photoAspect: photoAspect))
    }

    private var frameInset: CGFloat { photoSize.width * ScrapbookItemLayout.frameInsetRatio }

    private var pixelSize: Int {
        ScrapbookImageLoader.pixelSize(forLongSide: max(photoSize.width, photoSize.height) * displayScale)
    }

    var body: some View {
        if item.kind == .drawing {
            drawingLayer
        } else {
            interactiveContent
        }
    }

    private var drawingLayer: some View {
        ScrapbookDrawingImage(data: isHidden ? nil : item.drawingData)
            .frame(width: pageSize.width, height: pageSize.height)
            .position(x: pageSize.width / 2, y: pageSize.height / 2)
            .allowsHitTesting(false)
    }

    private var interactiveContent: some View {
        decoratedContent
            // Outside the cut shape is not touchable, so items underneath stay selectable.
            .contentShape(mask)
            .overlay {
                if isEditable && isSelected {
                    if item.kind == .text || item.kind == .washi {
                        Rectangle()
                            .stroke(Color.accentColor, lineWidth: 2)
                            .padding(-4)
                    } else if item.maskPolygon != nil {
                        mask.stroke(Color.accentColor, lineWidth: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 2)
                            .padding(-4)
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isEditable && isSelected {
                    // Centered on the selection's corner (stroke drawn 4 pt outside the item).
                    resizeHandle
                        .offset(x: Self.handleTouchSize / 2 + 4, y: Self.handleTouchSize / 2 + 4)
                }
            }
            .contextMenu { if isEditable { menu } }
            .onTapGesture(count: 2) { actions?.doubleTap(item.id) }
            .onTapGesture { actions?.select(item.id) }
            .gesture(editGesture, including: isEditable ? .all : .none)
            .scaleEffect(isOverTrash ? 0.62 : 1)
            .opacity(isOverTrash ? 0.72 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isOverTrash)
            .rotationEffect(Angle(radians: item.rotation) + rotationDelta)
            .position(x: item.centerX * pageSize.width + dragOffset.width,
                      y: item.centerY * pageSize.height + dragOffset.height)
            .onDisappear { actions?.cancelDrag(item.id) }
            .task(id: "\(item.photoID?.uuidString ?? "-")-\(pixelSize)") {
                guard let photo else { return }
                if let cached = ScrapbookImageLoader.shared.cachedImage(for: photo.id, pixelSize: pixelSize) {
                    image = cached
                } else {
                    image = await ScrapbookImageLoader.shared.image(for: photo.id, data: photo.imageData, pixelSize: pixelSize)
                }
                if let movie = photo.livePhotoMovieData, movieURL == nil {
                    movieURL = LiveMovieFileCache.url(for: photo.id, data: movie)
                }
            }
    }

    /// Photos get a white print frame and a shadow; stickers have their own border in the asset.
    @ViewBuilder
    private var decoratedContent: some View {
        switch item.kind {
        case .sticker:
            if let sticker = item.sticker {
                Image(sticker.assetName)
                    .resizable()
                    .frame(width: photoSize.width, height: photoSize.height)
            }
            // A sticker no longer in the catalog is not shown.
        case .letter:
            if let letter = item.letterID.flatMap(LetterCatalog.letter(withID:)) {
                Image(letter.assetName)
                    .resizable()
                    .frame(width: photoSize.width, height: photoSize.height)
                    .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
            } else {
                missingAsset
            }
        case .washi:
            if let style = item.washiID.flatMap(WashiCatalog.style(withID:)) {
                WashiTapeView(style: style, tearSeed: item.tearSeed ?? 0)
                    .frame(width: photoSize.width, height: photoSize.height)
            } else {
                missingAsset
            }
        case .text:
            Text(item.text ?? "")
                .font(TextItemStyle.font(size: normalizedWidth * pageSize.width))
                .foregroundStyle(TextItemColor.from(item.textColor).color)
                .multilineTextAlignment(.center)
                .frame(maxWidth: pageSize.width * TextItemStyle.maxWidthRatio)
                .fixedSize(horizontal: false, vertical: true)
        case .drawing:
            EmptyView()
        case .photo:
            photoContent
                .frame(width: photoSize.width, height: photoSize.height)
                .clipped()
                .padding(frameInset)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                // Cut pieces: plain cut edges, the frame only on the original edges.
                .clipShape(mask)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
    }

    /// A letter or washi pattern missing from the catalog: a gray box, no crash.
    private var missingAsset: some View {
        Color.gray.opacity(0.4)
            .frame(width: photoSize.width, height: photoSize.height)
    }

    @ViewBuilder
    private var photoContent: some View {
        if photo != nil {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(white: 0.85)
                }
                if let movieURL {
                    LoopingVideoView(url: movieURL, isPlaying: shouldPlay(isInteracting))
                }
            }
        } else {
            ZStack {
                Color(white: 0.85)
                Image(systemName: "photo.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button { actions?.bringToFront(item.id) } label: {
            Label("Bring to Front", systemImage: "square.3.layers.3d.top.filled")
        }
        Button { actions?.sendToBack(item.id) } label: {
            Label("Send to Back", systemImage: "square.3.layers.3d.bottom.filled")
        }
        if isLive {
            Button { actions?.toggleMotion(item.id) } label: {
                if item.loopEnabled {
                    Label("Turn Off Motion", systemImage: "livephoto.slash")
                } else {
                    Label("Turn On Motion", systemImage: "livephoto")
                }
            }
        }
        if item.kind == .text {
            Button { actions?.editText(item.id) } label: {
                Label("Edit Text", systemImage: "character.cursor.ibeam")
            }
        }
        Button(role: .destructive) { actions?.remove(item.id) } label: {
            Label("Remove from Page", systemImage: "trash")
        }
    }

    // MARK: - Gestures

    private var editGesture: some Gesture {
        // Translation in page space, not in the rotated item's space.
        let drag = DragGesture(coordinateSpace: .named(ScrapbookPageView.coordinateSpace))
            .onChanged { value in
                beginInteraction()
                dragOffset = value.translation
                actions?.dragChanged(item.id, value.location)
            }
        let magnify = MagnifyGesture()
            .onChanged { value in
                beginInteraction()
                scaleFactor = value.magnification
            }
        let rotate = RotateGesture()
            .onChanged { value in
                beginInteraction()
                rotationDelta = value.rotation
            }
        return drag.simultaneously(with: magnify).simultaneously(with: rotate)
            .onEnded { _ in commitInteraction() }
    }

    // MARK: - Corner handle (change 022)

    private static let handleTouchSize: CGFloat = 44

    /// One finger on the selected item's corner: away from / toward the center resizes, around it rotates.
    /// Easier than pinching small items such as letters.
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
            .highPriorityGesture(resizeGesture)
            .accessibilityLabel("Resize and rotate")
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(ScrapbookPageView.coordinateSpace))
            .onChanged { value in
                let center = CGPoint(x: item.centerX * pageSize.width, y: item.centerY * pageSize.height)
                let start = CGVector(dx: value.startLocation.x - center.x, dy: value.startLocation.y - center.y)
                let current = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
                let startDistance = hypot(start.dx, start.dy)
                guard startDistance > 1 else { return }
                beginInteraction()
                scaleFactor = hypot(current.dx, current.dy) / startDistance
                rotationDelta = .radians(atan2(current.dy, current.dx) - atan2(start.dy, start.dx))
            }
            .onEnded { _ in commitInteraction() }
    }

    private func beginInteraction() {
        guard !isInteracting else { return }
        isInteracting = true
        actions?.select(item.id)
    }

    private func commitInteraction() {
        let didDelete = actions?.endDrag(item.id) ?? false
        if !didDelete {
            actions?.commitTransform(item.id, dragOffset, scaleFactor, rotationDelta.radians, pageSize)
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            dragOffset = .zero
            scaleFactor = 1
            rotationDelta = .zero
        }
        isInteracting = false
    }
}

/// Scissors cut shape (points normalized 0–1). `nil` = full box.
struct ItemMaskShape: Shape {
    let points: [CGPoint]?

    func path(in rect: CGRect) -> Path {
        guard let points, points.count >= 3 else { return Path(rect) }
        var path = Path()
        path.addLines(points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) })
        path.closeSubpath()
        return path
    }
}
