import SwiftUI
import UIKit

/// Circular profile avatar matching Figma nodes 1300:36498 / 1300:36783 (120pt diameter).
struct ProfileAvatarView: View {
    let avatarData: Data?
    var size: CGFloat = 120

    private static let placeholderColor = Color(red: 0.769, green: 0.769, blue: 0.769)

    var body: some View {
        Group {
            if let avatarData, let image = UIImage(data: avatarData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Self.placeholderColor
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
