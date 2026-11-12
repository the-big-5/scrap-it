import SwiftUI

/// Two phones with the star characters (change 081, Figma 1599:49022), on Invite Friends and Join Roll. Three
/// layers placed as in Figma (376 × 219), scaled to the width it gets.
struct InviteFriendsIllustration: View {
    private static let size = CGSize(width: 376, height: 219)

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / Self.size.width
            ZStack(alignment: .topLeading) {
                layer("InvitePhones", x: 0, y: 0, width: 376, height: 188, scale: scale)
                layer("StarCharacterSquint", x: 256, y: 57, width: 76, height: 162, scale: scale)
                layer("StarCharacterHappy", x: 61, y: 27, width: 97, height: 123, scale: scale)
            }
        }
        .aspectRatio(Self.size.width / Self.size.height, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func layer(_ name: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                       scale: CGFloat) -> some View {
        Image(name)
            .resizable()
            .frame(width: width * scale, height: height * scale)
            .offset(x: x * scale, y: y * scale)
    }
}
