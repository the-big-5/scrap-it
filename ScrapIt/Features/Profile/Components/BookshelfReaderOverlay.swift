import SwiftData
import SwiftUI
import UIKit

/// Responsive cover & open-spread sizing for `BookshelfReaderOverlay` across iPhone and iPad viewports (change 128).
enum BookshelfReaderLayout {
    static func closedCoverSize(
        for viewport: CGSize,
        isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    ) -> CGSize {
        guard viewport.width > 0, viewport.height > 0 else {
            return CGSize(width: 340, height: 468)
        }
        let maxW = isPad ? viewport.width * 0.60 : min(340, viewport.width * 0.84)
        let verticalMargin: CGFloat = isPad ? 220 : 200
        let maxH = max(220, viewport.height - verticalMargin) * (isPad ? 0.80 : 0.78)
        let scale = min(maxW / 340, maxH / 468)
        return CGSize(width: 340 * scale, height: 468 * scale)
    }

    static func spreadScale(
        for viewport: CGSize,
        isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    ) -> CGFloat {
        guard viewport.width > 0, viewport.height > 0 else { return 1 }
        let baseWidth: CGFloat = 357.6
        let baseHeight = ScrapbookInteractiveSpreadBook.bookHeight(scale: 1)
        let maxW = viewport.width * (isPad ? 0.84 : 0.89)
        let verticalMargin: CGFloat = isPad ? 220 : 210
        let maxH = max(200, viewport.height - verticalMargin) * (isPad ? 0.78 : 0.74)
        return min(maxW / baseWidth, maxH / baseHeight)
    }

    static func bookCenter(in viewport: CGSize) -> CGPoint {
        CGPoint(x: viewport.width / 2, y: viewport.height * 0.52)
    }
}

/// Interactive book-opening & reading overlay over the blurred Profile bookshelf (change 128).
/// Matches Figma `1573:27257` → `1573:28563` and `ScreenRecording_11-13-2026 16-39-07_1.mp4`.
struct BookshelfReaderOverlay: View {
    private enum ReaderStage {
        case pullingOut
        case hinging
        case interactive
    }

    let scrapbook: Scrapbook
    @Bindable var profileViewModel: ProfileViewModel
    let modelContext: ModelContext
    let sessionStore: SessionStore

