import SwiftUI

/// Drag math for the floating tab bar: finger x (in the bar) → selection pill position and tab index.
struct TabBarDragMath: Equatable {
    let barWidth: CGFloat
    let horizontalPadding: CGFloat
    let tabCount: Int

    var tabWidth: CGFloat {
        (barWidth - horizontalPadding * 2) / CGFloat(tabCount)
    }

    func center(ofTab index: Int) -> CGFloat {
        horizontalPadding + tabWidth * (CGFloat(index) + 0.5)
    }

    /// Tab under the finger, clamped to the first / last tab.
    func tabIndex(atX x: CGFloat) -> Int {
        let raw = Int(((x - horizontalPadding) / tabWidth).rounded(.down))
        return min(max(raw, 0), tabCount - 1)
    }

    /// Pill center while dragging: follows the finger, never past the first / last tab.
    func pillCenter(forFingerX x: CGFloat) -> CGFloat {
        min(max(x, center(ofTab: 0)), center(ofTab: tabCount - 1))
    }
}

struct FloatingTabBarView: View {
    @Binding var selectedTab: AppTab
    /// Pill center while the finger drags along the bar; `nil` when not dragging.
    @State private var dragPillX: CGFloat?

    private let tabs: [(tab: AppTab, icon: String, label: String)] = [
        (.home, "house.fill", "Home"),
        (.explore, "magnifyingglass", "Explore"),
        (.profile, "person.fill", "Profile")
    ]

    private let barWidth: CGFloat = 274
    private let barHeight: CGFloat = 62
    private let padding: CGFloat = 6
    private let pillSize = CGSize(width: 78, height: 44)
    private let ink = Color(red: 0.16, green: 0.14, blue: 0.12)

    private var math: TabBarDragMath {
        TabBarDragMath(barWidth: barWidth, horizontalPadding: padding, tabCount: tabs.count)
    }

    private var selectedIndex: Int {
        tabs.firstIndex { $0.tab == selectedTab } ?? 0
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Selection pill: on the selected tab, or under the finger while dragging.
            Capsule()
                .fill(Color(red: 0.89, green: 0.86, blue: 0.79))
                .frame(width: pillSize.width, height: pillSize.height)
                .position(x: dragPillX ?? math.center(ofTab: selectedIndex), y: barHeight / 2)

            HStack(spacing: 0) {
                ForEach(tabs, id: \.tab) { item in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            selectedTab = item.tab
                        }
                    } label: {
                        Image(systemName: item.icon)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(ink)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.label)
                    .accessibilityAddTraits(selectedTab == item.tab ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, padding)
        }
        .frame(width: barWidth, height: barHeight)
        .background(
            ZStack {
                // Hard neo-brutalist shadow (Figma 984:3468)
                Capsule()
                    .fill(ink)
                    .offset(y: 5)

                // White pill body
                Capsule()
                    .fill(Color(red: 0.996, green: 0.996, blue: 0.992))

                // 1.5pt dark stroke
                Capsule()
                    .stroke(ink, lineWidth: 1.5)
            }
        )
        // Drag along the bar like the native tab bar: the pill follows the finger,
        // the tab under it is selected, and it snaps into place on release.
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    dragPillX = math.pillCenter(forFingerX: value.location.x)
                    let tab = tabs[math.tabIndex(atX: value.location.x)].tab
                    if tab != selectedTab {
                        selectedTab = tab
                    }
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selectedTab = tabs[math.tabIndex(atX: value.location.x)].tab
                        dragPillX = nil
                    }
                }
        )
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}
