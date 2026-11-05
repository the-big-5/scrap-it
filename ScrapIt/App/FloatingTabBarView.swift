import SwiftUI

struct FloatingTabBarView: View {
    @Binding var selectedTab: AppTab
    @Namespace private var animationNamespace

    private let tabs: [(tab: AppTab, icon: String, label: String)] = [
        (.home, "house.fill", "Home"),
        (.explore, "magnifyingglass", "Explore"),
        (.profile, "person.fill", "Profile")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tab) { item in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selectedTab = item.tab
                    }
                } label: {
                    ZStack {
                        if selectedTab == item.tab {
                            Capsule()
                                .fill(Color(red: 0.89, green: 0.86, blue: 0.79))
                                .frame(width: 78, height: 44)
                                .matchedGeometryEffect(id: "selectedTabIndicator", in: animationNamespace)
                        } else {
                            Capsule()
                                .fill(Color.clear)
                                .frame(width: 78, height: 44)
                        }

                        Image(systemName: item.icon)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Color(red: 0.16, green: 0.14, blue: 0.12))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.label)
                .accessibilityAddTraits(selectedTab == item.tab ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 6)
        .frame(width: 274, height: 62)
        .background(
            ZStack {
                // Hard neo-brutalist shadow (Figma 984:3468)
                Capsule()
                    .fill(Color(red: 0.16, green: 0.14, blue: 0.12))
                    .offset(y: 5)

                // White pill body
                Capsule()
                    .fill(Color(red: 0.996, green: 0.996, blue: 0.992))

                // 1.5pt dark stroke
                Capsule()
                    .stroke(Color(red: 0.16, green: 0.14, blue: 0.12), lineWidth: 1.5)
            }
        )
    }
}
