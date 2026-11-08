import SwiftUI

/// One photo or sticker on a page. With `actions` it can be dragged, pinched and rotated; the new values
/// are only sent when the gesture ends (POC). The ViewModel decides clamping and snapping.
struct ScrapbookItemView: View {
    @Environment(\.displayScale) private var displayScale

    let item: ScrapbookItem
    let photo: ScrapPhoto?
    let photoAspect: CGFloat?
    let pageSize: CGSize
    let isSelected: Bool
    let shouldPlay: (Bool) -> Bool
    let actions: ScrapbookItemActions?

    @State private var image: UIImage?
    @State private var movieURL: URL?
    @State private var dragOffset: CGSize = .zero
    @State private var scaleFactor: CGFloat = 1
    @State private var rotationDelta: Angle = .zero
    @State private var isInteracting = false
    @State private var isStickerRemoveConfirmationPresented = false

    private var isEditable: Bool { actions != nil }
    private var isLive: Bool { photo?.livePhotoMovieData != nil }

    private var mask: ItemMaskShape { ItemMaskShape(points: item.maskPolygon) }

    private var photoSize: CGSize {
        let width = min(max(item.width * scaleFactor, ScrapbookItem.minWidth), ScrapbookItem.maxWidth) * pageSize.width
        return CGSize(width: width, height: width / ScrapbookItemLayout.aspectRatio(of: item, photoAspect: photoAspect))
    }

    private var frameInset: CGFloat { photoSize.width * ScrapbookItemLayout.frameInsetRatio }

    private var pixelSize: Int {
        ScrapbookImageLoader.pixelSize(forLongSide: max(photoSize.width, photoSize.height) * displayScale)
    }

    var body: some View {
        decoratedContent
            // Outside the cut shape is not touchable, so items underneath stay selectable.
            .contentShape(mask)
            .overlay {
                if isEditable && isSelected {
                    if item.maskPolygon != nil {
                        mask.stroke(Color.accentColor, lineWidth: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 2)
                            .padding(-4)
                    }
                }
            }
            .contextMenu { if isEditable { menu } }
            .onTapGesture { actions?.select(item.id) }
            .gesture(editGesture, including: isEditable ? .all : .none)
            .rotationEffect(Angle(radians: item.rotation) + rotationDelta)
            .position(x: item.centerX * pageSize.width + dragOffset.width,
                      y: item.centerY * pageSize.height + dragOffset.height)
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
            .confirmationDialog("Remove this sticker?", isPresented: $isStickerRemoveConfirmationPresented, titleVisibility: .visible) {
                Button("Remove Sticker", role: .destructive) { actions?.remove(item.id) }
            } message: {
                Text("A removed sticker can't be used again.")
            }
    }

    /// Photos get a white print frame and a shadow; stickers have their own border in the asset.
    @ViewBuilder
    private var decoratedContent: some View {
        if let sticker = item.sticker {
            Image(sticker.assetName)
                .resizable()
                .frame(width: photoSize.width, height: photoSize.height)
        } else if item.stickerID == nil {
            photoContent
                .frame(width: photoSize.width, height: photoSize.height)
                .clipped()
                .padding(frameInset)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                // Cut pieces: plain cut edges, the frame only on the original edges.
                .clipShape(mask)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                .overlay(alignment: .topTrailing) {
                    if isEditable, isLive, !item.loopEnabled {
                        Image(systemName: "livephoto.slash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(.black.opacity(0.5)))
                            .padding(frameInset + 3)
                    }
                }
        }
        // A sticker no longer in the catalog is not shown.
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
        if item.stickerID != nil {
            Button(role: .destructive) {
                isStickerRemoveConfirmationPresented = true
            } label: {
                Label("Remove Sticker", systemImage: "trash")
            }
        } else {
            Button(role: .destructive) { actions?.remove(item.id) } label: {
                Label("Remove from Page", systemImage: "trash")
            }
        }
    }

    // MARK: - Gestures

    private var editGesture: some Gesture {
        // Translation in page space, not in the rotated item's space.
        let drag = DragGesture(coordinateSpace: .named(ScrapbookPageView.coordinateSpace))
            .onChanged { value in
                beginInteraction()
                dragOffset = value.translation
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

    private func beginInteraction() {
        guard !isInteracting else { return }
        isInteracting = true
        actions?.select(item.id)
    }

    private func commitInteraction() {
        actions?.commitTransform(item.id, dragOffset, scaleFactor, rotationDelta.radians, pageSize)
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
