import SwiftUI

/// Warm gradient header with stationery stickers shared by the room screens (Figma 1011:5883, 725:6659).
struct RollRoomHeader: View {
    var body: some View {
        Image("ShareRoomHeaderDecoration")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 206)
            .clipped()
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .top)
    }
}

/// Six 49×58 code boxes (Figma Invite friend 1068:4233 / Join Roll 725:6659).
struct RollCodeBox<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(.system(size: 30, weight: .regular, design: .monospaced))
            .foregroundStyle(Color.black)
            .frame(width: 49, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black, lineWidth: 1)
                    )
            )
    }
}