    @State private var bookViewModel: ScrapbookViewModel
    @State private var stage: ReaderStage = .pullingOut
    @State private var backdropProgress: CGFloat = 0
    @State private var chromeOpacity: Double = 0
    @State private var pullProgress: CGFloat = 0
    @State private var hingeProgress: CGFloat = 0
    @State private var isClosing = false
    @State private var turn: CGFloat = 0
    @State private var isShowingCollaborators = false
    @State private var isShowingDeleteConfirmation = false
    @State private var animationTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        scrapbook: Scrapbook,
        profileViewModel: ProfileViewModel,
        modelContext: ModelContext,
        sessionStore: SessionStore
    ) {
        self.scrapbook = scrapbook
        self.profileViewModel = profileViewModel
        self.modelContext = modelContext
        self.sessionStore = sessionStore
        _bookViewModel = State(initialValue: ScrapbookViewModel(
            modelContext: modelContext,
            navigator: nil,
            sessionStore: sessionStore,
            scrapbookID: scrapbook.id,
            currentUser: profileViewModel.currentUser,
            roomService: CloudKitRollRoomService()
        ))
    }

    var body: some View {
        ZStack {
            if bookViewModel.mode == .edit {
                ScrapbookEditorView(viewModel: bookViewModel)
                    .transition(.opacity)
            } else {
                readerStage
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: bookViewModel.mode)
        .onAppear {
            startOpenAnimation()
        }
        .onChange(of: bookViewModel.mode) { _, mode in
            guard mode != .edit, !isClosing else { return }
            Task { @MainActor in
                await Task.yield()
                bookViewModel.isVisible = (stage == .interactive && !isClosing)
            }
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
            bookViewModel.isVisible = false
        }
        .confirmationDialog(
            "Delete this scrapbook?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Scrapbook", role: .destructive) {
                profileViewModel.requestDelete(scrapbook)
                profileViewModel.confirmDelete()
            }
        } message: {
            Text("Its photos on this phone are deleted too.")
        }
    }

    private var readerStage: some View {
        GeometryReader { geometry in
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let rootGlobal = geometry.frame(in: .global)
            let localSource = profileViewModel.openedBookSourceFrame.map {
                $0.offsetBy(dx: -rootGlobal.minX, dy: -rootGlobal.minY)
            } ?? CGRect(
                x: geometry.size.width / 2 - 12,
                y: geometry.size.height - 200,
                width: 24,
                height: 150
            )
            let targetCenter = BookshelfReaderLayout.bookCenter(in: geometry.size)
            let closedSize = BookshelfReaderLayout.closedCoverSize(for: geometry.size, isPad: isPad)
            let spreadScale = BookshelfReaderLayout.spreadScale(for: geometry.size, isPad: isPad)
            let openSpreadSize = CGSize(
                width: ScrapbookInteractiveSpreadBook.spreadWidth(scale: spreadScale),
                height: ScrapbookInteractiveSpreadBook.bookHeight(scale: spreadScale)
            )
            let currentSpread = bookViewModel.spreads.indices.contains(bookViewModel.spreadIndex)
                ? bookViewModel.spreads[bookViewModel.spreadIndex]
                : (bookViewModel.spreads.first ?? [])

            ZStack(alignment: .topTrailing) {
                // Subtle translucent veil matching Figma 1766:65777 (#F7F2EB) over Profile's 5.5pt blur.
                Color(red: 247 / 255, green: 242 / 255, blue: 235 / 255)
                    .opacity(0.04 * Double(backdropProgress))
                    .ignoresSafeArea()

                // Book animation / interactive reading stage.
                ZStack {
                    switch stage {
                    case .pullingOut:
                        BookPullOutView(
                            progress: pullProgress,
                            sourceRect: localSource,
                            targetCenter: targetCenter,
                            closedSize: closedSize,
                            spine: { BookSpineView(scrapbook: scrapbook) },
                            cover: { ScrapbookFrontCoverContent(viewModel: bookViewModel) }
                        )
                        .allowsHitTesting(false)

                    case .hinging:
                        BookCoverHingeView(
                            openProgress: hingeProgress,
                            closedSize: closedSize,
                            openSpreadSize: openSpreadSize,
                            coverHorizontalPadding: 7.4 * spreadScale,
                            coverVerticalPadding: 4.75 * spreadScale,
                            coverCornerRadius: 4.7 * spreadScale,
                            coverColorHex: bookViewModel.coverColorHex,
                            frontCover: {
                                ScrapbookFrontCoverContent(viewModel: bookViewModel)
                            },
                            leftPage: {
                                ScrapbookBookPageFace(viewModel: bookViewModel, page: currentSpread.first, allowsPlayback: false)
                            },
                            rightPage: {
                                ScrapbookBookPageFace(viewModel: bookViewModel, page: currentSpread.last, allowsPlayback: false)
                            }
                        )
                        .position(targetCenter)
                        .allowsHitTesting(false)

                    case .interactive:
                        ScrapbookInteractiveSpreadBook(
                            viewModel: bookViewModel,
                            scale: spreadScale,
                            turn: $turn,
                            showsAddPagePrompt: false,
                            allowsPlayback: bookViewModel.mode != .edit,
                            onTapSpread: {
                                isShowingCollaborators = false
                                bookViewModel.openSpread()
                            }
                        )
                        .position(targetCenter)
                        .opacity(reduceMotion ? Double(backdropProgress) : 1)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)

                // Floating Apple native Liquid Glass toolbar over the blurred shelf.
                topBar
                    .opacity(chromeOpacity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var topBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: dismissBook) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DSColor.Brand.primary.color)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Close book")

                Spacer(minLength: 8)

                VStack(spacing: 2) {
                    Text(bookViewModel.title.isEmpty ? scrapbook.title : bookViewModel.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DSColor.Brand.primary.color)
                        .lineLimit(1)
                    Text("Private")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DSColor.Brand.primary.color.opacity(0.6))
                }
                .frame(maxWidth: 220)

                Spacer(minLength: 8)

                Button {
                    isShowingCollaborators.toggle()
                } label: {
                    Image("ScrapbookPeople")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Collaborators")
                .popover(isPresented: $isShowingCollaborators, arrowEdge: .top) {
                    collaboratorsPopoverContent
                        .presentationCompactAdaptation(.popover)
                }

                Menu {
                    // Disabled placeholders until video export and public sharing are built (change 128).
                    Button(action: {}) {
                        Label("Save as Video", systemImage: "square.and.arrow.down")
                    }
                    .disabled(true)

                    Button(action: {}) {
                        Label("Make Public", systemImage: "globe")
                    }
                    .disabled(true)

                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Label("Delete Scrapbook", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DSColor.Brand.primary.color)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("More options")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Choreography

    private func withoutAnimation(_ update: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, update)
    }

    private func startOpenAnimation() {
        animationTask?.cancel()
        isClosing = false

        if reduceMotion {
            withoutAnimation {
                pullProgress = 1
                hingeProgress = 1
                stage = .interactive
                bookViewModel.isVisible = true
            }
            withAnimation(.easeOut(duration: 0.22)) {
                backdropProgress = 1
                chromeOpacity = 1
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.55)) {
            backdropProgress = 1
            chromeOpacity = 1
        }

        // Phase A: let initial shelf frame commit, then lift & turn spine into centered front cover.
        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(20))
            guard !Task.isCancelled else { return }

            HapticService.shared.playSnapFeedback()
            withAnimation(.easeInOut(duration: 0.55)) {
                backdropProgress = 1
                chromeOpacity = 1
            }
            withAnimation(.spring(response: 0.72, dampingFraction: 0.86)) {
                pullProgress = 1
            }

            try? await Task.sleep(for: .milliseconds(760))
            guard !Task.isCancelled else { return }

            // Phase B: pixel-matched handoff from front cover to 3D cover hinge open.
            withoutAnimation {
                hingeProgress = 0
                stage = .hinging
            }
            try? await Task.sleep(for: .milliseconds(20))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.82)) {
                hingeProgress = 1
            }

            try? await Task.sleep(for: .milliseconds(830))
            guard !Task.isCancelled else { return }

            HapticService.shared.playSnapFeedback()
            withoutAnimation {
                stage = .interactive
                bookViewModel.isVisible = true
            }
        }
    }

    private func dismissBook() {
        guard !isClosing else { return }
        isClosing = true
        isShowingCollaborators = false
        bookViewModel.isVisible = false
        animationTask?.cancel()

        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) {
                backdropProgress = 0
                chromeOpacity = 0
                profileViewModel.isReaderBackdropBlurred = false
            }
            animationTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
                profileViewModel.finishClosingShelfReader()
            }
            return
        }

        withoutAnimation {
            turn = 0
            if stage == .interactive {
                hingeProgress = 1
                stage = .hinging
            }
        }

        animationTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }

            if stage == .hinging {
                withAnimation(.easeInOut(duration: 0.52)) {
                    hingeProgress = 0
                }
                try? await Task.sleep(for: .milliseconds(520))
                guard !Task.isCancelled else { return }

                withoutAnimation {
                    pullProgress = 1
                    stage = .pullingOut
                }
                await Task.yield()
                guard !Task.isCancelled else { return }
            }

            withAnimation(.spring(response: 0.62, dampingFraction: 0.88)) {
                pullProgress = 0
                backdropProgress = 0
                chromeOpacity = 0
                profileViewModel.isReaderBackdropBlurred = false
            }

            try? await Task.sleep(for: .milliseconds(630))
            guard !Task.isCancelled else { return }
            profileViewModel.finishClosingShelfReader()
        }
    }

    private var collaboratorsPopoverContent: some View {
        VStack(spacing: 0) {
            ForEach(Array(bookViewModel.memberRows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider()
                        .padding(.leading, 56)
                }
                HStack(spacing: 12) {
                    collaboratorAvatar(for: row)
                    (Text(row.name).font(.system(size: 16, weight: .medium))
                        + Text(row.isMe ? " (You)" : "")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
            }
        }
        .padding(.vertical, 6)
        .frame(minWidth: 250)
    }

    @ViewBuilder
    private func collaboratorAvatar(for row: EditingProgressRow) -> some View {
        if let data = row.avatarData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color(coverHex: row.colorHex))
                .frame(width: 34, height: 34)
                .overlay {
                    Text(String(row.name.prefix(1)).uppercased())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
        }
    }
}
