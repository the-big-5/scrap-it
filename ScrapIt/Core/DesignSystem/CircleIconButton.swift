import SwiftUI

/// Round 44pt toolbar icon label with a hard offset shadow for SF Symbols (e.g. `Menu` label).
struct CircleIconLabel: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
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
                        .overlay(Circle().stroke(ScrapTheme.charcoal, lineWidth: 1.5))
                }
            )
    }
}
