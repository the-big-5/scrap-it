import SwiftUI

/// Reusable film canister + perforated horizontal film strip card for "Resume Roll" (Figma 1537:26016).
struct RollStripCard: View {
    let title: String
    let joinedCount: Int
    let slotsUsed: Int
    let rollSize: Int
    let formattedDate: String
    let canisterAsset: String
    let isHost: Bool
    let onTap: () -> Void
    let onLeave: () -> Void
    let onDelete: () -> Void

    private static let canisterSize = CGSize(width: 89, height: 142)
    private static let stripBodyHeight: CGFloat = 80
    private static let sprocketRailHeight: CGFloat = 6

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .leading) {
                filmStrip
                    .padding(.leading, 95)

                Image(canisterAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.canisterSize.width, height: Self.canisterSize.height)
                    .padding(.leading, 30)
            }
            .frame(maxWidth: .infinity, minHeight: Self.canisterSize.height, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onLeave) {
                Label("Leave Roll", systemImage: "rectangle.portrait.and.arrow.right")
            }

            if isHost {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Roll", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(joinedCount) joined, \(slotsUsed) of \(rollSize) shots, \(formattedDate)")
        .accessibilityHint("Tap to resume roll. Long press for options.")
    }

    private var filmStrip: some View {
        VStack(spacing: 0) {
            sprocketRail

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DSColor.Kraft.light.color)
                    .lineLimit(1)

                HStack(spacing: 14) {
                    Label("\(joinedCount) joined", systemImage: "person.2")
                    Label("\(slotsUsed)/\(rollSize) shots", systemImage: "camera")
                }
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(DSColor.Kraft.normal.color)
                .lineLimit(1)

                Text(formattedDate)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(DSColor.Kraft.normal.color)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 35)
            .padding(.trailing, 20)
            .frame(height: Self.stripBodyHeight)
            .background(DSColor.Brand.primary.color)

            sprocketRail
        }
    }

    private var sprocketRail: some View {
        Canvas { context, size in
            let railWidth = size.width
            // Outer and inner black borders matching Figma 1537:26034..26118.
            context.fill(Path(CGRect(x: 0, y: 0, width: railWidth, height: 2)), with: .color(.black))
            context.fill(Path(CGRect(x: 0, y: 4, width: railWidth, height: 2)), with: .color(.black))
            var x: CGFloat = 0
            while x < railWidth {
                context.fill(Path(CGRect(x: x, y: 0, width: 2, height: Self.sprocketRailHeight)), with: .color(.black))
                x += 5
            }
        }
        .frame(height: Self.sprocketRailHeight)
        .frame(maxWidth: .infinity)
    }
}
