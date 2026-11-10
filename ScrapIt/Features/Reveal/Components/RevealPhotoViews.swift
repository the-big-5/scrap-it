import SwiftUI
import UIKit

/// A roll photo downsampled to its size on screen (shared cache with the scrapbook editor).
struct RevealPhotoImage: View {
    let photo: RevealPhoto
    let longSide: CGFloat

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            DSColor.Kraft.normal.color
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .task(id: photo.id) {
            let pixelSize = ScrapbookImageLoader.pixelSize(forLongSide: longSide * displayScale)
            image = await ScrapbookImageLoader.shared.image(for: photo.id, data: photo.imageData, pixelSize: pixelSize)
        }
    }
}

/// Scattered photo on the mat (Figma 1323:41482): 1.5 pt white border, 2 pt corners, soft shadow.
/// Drag moves it (and brings it to the front); tap opens the detail.
struct RevealScatteredPhoto: View {
    let photo: RevealPhoto
    let onDragStart: () -> Void
    let onDragEnd: (CGSize) -> Void
    let onTap: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        let size = RollRevealViewModel.cardSize(aspectRatio: photo.aspectRatio)
        RevealPhotoImage(photo: photo, longSide: RollRevealViewModel.photoLongSide)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.white, lineWidth: 1.5))
            .shadow(color: Color(red: 20 / 255, green: 36 / 255, blue: 20 / 255).opacity(0.38), radius: 8, y: 3)
            .scaleEffect(isDragging ? 1.05 : 1)
            .offset(dragOffset)
            .onTapGesture(perform: onTap)
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onDragStart()
                        }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        onDragEnd(value.translation)
                        dragOffset = .zero
                        isDragging = false
                    }
            )
            .animation(.easeOut(duration: 0.12), value: isDragging)
            .accessibilityElement()
            .accessibilityLabel("Photo")
            .accessibilityAddTraits(.isButton)
    }
}

/// Tidy Up grid cell (Figma 793:3506): 175 × 233, 18 pt corners, capture time badge.
struct RevealGridPhoto: View {
    let photo: RevealPhoto
    let time: String

    var body: some View {
        Color.clear
            .aspectRatio(175.0 / 233.0, contentMode: .fit)
            .overlay {
                RevealPhotoImage(photo: photo, longSide: 233)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topLeading) {
                Text(time)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(DSColor.Brand.primary.color.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .padding(10)
            }
            .shadow(color: Color(red: 41 / 255, green: 31 / 255, blue: 20 / 255).opacity(0.12), radius: 8, y: 3)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityElement()
            .accessibilityLabel("Photo, \(time)")
            .accessibilityAddTraits(.isButton)
    }
}

/// Photo detail (Figma 1444:23620): dimmed mat, large photo with a white border, Save and Share.
/// A Live Photo plays (press and hold, as on the scrapbook grid). Tap outside the photo closes it.
struct RevealPhotoDetail: View {
    let photo: RevealPhoto
    let isSaving: Bool
    let onSave: () -> Void
    let onClose: () -> Void

    @State private var shareImage: UIImage?

    private static let buttonRowHeight: CGFloat = 58

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityLabel("Close photo")
                .accessibilityAddTraits(.isButton)

            GeometryReader { proxy in
                let size = fittedSize(in: CGSize(
                    width: proxy.size.width - 40,
                    height: proxy.size.height - Self.buttonRowHeight - 16 - 120
                ))
                VStack(spacing: 16) {
                    LivePhotoPlayerView(
                        imageData: photo.imageData,
                        movieData: photo.movieData,
                        contentMode: .scaleAspectFill
                    )
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white, lineWidth: 5.2))
                    .shadow(color: Color(red: 20 / 255, green: 36 / 255, blue: 20 / 255).opacity(0.38), radius: 28, y: 10)

                    HStack(spacing: 12) {
                        Button("Save", action: onSave)
                            .buttonStyle(OffsetPillButtonStyle())
                            .disabled(isSaving)

                        if let shareImage {
                            ShareLink(
                                item: Image(uiImage: shareImage),
                                preview: SharePreview("Photo", image: Image(uiImage: shareImage))
                            ) {
                                CircleIconLabel(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Share")
                        }
                    }
                    .frame(width: size.width, height: Self.buttonRowHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: photo.id) {
            shareImage = UIImage(data: photo.imageData)
        }
    }

    /// The photo as large as fits, keeping its aspect ratio.
    private func fittedSize(in available: CGSize) -> CGSize {
        let ratio = max(photo.aspectRatio, 0.1)
        let width = min(available.width, available.height * ratio)
        return CGSize(width: width, height: width / ratio)
    }
}
