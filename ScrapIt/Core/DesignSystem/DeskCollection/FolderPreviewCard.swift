import SwiftUI
import UIKit

/// Folder palette cycling cleanly across Burgundy, Kraft/Tan, and Navy/Slate (Figma 1537:25855).
enum FolderCardTheme: Int, CaseIterable, Equatable {
    case burgundy
    case kraft
    case navy

    var backAsset: String {
        switch self {
        case .burgundy: "FolderBurgundyBack"
        case .kraft: "FolderKraftBack"
        case .navy: "FolderNavyBack"
        }
    }

    var flapAsset: String {
        switch self {
        case .burgundy: "FolderBurgundyFlap"
        case .kraft: "FolderKraftFlap"
        case .navy: "FolderNavyFlap"
        }
    }

    var flapSize: CGSize {
        switch self {
        case .burgundy, .navy: CGSize(width: 181.882, height: 162)
        case .kraft: CGSize(width: 182.824, height: 162)
        }
    }

    var flapOffsetX: CGFloat {
        switch self {
        case .burgundy, .navy: -6.94
        case .kraft: -7.91
        }
    }

    var titleColor: Color {
        switch self {
        case .burgundy, .navy: DSColor.Paper.light.color
        case .kraft: DSColor.Brand.primary.color
        }
    }

    var subtitleColor: Color {
        switch self {
        case .burgundy, .navy: DSColor.Paper.normalHover.color
        case .kraft: Color(red: 79 / 255, green: 65 / 255, blue: 33 / 255) // #4F4121
        }
    }
}

/// Decoupled preview payload for a peeking photo inside a `FolderPreviewCard`.
struct FolderPreviewPhoto: Identifiable, Equatable {
    let id: UUID
    let data: Data
}

/// Tactile folder card showing 0...4 photo previews peeking out above the flap (Figma 1537:25855).
struct FolderPreviewCard: View {
    let title: String
    let subtitle: String
    let theme: FolderCardTheme
    let previewPhotos: [FolderPreviewPhoto]
    let onTap: () -> Void
    let onRemoveFromDevice: () -> Void

    private static let cardSize = CGSize(width: 170, height: 150)

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                Image(theme.backAsset)
                    .resizable()
                    .frame(width: Self.cardSize.width, height: Self.cardSize.height)

                photoPreviews

                Image(theme.flapAsset)
                    .resizable()
                    .frame(width: theme.flapSize.width, height: theme.flapSize.height)
                    .offset(x: theme.flapOffsetX)
                    .shadow(color: Color(red: 0.16, green: 0.12, blue: 0.08).opacity(0.14), radius: 3, x: 0, y: -3)
                    .shadow(color: Color(red: 0.16, green: 0.12, blue: 0.08).opacity(0.12), radius: 5, x: 0, y: 5)

                Image("FolderEdgeHighlight")
                    .resizable()
                    .frame(width: Self.cardSize.width, height: Self.cardSize.height)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.titleColor)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(theme.subtitleColor)
                        .lineLimit(1)
                }
                .frame(width: 134, alignment: .leading)
                .offset(x: 18, y: 86)
            }
            .frame(width: 169, height: Self.cardSize.height, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onRemoveFromDevice) {
                Label("Remove from Device", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityHint("Tap to open scrapbook, or long press for options")
    }

    @ViewBuilder
    private var photoPreviews: some View {
        let count = previewPhotos.count
        if count >= 1 {
            widePreviewStrip(previewPhotos[0])
                .rotationEffect(.degrees(3))
                .position(x: 73.49, y: 62.10)
        }
        if count >= 3 {
            polaroidCard(previewPhotos[2])
                .rotationEffect(.degrees(5))
                .position(x: 73.27, y: 45.81)
        }
        if count >= 4 {
            polaroidCard(previewPhotos[3])
                .rotationEffect(.degrees(-3))
                .position(x: 108.38, y: 36.11)
        }
        if count >= 2 {
            polaroidCard(previewPhotos[1])
                .rotationEffect(.degrees(-9))
                .position(x: 140.95, y: 40.11)
        }
    }

    private func widePreviewStrip(_ photo: FolderPreviewPhoto) -> some View {
        decodedImage(photo.data)
            .frame(width: 120, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: Color(red: 41 / 255, green: 31 / 255, blue: 20 / 255).opacity(0.12), radius: 1, x: 0, y: 1)
    }

    private func polaroidCard(_ photo: FolderPreviewPhoto) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 3)
                .fill(DSColor.Component.surface.color)
                .frame(width: 44, height: 54)
                .shadow(color: DSColor.Brand.primary.color.opacity(0.18), radius: 2, x: 0, y: 2)

            decodedImage(photo.data)
                .frame(width: 38, height: 41)
                .clipShape(RoundedRectangle(cornerRadius: 1))
                .padding(.top, 3)
        }
    }

    @ViewBuilder
    private func decodedImage(_ data: Data) -> some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            DSColor.Kraft.normal.color
        }
    }
}
