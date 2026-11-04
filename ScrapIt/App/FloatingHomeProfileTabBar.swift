import SwiftData
import SwiftUI

struct FloatingHomeProfileTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            Button {
                selectedTab = .home
            } label: {
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            selectedTab == .home
                                ? Color(red: 0.36, green: 0.17, blue: 0.07)
                                : ScrapTheme.charcoal.opacity(0.5)
                        )
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(45))
                        .padding(.bottom, 2)

                    Text("Home")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(
                            selectedTab == .home
                                ? Color(red: 0.36, green: 0.17, blue: 0.07)
                                : ScrapTheme.charcoal
                        )
                }
                .frame(width: 98, height: 54)
                .background(
                    Capsule()
                        .fill(selectedTab == .home ? Color.black.opacity(0.08) : Color.clear)
                )
            }
            .buttonStyle(.plain)

            Button {
                selectedTab = .profile
            } label: {
                VStack(spacing: 4) {
                    Circle()
                        .fill(ScrapTheme.charcoal)
                        .frame(width: 24, height: 24)

                    Text("Profile")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ScrapTheme.charcoal)
                }
                .frame(width: 98, height: 54)
                .background(
                    Capsule()
                        .fill(selectedTab == .profile ? Color.black.opacity(0.08) : Color.clear)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        )
    }
}

// MARK: - Profile Stub View (Task 4: Profile tab can be a stub)
