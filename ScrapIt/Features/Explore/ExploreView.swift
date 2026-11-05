import SwiftUI

struct ExploreView: View {
    var body: some View {
        ZStack {
            ScrapTheme.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(ScrapTheme.charcoal.opacity(0.4))
                    .padding(.bottom, 4)

                Text("Explore")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(ScrapTheme.charcoal)

                Text("Discover shared rolls and inspiration soon.")
                    .font(.system(size: 14))
                    .foregroundStyle(ScrapTheme.charcoal.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}
