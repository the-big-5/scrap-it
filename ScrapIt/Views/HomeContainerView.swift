import SwiftData
import SwiftUI

struct HomeContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Scrapbook.createdDate, order: .reverse) private var scrapbooks: [Scrapbook]

    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    var body: some View {
        NavigationStack(path: $flowViewModel.navigationPath) {
            ZStack(alignment: .bottom) {
                ScrapTheme.creamBackground
                    .ignoresSafeArea()

                Group {
                    switch flowViewModel.selectedTab {
                    case .home:
                        HomeShelvesScene(
                            scrapbooks: scrapbooks,
                            onTapCamera: {
                                flowViewModel.openCameraRollMenu()
                            },
                            onTapScrapbook: { book in
                                flowViewModel.activeScrapbook = book
                                flowViewModel.navigationPath.append(.scrapbookGrid(book.id))
                            }
                        )
                    case .profile:
                        ProfileStubView(currentUser: currentUser, scrapbooksCount: scrapbooks.count)
                    }
                }

                FloatingHomeProfileTabBar(selectedTab: $flowViewModel.selectedTab)
                    .padding(.bottom, 16)
            }
            .navigationDestination(for: RollRoute.self) { route in
                switch route {
                case .cameraRollMenu:
                    CameraRollMenuView(flowViewModel: flowViewModel)
                case .createStep1NameAndShots:
                    CreateRollStep1View(flowViewModel: flowViewModel)
                case .createStep2ChooseFilter:
                    CreateRollStep2FilterView(
                        currentUser: currentUser,
                        flowViewModel: flowViewModel
                    )
                case .createStep3ShareRoom:
                    CreateRollStep3ShareRoomView(
                        currentUser: currentUser,
                        flowViewModel: flowViewModel
                    )
                case .joinRoll:
                    JoinRollView(
                        currentUser: currentUser,
                        flowViewModel: flowViewModel
                    )
                case .captureSession:
                    CaptureSessionView(
                        currentUser: currentUser,
                        flowViewModel: flowViewModel
                    )
                case .scrapbookGrid(let scrapbookID):
                    ScrapbookGridView(
                        scrapbookID: scrapbookID,
                        currentUser: currentUser,
                        flowViewModel: flowViewModel
                    )
                }
            }
        }
        .onOpenURL { url in
            flowViewModel.handleIncomingURL(
                url,
                currentUser: currentUser,
                modelContext: modelContext
            )
        }
    }
}

// MARK: - Illustrated Shelves Scene (Figma node 613:1577)

struct HomeShelvesScene: View {
    var scrapbooks: [Scrapbook]
    var onTapCamera: () -> Void
    var onTapScrapbook: (Scrapbook) -> Void

    var body: some View {
        ZStack {
            // Warm lamp light cone
            LampLightConeShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.99, green: 0.91, blue: 0.68).opacity(0.50),
                            Color(red: 0.99, green: 0.93, blue: 0.76).opacity(0.22),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 380, height: 600)
                .offset(y: -10)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Hanging Pendant Lamp (Figma node 663:4866)
                HangingLampIllustration()
                    .padding(.bottom, 28)

                // Top Shelf: Camera (interactive), Potted Plant, Stickers Toolbox
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 10) {
                        Button(action: onTapCamera) {
                            Image("ShelfCamera")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 83, height: 57)
                                .accessibilityLabel("Camera Roll")
                        }
                        .buttonStyle(.plain)

                        PottedPlantIllustration()

                        StickerCaddyIllustration()
                    }
                    .padding(.horizontal, 26)

                    WoodenShelfPlank()
                        .offset(y: -4)
                }
                .padding(.bottom, 48)

                // Bottom Shelf: Cat Figurine, Standing Books ("memories"), Film Canisters
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 0) {
                        CatFigurineIllustration()
                            .padding(.trailing, 2)

                        ShelfBooksCluster(
                            scrapbooks: scrapbooks,
                            onTapMemories: {
                                if let latest = scrapbooks.first {
                                    onTapScrapbook(latest)
                                }
                            }
                        )

                        Spacer(minLength: 16)

                        ShelfFilmCanistersCluster()
                    }
                    .padding(.horizontal, 42)

                    WoodenShelfPlank()
                        .offset(y: -4)
                }

                Spacer()
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

struct LampLightConeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topWidth: CGFloat = 92
        path.move(to: CGPoint(x: rect.midX - topWidth / 2, y: 120))
        path.addLine(to: CGPoint(x: rect.midX + topWidth / 2, y: 120))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct HangingLampIllustration: View {
    var body: some View {
        Image("HangingLamp")
            .resizable()
            .scaledToFit()
            .frame(width: 124, height: 225)
            .offset(y: -12)
    }
}

struct WoodenShelfPlank: View {
    var body: some View {
        Image("ShelfPlank")
            .resizable()
            .scaledToFit()
            .frame(width: 308, height: 22)
            .shadow(color: .black.opacity(0.22), radius: 8, y: 5)
    }
}

struct PottedPlantIllustration: View {
    var body: some View {
        Image("ShelfPlant")
            .resizable()
            .scaledToFit()
            .frame(width: 107, height: 143)
    }
}

struct StickerCaddyIllustration: View {
    var body: some View {
        Image("ShelfStickerBox")
            .resizable()
            .scaledToFit()
            .frame(width: 118, height: 112)
    }
}

struct CatFigurineIllustration: View {
    var body: some View {
        Image("ShelfCat")
            .resizable()
            .scaledToFit()
            .frame(width: 74, height: 66)
    }
}

struct ShelfBooksCluster: View {
    var scrapbooks: [Scrapbook]
    var onTapMemories: () -> Void

    var body: some View {
        Button(action: onTapMemories) {
            Image("ShelfBooks")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 136)
        }
        .buttonStyle(.plain)
    }
}

struct ShelfFilmCanistersCluster: View {
    var body: some View {
        Image("ShelfCanisters")
            .resizable()
            .scaledToFit()
            .frame(width: 126, height: 49)
    }
}

// MARK: - Bottom Floating Home | Profile Pill Tab Bar

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

struct ProfileStubView: View {
    var currentUser: UserProfile
    var scrapbooksCount: Int

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Circle()
                .fill(ScrapTheme.charcoal.opacity(0.12))
                .frame(width: 88, height: 88)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(ScrapTheme.charcoal)
                )

            Text(currentUser.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(ScrapTheme.charcoal)

            Text("\(scrapbooksCount) Shared Scrapbook\(scrapbooksCount == 1 ? "" : "s")")
                .font(.system(size: 15))
                .foregroundStyle(ScrapTheme.secondaryText)

            Text("Profile shelf design in progress")
                .font(.system(size: 13))
                .foregroundStyle(ScrapTheme.secondaryText.opacity(0.8))
                .padding(.top, 8)
            Spacer()
        }
    }
}
