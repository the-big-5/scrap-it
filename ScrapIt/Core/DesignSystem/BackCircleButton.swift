import SwiftUI

struct BackCircleButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ScrapTheme.charcoal)
                .frame(width: 44, height: 44)
                .background(
                    ZStack {
                        Circle()
                            .fill(ScrapTheme.charcoal)
                            .offset(y: 3)
                        Circle()
                            .fill(Color.white)
                            .overlay(
                                Circle()
                                    .stroke(ScrapTheme.charcoal, lineWidth: 1.5)
                            )
                    }
                )
        }
        .buttonStyle(.plain)
    }
}
