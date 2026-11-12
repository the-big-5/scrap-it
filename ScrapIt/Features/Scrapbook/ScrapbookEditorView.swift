import SwiftUI

/// Scrapbook (change 013). Opens as a book on the desk; tapping the book zooms into the spread editor
/// (change 025). Tools are in the leather tray (change 022); only the spread turns to landscape.
struct ScrapbookEditorView: View {
    @State private var viewModel: ScrapbookViewModel
    @State private var stickerController = StickerDragController()
    @State private var trayDrag = TrayDragController()
    @State private var pencil = PencilController()
    /// Each page's frame in the screen's coordinate space, to drop a sticker on the page under it (change 025).
    @State private var pageScreenFrames: [UUID: CGRect] = [:]
    /// Landscape: the Dynamic Island (top of the phone) is on the left, where the buttons go (change 113).
    @State private var isIslandOnLeading = true
    /// Two-finger zoom on the pages (change 114).
    @State private var pageZoom = PageZoom()
    /// PencilKit-style iPad floating tray dock edge and minimized corner state (change 107).
    @State private var iPadTrayDock: ScrapbookEditorLayout.TrayDockEdge = .bottom
    @State private var iPadTrayCorner: ScrapbookEditorLayout.TrayCorner = .bottomLeading
    @State private var iPadTrayDragOffset: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The spread zooms from the book into the editor and back (change 025).
    @Namespace private var spreadNamespace
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    init(viewModel: ScrapbookViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            switch viewModel.mode {
            case .book:
                ScrapbookBookView(viewModel: viewModel, namespace: spreadNamespace)
                    .transition(.opacity)
            case .edit:
                editView
                    .transition(.opacity)
            case .cover:
                ScrapbookCoverScreen(viewModel: viewModel)
                    .transition(.opacity)
            case .editCover:
                editCoverView
                    .transition(.opacity)
            }

            if let card = viewModel.finishCard {
                finishCard(card)
                    .zIndex(10)
            }

            if viewModel.isBackConfirmationPresented {
                BookBackConfirmation(
                    onCancel: { viewModel.isBackConfirmationPresented = false },
                    onConfirm: viewModel.confirmBack
                )
                .zIndex(10)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.86),
                   value: viewModel.mode)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isBackConfirmationPresented)
        .animation(.easeInOut(duration: 0.2), value: viewModel.finishCard)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.coverSide)
        // The page zoom starts over on another view or screen (change 114).
        .onChange(of: viewModel.zoom) { pageZoom.reset() }
        .onChange(of: viewModel.mode) { pageZoom.reset() }
        .sheet(isPresented: $viewModel.isEditingProgressPresented) {
            WhosHereSheet(title: "Editing Progress", firstTitle: "Done Editing", secondTitle: "In Progress",
                          showsPageNumbers: false,
                          onThisSpread: viewModel.editingDone.map(Self.row),
                          onOtherPages: viewModel.editingInProgress.map(Self.row),
                          onClose: { viewModel.isEditingProgressPresented = false })
        }
        .task { await viewModel.refreshFinishStatus() }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: Binding(get: { viewModel.viewerPhoto != nil },
                                              set: { if !$0 { viewModel.closePhotoViewer() } })) {
            if let photo = viewModel.viewerPhoto {
                ScrapbookPhotoViewer(photo: photo, onClose: viewModel.closePhotoViewer)
            }
        }
        .sheet(isPresented: $viewModel.isWhosHerePresented) {
            WhosHereSheet(onThisSpread: viewModel.whosHereOnThisSpread,
                          onOtherPages: viewModel.whosHereOnOtherPages,
                          onClose: { viewModel.isWhosHerePresented = false })
        }
        .alert("Couldn't save the change", isPresented: $viewModel.isSaveErrorPresented) {
            Button("OK", role: .cancel) {}
        }
        // Keep iPad in default .all orientation across scrapbook modes (change 107); iPhone turns only on the spread (change 025).
        .onChange(of: viewModel.allowsLandscape, initial: true) { _, allows in
            OrientationLock.set(ScrapbookEditorLayout.orientationMask(allowsLandscape: allows))
        }
        .onAppear {
            viewModel.load()
            viewModel.isVisible = true
            viewModel.connectRealtimeOnAppear()
            stickerController.onPlace = { [viewModel] sticker, center, width, rotation in
                // The sticker goes to the page it's dropped on.
                let frames = viewModel.editablePages.compactMap { page in pageScreenFrames[page.id].map { (page.id, $0) } }
                guard let target = frames.first(where: { $0.1.contains(center) }) ?? frames.first else { return false }
                viewModel.activatePage(target.0)
                return viewModel.placeSticker(sticker, center: center, width: width, rotation: rotation,
                                              pageFrame: target.1)
            }
            trayDrag.onDrop = { [viewModel, reduceMotion] payload, point in
                switch payload {
                case .photo(let id, _): viewModel.dropFromTray(.photo(id), at: point, reduceMotion: reduceMotion)
                case .letter(let letter): viewModel.dropFromTray(.letter(letter), at: point)
                }
            }
            pencil.onDrawingChanged = { [viewModel] changes in viewModel.updateDrawings(changes) }
        }
        .onDisappear {
            viewModel.editorDidDisappear()
            viewModel.isVisible = false
            viewModel.disconnectRealtime()
            OrientationLock.resetToPortrait()
        }
    }

    // MARK: - Cover (change 026)

    private static func row(_ row: EditingProgressRow) -> WhosHereRow {
        WhosHereRow(id: row.id, name: row.name, colorHex: row.colorHex, avatarData: row.avatarData, pageNumber: 0, isMe: row.isMe)
    }

    @ViewBuilder
    private func finishCard(_ card: FinishCard) -> some View {
        switch card {
        case .confirmSave:
            BookStarCard(
                starImage: "BookConfirmStarWink",
                title: "Ready to close the scrapbook?",
                message: "Some participants are still editing. If you finish now, the scrapbook will be locked and no one will be able to make further changes.",
                actions: [
                    .init(title: "Keep Editing", style: .secondary, action: viewModel.dismissFinishCard),
                    .init(title: "Save Scrapbook", style: .primary, action: viewModel.saveScrapbook),
                ],
                stacked: true,
                onDismiss: viewModel.dismissFinishCard
            )
        case .complete:
            BookStarCard(
                title: "Scrapbook Complete!",
                message: "Your memories are all tucked in! Revisit your scrapbook anytime on your Bookshelf.",
                actions: [.init(title: "View Bookshelf", style: .primary, action: viewModel.viewBookshelf)]
            )
        case .niceWork:
            BookStarCard(
                starImage: "BookConfirmStarWink",
                title: "Nice Work!",
                message: "Hang tight while everyone else finishes editing the scrapbook.",
                actions: [.init(title: "Got It", style: .primary, action: viewModel.dismissFinishCard)],
                onDismiss: viewModel.dismissFinishCard
            )
        }
    }

    /// Edit Cover (Figma 1444:23793 front, 1515:27196 spine): the cover side on the mat, the tray already open with
    /// this side's tools, the color picker above the tray, → to the spine and ✓ to finish.
    private var editCoverView: some View {
        GeometryReader { geometry in
            let scale = ScrapbookEditorLayout.coverScale(for: geometry.size)
            ZStack(alignment: .bottomLeading) {
                CoverCuttingMat()

                VStack(spacing: 0) {
                    // Figma 1444:23793 / 1515:27196 (change 121): ‹ back to the front on the spine; Editing
                    // Progress, Undo, Redo and ✓ on both sides.
                    HStack(spacing: 8) {
                        if viewModel.coverSide == .spine {
                            BackCircleButton(action: viewModel.showFront)
                                .accessibilityLabel("Back to the front cover")
                        }
                        Spacer()
                        SpreadEditorButton(icon: .asset("ScrapbookPeople", template: false), width: 46,
                                           accessibilityLabel: "Editing progress") {
                            viewModel.isEditingProgressPresented = true
                        }
                        undoButton
                        redoButton
                        SpreadEditorButton(icon: .system("checkmark"), accessibilityLabel: "Done",
                                           action: viewModel.finishCoverEdit)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    if viewModel.coverSide == .front {
                        // Figma 1444:23788: the way to the spine, labeled.
                        Button(action: viewModel.showSpine) {
                            HStack(spacing: 6) {
                                Text("Edit book spine")
                                Image(systemName: "arrow.forward")
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DSColor.Paper.light.color)
                            .padding(.horizontal, 14)
                            .frame(height: 52)
                            .background(DSColor.Brand.primary.color, in: Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 23)
                        .padding(.top, 39)
                        // Room between the button and the cover (asked while testing).
                        .padding(.bottom, 24)
                    }
                    Spacer(minLength: 0)
                    coverSideCell(scale: scale)
                    // Room for the color picker and full-width tray under the cover.
                    Spacer(minLength: TrayStyle.trayHeight + 74)
                }
                .zIndex(viewModel.draggedItemID != nil ? 2 : 0)

                CoverColorButton(colorHex: viewModel.coverColorHex, onChange: viewModel.setCoverColor,
                                 onOpen: viewModel.coverColorPickerOpened)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 20)
                    .padding(.bottom, TrayStyle.trayHeight + 24)

                ToolTray(
                    isOpen: viewModel.isTrayOpen,
                    activeTool: viewModel.raisedTool,
                    onOpen: viewModel.openTray,
                    onClose: viewModel.closeTray,
                    onSelect: viewModel.selectTrayTool,
                    tools: viewModel.availableTools,
                    isFixed: true,
                    onCloseSubTray: viewModel.closeSubTray,
                    pillWidth: isPad ? ScrapbookEditorLayout.iPadTrayPillWidth(for: geometry.size) : nil
                ) { tool in
                    subTray(for: tool)
                }
                .frame(maxWidth: .infinity, alignment: isPad ? .bottom : .bottomLeading)
                .padding(.bottom, isPad ? 16 : 4)
                .zIndex(1)

                trashCan
                    .padding(.bottom, trashBottomPadding)
                    // Only the trashcan animates when a drag starts / ends: on the whole screen the spring also
                    // animated the item moving to the other page and the book's clip (change 104).
                    .animation(.spring(response: 0.25, dampingFraction: 0.78), value: viewModel.draggedItemID != nil)

                if viewModel.activeTool == .pencil && pencil.showsSizePanel {
                    // Right above the picked tool, like Notes (change 114).
                    SizePanelAboveTool(toolFrame: pencil.toolFrames[pencil.tool]) { pencilSizePanel }
                        .transition(.opacity)
                        .zIndex(1)
                }

                StickerDragLayer(controller: stickerController)
                    .zIndex(4)
                TrayDragLayer(controller: trayDrag)
                    .zIndex(4)

                if viewModel.textEditor != nil {
                    TextEditorOverlay(
                        draft: Binding(get: { viewModel.textEditor?.draft ?? "" }, set: { viewModel.textEditor?.draft = $0 }),
                        color: Binding(get: { viewModel.textEditor?.color ?? .black }, set: { viewModel.textEditor?.color = $0 }),
                        font: TextItemStyle.coverFont(size: 30),
                        onDone: viewModel.commitTextEditor
                    )
                    .transition(.opacity)
                    .zIndex(6)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .coordinateSpace(name: StickerDragController.coordinateSpace)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isStickerSheetOpen)
        .animation(.easeInOut(duration: 0.2), value: viewModel.textEditor != nil)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: pencil.showsSizePanel)
    }

    /// The front cover (340 × 468) or the spine (74 × 462) at Figma size, with its decorations editable.
    @ViewBuilder
    private func coverSideCell(scale: CGFloat) -> some View {
        let role = viewModel.coverSide.role
        if let page = viewModel.coverPage(role) {
            let size = role == .front ? CGSize(width: 340 * scale, height: 468 * scale)
                                      : CGSize(width: 74 * scale, height: 462 * scale)
            ZStack {
                if role == .front {
                    BookCoverArt(colorHex: viewModel.coverColorHex)
                } else {
                    BookSpineArt(colorHex: viewModel.coverColorHex)
                }
                ScrapbookPageView(
                    page: page,
                    photos: viewModel.photosByID,
                    selectedItemID: viewModel.selectedItemID,
                    photoAspect: viewModel.photoAspect(for:),
                    shouldPlay: viewModel.shouldPlay(_:isInteracting:),
                    actions: itemActions(for: page),
                    activeDrawingID: viewModel.drawingLayerIDs[page.id],
                    draggedItemID: viewModel.draggedItemID,
                    isTrashTargeted: viewModel.isTrashTargeted,
                    aspectRatio: role.aspectRatio,
                    drawsBackground: false
                )
                .onFrameChange(in: .global) { frame in
                    viewModel.pageGlobalFrames[page.id] = frame
                    trayDrag.pageFrame = frame
                }
                .onFrameChange(in: .named(StickerDragController.coordinateSpace)) { frame in
                    pageScreenFrames[page.id] = frame
                    stickerController.pageFrame = frame
                }
                .overlay {
                    GeometryReader { geometry in
                        pageOverlay(for: page, size: geometry.size)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .id(page.id)
            .overlay {
                // The sticker sheet opens over the cover area; stickers stick to this side.
                if viewModel.isStickerSheetOpen, let sheet = viewModel.currentStickerSheet {
                    StickerSheetOverlay(
                        set: viewModel.stickerSet,
                        sheet: sheet,
                        controller: stickerController,
                        pageSize: CGSize(width: 340 * scale, height: 468 * scale),
                        onClose: viewModel.closeStickerSheet,
                        onNewSheet: viewModel.takeNewStickerSheet
                    )
                    .frame(width: 340 * scale, height: 468 * scale)
                    .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Edit view

    private var editView: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            ZStack {
                DSColor.Brand.primary.color
                    .ignoresSafeArea()
                    // Interface landscape right = the phone's top on the left.
                    .background(InterfaceOrientationReader { orientation in
                        if orientation == .landscapeRight { isIslandOnLeading = true }
                        if orientation == .landscapeLeft { isIslandOnLeading = false }
                    })

                if isPad {
                    iPadEditLayout(geometry, isLandscape: isLandscape)
                        .onChange(of: isLandscape, initial: true) { _, landscapeNow in
                            if landscapeNow {
                                viewModel.ensureSpreadForLandscape()
                            }
                        }
                } else if isLandscape {
                    landscapeLayout(geometry)
                } else {
                    portraitLayout(geometry)
                }

                StickerDragLayer(controller: stickerController)
                    .zIndex(4)
                TrayDragLayer(controller: trayDrag)
                    .zIndex(4)

                if let message = viewModel.toastMessage {
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.regularMaterial))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 60)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .zIndex(5)
                }

                if viewModel.textEditor != nil {
                    TextEditorOverlay(
                        draft: Binding(get: { viewModel.textEditor?.draft ?? "" }, set: { viewModel.textEditor?.draft = $0 }),
                        color: Binding(get: { viewModel.textEditor?.color ?? .black }, set: { viewModel.textEditor?.color = $0 }),
                        onDone: viewModel.commitTextEditor
                    )
                    .transition(.opacity)
                    .zIndex(6)
                }
            }
        }
        // The text keyboard must not shrink the page (brief K6).
        .ignoresSafeArea(.keyboard)
        .coordinateSpace(name: StickerDragController.coordinateSpace)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isStickerSheetOpen)
        .animation(.easeInOut(duration: 0.2), value: viewModel.textEditor != nil)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: pencil.showsSizePanel)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isCutting)
        .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage)
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: viewModel.zoom)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.isTrashTargeted) { _, isTargeted in isTargeted }
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.trashedItemCount)
        .onChange(of: viewModel.zoom) { updateTrayDropFrame() }
        .onChange(of: viewModel.currentPageID) { updateTrayDropFrame() }
    }

    private func portraitLayout(_ geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let pageWidth = viewModel.zoom == .spread ? width / 2 : width
        return ZStack(alignment: .bottomLeading) {
            VStack(spacing: 0) {
                portraitTopBar
                Spacer(minLength: 0)
                spread(pageWidth: pageWidth, viewportWidth: width,
                       offsetX: viewModel.zoom == .right ? width - 2 * pageWidth : 0)
                    // Zoomed pages spread over the dark area, under the top bar (change 114).
                    .zIndex(-1)
                if viewModel.isLowPowerPaused {
                    Text("Live Photos paused in Low Power Mode")
                        .font(.caption)
                        .foregroundStyle(DSColor.Kraft.normal.color)
                        .padding(.top, 8)
                }
                Spacer(minLength: TrayStyle.trayHeight)
            }
            .zIndex(viewModel.draggedItemID != nil ? 2 : 0)

            ToolTray(
                isOpen: viewModel.isTrayOpen,
                activeTool: viewModel.raisedTool,
                onOpen: viewModel.openTray,
                onClose: viewModel.closeTray,
                onSelect: viewModel.selectTrayTool
            ) { tool in
                subTray(for: tool)
            }
            .padding(.bottom, 4)
            .zIndex(1)

            trashCan
                .padding(.bottom, trashBottomPadding)
                // Only the trashcan animates when a drag starts / ends: on the whole screen the spring also animated
                // the item moving to the other page and the book's clip (change 104).
                .animation(.spring(response: 0.25, dampingFraction: 0.78), value: viewModel.draggedItemID != nil)

            if viewModel.activeTool == .pencil && pencil.showsSizePanel {
                // The size panel opens right above the picked tool, like Notes (change 114).
                SizePanelAboveTool(toolFrame: pencil.toolFrames[pencil.tool]) { pencilSizePanel }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }

    private var portraitTopBar: some View {
        HStack(spacing: 10) {
            closeButton
            SpreadEditorButton(icon: .asset(zoomIconName, template: true), width: 51,
                               accessibilityLabel: zoomAccessibilityLabel, action: viewModel.cycleZoom)
            Spacer()
            whosHereButton
            undoButton
            redoButton
        }
        .padding(.horizontal, 22)
        .padding(.top, 4)
    }

    private var iPadLandscapeTopBar: some View {
        HStack(spacing: 10) {
            closeButton
            Spacer()
            whosHereButton
            undoButton
            redoButton
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    /// iPad spread editor: landscape fills full screen height behind the top bar; portrait keeps framed margins and
    /// the Zoom toggle. Both orientations use a PencilKit-style floating pill tray that centers on its docked edge
    /// (`.bottom`, `.leading`, `.trailing`) and collapses to a bottom corner circle button.
    @ViewBuilder
    private func iPadEditLayout(_ geometry: GeometryProxy, isLandscape: Bool) -> some View {
        let pageWidth = ScrapbookEditorLayout.iPadSpreadPageWidth(
            container: geometry.size,
            safeAreaInsets: geometry.safeAreaInsets,
            isLandscape: isLandscape,
            zoom: viewModel.zoom
        )
        let pillWidth = ScrapbookEditorLayout.iPadTrayPillWidth(for: geometry.size)
        let hasSubTray = viewModel.activeTool?.hasSubTray == true
        let openDepth = ScrapbookEditorLayout.iPadOpenTrayDepth(hasSubTray: hasSubTray)
        let restingCenter = viewModel.isTrayOpen
            ? ScrapbookEditorLayout.iPadOpenTrayCenter(container: geometry.size, dock: iPadTrayDock, hasSubTray: hasSubTray)
            : ScrapbookEditorLayout.iPadClosedTrayCenter(container: geometry.size, corner: iPadTrayCorner)
        let rotation = viewModel.isTrayOpen ? ScrapbookEditorLayout.iPadTrayRotation(for: iPadTrayDock) : .zero

        ZStack(alignment: .bottomLeading) {
            if isLandscape {
                spread(pageWidth: pageWidth, viewportWidth: pageWidth * 2, offsetX: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .vertical)
                    .zIndex(viewModel.draggedItemID != nil ? 2 : 0)

                VStack(spacing: 0) {
                    iPadLandscapeTopBar
                    if viewModel.isLowPowerPaused {
                        Text("Live Photos paused in Low Power Mode")
                            .font(.caption)
                            .foregroundStyle(DSColor.Kraft.normal.color)
                            .padding(.top, 8)
                    }
                    Spacer()
                }
                .zIndex(1)
            } else {
                let viewportWidth = viewModel.zoom == .spread ? pageWidth * 2 : pageWidth
                let offsetX = viewModel.zoom == .right ? -pageWidth : 0
                VStack(spacing: 0) {
                    portraitTopBar
                    Spacer(minLength: 0)
                    spread(pageWidth: pageWidth, viewportWidth: viewportWidth, offsetX: offsetX)
                        .frame(width: geometry.size.width)
                        // Zoomed pages spread over the dark area, under the top bar (change 114).
                        .zIndex(-1)
                    if viewModel.isLowPowerPaused {
                        Text("Live Photos paused in Low Power Mode")
                            .font(.caption)
                            .foregroundStyle(DSColor.Kraft.normal.color)
                            .padding(.top, 8)
                    }
                    Spacer(minLength: iPadTrayDock == .bottom ? TrayStyle.trayHeight : 24)
                }
                .zIndex(viewModel.draggedItemID != nil ? 2 : 0)
            }

            ToolTray(
                isOpen: viewModel.isTrayOpen,
                activeTool: viewModel.raisedTool,
                onOpen: viewModel.openTray,
                onClose: viewModel.closeTray,
                onSelect: viewModel.selectTrayTool,
                pillWidth: pillWidth,
                onTrayDragChanged: { translation in
                    iPadTrayDragOffset = translation
                },
                onTrayDragEnded: { translation, predicted in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        if viewModel.isTrayOpen {
                            let resolved = ScrapbookEditorLayout.resolveIPadTrayDrag(
                                container: geometry.size,
                                currentDock: iPadTrayDock,
                                currentCorner: iPadTrayCorner,
                                hasSubTray: hasSubTray,
                                translation: translation,
                                predictedEndTranslation: predicted
                            )
                            iPadTrayDock = resolved.dock
                            iPadTrayCorner = resolved.corner
                            iPadTrayDragOffset = .zero
                            if !resolved.isOpen {
                                viewModel.closeTray()
                            }
                        } else {
                            let resolved = ScrapbookEditorLayout.resolveIPadClosedTrayDrag(
                                container: geometry.size,
                                currentDock: iPadTrayDock,
                                currentCorner: iPadTrayCorner,
                                translation: translation,
                                predictedEndTranslation: predicted
                            )
                            iPadTrayDock = resolved.dock
                            iPadTrayCorner = resolved.corner
                            iPadTrayDragOffset = .zero
                        }
                    }
                }
            ) { tool in
                subTray(for: tool)
            }
            .frame(
                width: viewModel.isTrayOpen ? pillWidth : TrayStyle.closedSize,
                height: viewModel.isTrayOpen ? openDepth : TrayStyle.closedSize,
                alignment: .bottom
            )
            .rotationEffect(rotation)
            .frame(
                width: viewModel.isTrayOpen ? (iPadTrayDock == .bottom ? pillWidth : openDepth) : TrayStyle.closedSize,
                height: viewModel.isTrayOpen ? (iPadTrayDock == .bottom ? openDepth : pillWidth) : TrayStyle.closedSize
            )
            .position(
                x: restingCenter.x + iPadTrayDragOffset.width,
                y: restingCenter.y + iPadTrayDragOffset.height
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: iPadTrayDock)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: iPadTrayCorner)
            .zIndex(1)

            trashCan
                .padding(.bottom, iPadTrayDock == .bottom ? trashBottomPadding : 24)
                .animation(.spring(response: 0.25, dampingFraction: 0.78), value: viewModel.draggedItemID != nil)

            if viewModel.activeTool == .pencil && pencil.showsSizePanel {
                if iPadTrayDock == .bottom {
                    SizePanelAboveTool(toolFrame: pencil.toolFrames[pencil.tool]) { pencilSizePanel }
                        .transition(.opacity)
                        .zIndex(1)
                } else {
                    pencilSizePanel
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: iPadTrayDock == .leading ? .leading : .trailing
                        )
                        .padding(.horizontal, openDepth + 28)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
        }
    }

    /// Landscape: always the spread (no zoom). Buttons run down the notch side, the tray stands up on the other.
    private func landscapeLayout(_ geometry: GeometryProxy) -> some View {
        let insets = geometry.safeAreaInsets
        // Buttons on the Dynamic Island side, the tray on the other (Figma 1563:31649 / 1563:30868). The safe area
        // can't tell: it is the same on both sides in landscape (change 113).
        let buttonsOnLeading = isIslandOnLeading
        let fullHeight = geometry.size.height + insets.top + insets.bottom
        let pageWidth = fullHeight * 3 / 4
        let trayDepth = TrayStyle.trayHeight * 2 - TrayStyle.overlap + 10
        return ZStack {
            spread(pageWidth: pageWidth, viewportWidth: pageWidth * 2, offsetX: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .vertical)
                .zIndex(viewModel.draggedItemID != nil ? 2 : 0)

            HStack {
                if !buttonsOnLeading { Spacer() }
                VStack(spacing: 12) {
                    undoButton
                    redoButton
                    whosHereButton
                    Spacer()
                    closeButton
                }
                .padding(.vertical, 8)
                if buttonsOnLeading { Spacer() }
            }
            .padding(.horizontal, 8)

            // The leather tray turned on its side, its bottom against the screen edge (Figma 1563:30642 / 1563:30756):
            // the closed button sits at the bottom of the screen on either side, and swiping toward the edge closes it.
            ToolTray(
                isOpen: viewModel.isTrayOpen,
                activeTool: viewModel.raisedTool,
                onOpen: viewModel.openTray,
                onClose: viewModel.closeTray,
                onSelect: viewModel.selectTrayTool,
                closedAlignment: buttonsOnLeading ? .bottomLeading : .bottomTrailing,
                closedButtonRotation: .degrees(buttonsOnLeading ? 90 : -90)
            ) { tool in
                subTray(for: tool)
            }
            .frame(width: fullHeight, height: trayDepth, alignment: buttonsOnLeading ? .bottomLeading : .bottomTrailing)
            .rotationEffect(.degrees(buttonsOnLeading ? -90 : 90))
            .frame(width: trayDepth, height: fullHeight)
            .frame(maxWidth: .infinity, alignment: buttonsOnLeading ? .trailing : .leading)
            .ignoresSafeArea()
            .zIndex(1)

            trashCan
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 8)
                .animation(.spring(response: 0.25, dampingFraction: 0.78), value: viewModel.draggedItemID != nil)

            if viewModel.activeTool == .pencil && pencil.showsSizePanel {
                pencilSizePanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: buttonsOnLeading ? .bottomTrailing : .bottomLeading)
                    .padding(.horizontal, trayDepth + 12)
                    // About 60 pt above the screen's bottom edge, clear of the home indicator (change 113).
                    .padding(.bottom, max(60 - insets.bottom, 12))
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }

    /// The eraser has its own size panel (change 114); the other tools share the size and opacity panel.
    @ViewBuilder
    private var pencilSizePanel: some View {
        if pencil.tool == .eraser {
            EraserSizePanel(controller: pencil)
        } else {
            PenSizePanel(controller: pencil)
        }
    }

    // MARK: - Buttons

    private var closeButton: some View {
        SpreadEditorButton(icon: .system("xmark"), accessibilityLabel: "Close", action: viewModel.closeSpread)
    }

    private var whosHereButton: some View {
        SpreadEditorButton(icon: .asset("ScrapbookPeople", template: false), width: 46,
                           accessibilityLabel: "Who's here") {
            viewModel.isWhosHerePresented = true
        }
    }

    private var undoButton: some View {
        SpreadEditorButton(icon: .system("arrow.uturn.backward"), width: 47, accessibilityLabel: "Undo",
                           action: viewModel.undo)
            .disabled(!viewModel.canUndo)
    }

    private var redoButton: some View {
        SpreadEditorButton(icon: .system("arrow.uturn.forward"), width: 47, accessibilityLabel: "Redo",
                           action: viewModel.redo)
            .disabled(!viewModel.canRedo)
    }

    private var zoomIconName: String {
        switch viewModel.zoom {
        case .spread: "ScrapbookZoomSpread"
        case .left: "ScrapbookZoomLeft"
        case .right: "ScrapbookZoomRight"
        }
    }

    private var zoomAccessibilityLabel: String {
        switch viewModel.zoom {
        case .spread: "Zoom to left page"
        case .left: "Zoom to right page"
        case .right: "Show both pages"
        }
    }

    // MARK: - Spread

    /// Both pages side by side; zoom slides one page into view, filling the width (change 104).
    private func spread(pageWidth: CGFloat, viewportWidth: CGFloat, offsetX: CGFloat) -> some View {
        let pageHeight = pageWidth * 4 / 3
        // Both papers, then the items of both pages in one layer order, both edge shadows, then each page's tool.
        // An item across the gutter stays whole, and selecting or moving it to the other page doesn't reorder the
        // layers (change 104).
        return ZStack {
            HStack(spacing: 0) {
                ForEach(viewModel.currentSpreadPages, id: \.id) { page in
                    PageBackgroundView(background: page.pageBackground)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture { viewModel.tapEmptyPage(page.id) }
                        .simultaneousGesture(TapGesture(count: 2).onEnded { resetPageZoom() })
                        .allowsHitTesting(viewModel.editablePages.contains { $0.id == page.id })
                }
            }
            .gesture(PageZoomPinch(zoom: pageZoom))
            spreadItems
            HStack(spacing: 0) {
                ForEach(viewModel.currentSpreadPages, id: \.id) { _ in
                    Color.clear
                        .scrapbookPageEdgeShadow()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .allowsHitTesting(false)
            HStack(spacing: 0) {
                ForEach(viewModel.currentSpreadPages, id: \.id) { page in
                    pageCell(page)
                }
            }
            // Pencil on the two-page view: one canvas over both pages, so a stroke can cross the gutter (change 104).
            if let pageIDs = spreadDrawingPageIDs {
                GeometryReader { geometry in
                    DrawingCanvasView(pageIDs: pageIDs,
                                      drawingData: pageIDs.map(viewModel.drawingData(onPage:)),
                                      pageSize: CGSize(width: geometry.size.width / 2, height: geometry.size.height),
                                      controller: pencil,
                                      remoteRevision: viewModel.remoteDrawingRevision,
                                      zoom: pageZoom)
                        .id(pageIDs.compactMap { viewModel.drawingLayerIDs[$0] })
                }
            }
        }
        // Pages size to this frame, so the zoom from the book scales them smoothly.
        .matchedGeometryEffect(id: ScrapbookBookView.spreadMatchID, in: spreadNamespace)
        .frame(width: pageWidth * 2, height: pageHeight, alignment: .leading)
        .offset(x: offsetX)
        .frame(width: viewportWidth, height: pageHeight, alignment: .leading)
        // Two-finger zoom (change 114): the pages scale around the screen area's center, cut at its edges.
        .scaleEffect(pageZoom.scale)
        .offset(pageZoom.offset)
        .background(Color.clear.onFrameChange(in: .global) { pageZoom.viewport = $0 })
        .overlay {
            // The sticker sheet opens over the pages on screen; stickers stick to the page they're dropped on.
            if viewModel.isStickerSheetOpen, let sheet = viewModel.currentStickerSheet {
                GeometryReader { geometry in
                    StickerSheetOverlay(
                        set: viewModel.stickerSet,
                        sheet: sheet,
                        controller: stickerController,
                        pageSize: geometry.size,
                        onClose: viewModel.closeStickerSheet,
                        onNewSheet: viewModel.takeNewStickerSheet
                    )
                }
                .transition(.scale(scale: 0.3, anchor: .bottomLeading).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            // On the two-page view the tool hint shows once, centered over both pages.
            if viewModel.zoom == .spread, let tool = viewModel.hintTool {
                hint(for: tool)
                    .frame(width: viewportWidth)
                    .allowsHitTesting(false)
            }
        }
        // Zoomed in, the pages spread over the dark area around them, under the buttons and the tray (change 114).
        .clipShape(Rectangle().inset(by: viewModel.draggedItemID != nil || pageZoom.isZoomed ? -2000 : 0))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    /// Both pages of the two-page view while Pencil has a layer on each; `nil` = one canvas per page.
    private var spreadDrawingPageIDs: [UUID]? {
        let pageIDs = viewModel.currentSpreadPages.map(\.id)
        guard viewModel.zoom == .spread, pageIDs.count == 2,
              pageIDs.allSatisfy({ viewModel.drawingLayerIDs[$0] != nil }) else { return nil }
        return pageIDs
    }

    /// The items of both pages, back to front by layer (change 104). Each item sits in its page's frame and
    /// coordinate space, as on `ScrapbookPageView`; only the pages that take touches can be touched.
    private var spreadItems: some View {
        GeometryReader { geometry in
            let pageSize = CGSize(width: geometry.size.width / 2, height: geometry.size.height)
            ZStack(alignment: .topLeading) {
                ForEach(viewModel.layerOrder(of: viewModel.currentSpreadPages)) { entry in
                    let item = entry.item
                    ScrapbookItemView(
                        item: item,
                        photo: item.photoID.flatMap { viewModel.photosByID[$0] },
                        photoAspect: viewModel.photoAspect(for: item),
                        pageSize: pageSize,
                        isSelected: viewModel.selectedItemID == item.id,
                        shouldPlay: { viewModel.shouldPlay(item, isInteracting: $0) },
                        actions: itemActions(for: entry.page),
                        isHidden: viewModel.drawingLayerIDs.values.contains(item.id),
                        isOverTrash: viewModel.isTrashTargeted && viewModel.draggedItemID == item.id
                    )
                    .frame(width: pageSize.width, height: pageSize.height)
                    .coordinateSpace(name: ScrapbookPageView.coordinateSpace)
                    .offset(x: CGFloat(entry.pageIndex) * pageSize.width)
                    .allowsHitTesting(viewModel.editablePages.contains { $0.id == entry.page.id })
                }
            }
        }
    }

    /// Frames, drops and the active tool of one page; its items are drawn in `spreadItems`.
    private func pageCell(_ page: ScrapbookPage) -> some View {
        let isEditable = viewModel.editablePages.contains { $0.id == page.id }
        return Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onFrameChange(in: .global) { frame in
                viewModel.pageGlobalFrames[page.id] = frame
                updateTrayDropFrame()
            }
            .onFrameChange(in: .named(StickerDragController.coordinateSpace)) { frame in
                pageScreenFrames[page.id] = frame
                updateTrayDropFrame()
            }
            .overlay {
                GeometryReader { geometry in
                    pageOverlay(for: page, size: geometry.size)
                }
            }
            .allowsHitTesting(isEditable)
    }

    /// The tool using touches on a page, if any.
    @ViewBuilder
    private func pageOverlay(for page: ScrapbookPage, size: CGSize) -> some View {
        // The page shows the hint itself only when it's alone (zoomed page, cover); the spread centers it instead.
        let showsHint = page.id == viewModel.currentPageID && !(viewModel.mode == .edit && viewModel.zoom == .spread)
        if viewModel.isCutting {
            ScissorsToolView(
                itemAt: { point, size in
                    viewModel.activatePage(page.id)
                    return viewModel.itemID(at: point, pageSize: size, photosOnly: false)
                },
                isOverPhoto: { viewModel.itemID(at: $0, pageSize: $1, photosOnly: true) != nil },
                itemFrame: viewModel.itemFrame,
                onSelect: viewModel.selectItem,
                onMove: { id, frame in
                    viewModel.setItemFrame(itemID: id, centerX: frame.centerX, centerY: frame.centerY,
                                           width: frame.width, rotation: frame.rotation)
                },
                onFinishMove: { viewModel.finishItemManipulation(itemID: $0) },
                onCut: { path, size in
                    viewModel.activatePage(page.id)
                    return viewModel.cut(along: path, pageSize: size)
                },
                onDragMoved: { id, location in viewModel.updateItemDrag(itemID: id, pageLocation: zoomed(location)) },
                onDropInTrash: { viewModel.endItemDrag(itemID: $0) },
                onCancelDrag: { viewModel.cancelItemDrag() }
            )
            .overlay(alignment: .top) { if showsHint { hint(for: .scissors) } }
            .transition(.opacity)
        } else if viewModel.isDrawing {
            // Pencil draws straight on every page on screen, each into its own layer (both pages of the spread share
            // one canvas, change 104).
            if spreadDrawingPageIDs == nil, let layerID = viewModel.drawingLayerIDs[page.id] {
                DrawingCanvasView(pageIDs: [page.id],
                                  drawingData: [viewModel.drawingData(onPage: page.id)],
                                  pageSize: size,
                                  controller: pencil,
                                  remoteRevision: viewModel.remoteDrawingRevision,
                                  zoom: page.role == nil ? pageZoom : nil)
                    .id(layerID)
                    .overlay(alignment: .top) { if showsHint { hint(for: .pencil) } }
            }
        } else if let style = viewModel.washiStyleID.flatMap(WashiCatalog.style(withID:)) {
            WashiPullOverlay(style: style, pageSize: size,
                             hint: showsHint && viewModel.hintTool == .washi ? ScrapbookTool.washi.hint(isPad: isPad) : nil) { start, end, seed in
                viewModel.activatePage(page.id)
                return viewModel.addWashi(from: start, to: end, seed: seed, pageSize: size)
            }
        }
    }

    /// Photos and letters dragged from the tray land on the pages on screen: both on the spread, one when zoomed.
    private func updateTrayDropFrame() {
        let pages = viewModel.editablePages
        let frames = pages.compactMap { viewModel.pageGlobalFrames[$0.id] }
        trayDrag.pageFrame = frames.dropFirst().reduce(frames.first ?? .zero) { $0.union($1) }
        // A sticker counts as on the page anywhere over the pages on screen.
        let screenFrames = pages.compactMap { pageScreenFrames[$0.id] }
        stickerController.pageFrame = screenFrames.dropFirst().reduce(screenFrames.first ?? .zero) { $0.union($1) }
    }

    @ViewBuilder
    private func hint(for tool: ScrapbookTool) -> some View {
        if viewModel.hintTool == tool, let text = tool.hint(isPad: isPad) {
            ScrapbookHintCapsule(text: text)
                .padding(.top, 10)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var trashCan: some View {
        if viewModel.draggedItemID != nil {
            ScrapbookTrashCanView(isOpen: viewModel.isTrashTargeted)
                .onFrameChange(in: .global) { viewModel.trashDropFrame = $0 }
                .frame(maxWidth: .infinity)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .zIndex(3)
                .onDisappear {
                    if viewModel.draggedItemID == nil {
                        viewModel.trashDropFrame = .zero
                    }
                }
        }
    }

    private var trashBottomPadding: CGFloat {
        guard viewModel.isTrayOpen else { return 24 }
        if viewModel.activeTool?.hasSubTray == true {
            return TrayStyle.trayHeight * 2 - TrayStyle.overlap + 14
        }
        return TrayStyle.trayHeight + 16
    }

    /// A point in a page's own space to its size on screen while the pages are zoomed (change 114).
    private func zoomed(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * pageZoom.scale, y: point.y * pageZoom.scale)
    }

    private func resetPageZoom() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { pageZoom.reset() }
    }

    private func itemActions(for page: ScrapbookPage) -> ScrapbookItemActions {
        ScrapbookItemActions(
            select: viewModel.selectItem,
            commitTransform: { id, translation, scale, rotation, size in
                viewModel.commitTransform(itemID: id, translation: translation, scale: scale,
                                          rotationDelta: rotation, pageSize: size)
            },
            bringToFront: viewModel.bringToFront,
            sendToBack: viewModel.sendToBack,
            toggleMotion: viewModel.toggleMotion,
            remove: viewModel.removeItem,
            deselect: { viewModel.tapEmptyPage(page.id) },
            doubleTap: viewModel.doubleTapItem,
            editText: viewModel.editText,
            dragChanged: { id, location in viewModel.updateItemDrag(itemID: id, pageLocation: zoomed(location)) },
            endDrag: { viewModel.endItemDrag(itemID: $0) },
            cancelDrag: { viewModel.cancelItemDrag(for: $0) }
        )
    }

    // MARK: - Tray

    @ViewBuilder
    private func subTray(for tool: ScrapbookTool) -> some View {
        switch tool {
        case .pencil:
            PencilTray(controller: pencil)
        case .sticker:
            StickerTray(sheets: viewModel.stickerTraySheets,
                        openSetID: viewModel.isStickerSheetOpen ? viewModel.stickerSetID : nil,
                        onToggle: viewModel.toggleStickerSheet)
        case .photo:
            PhotoTray(photos: viewModel.trayPhotos,
                      aspectRatio: viewModel.aspectRatio(of:),
                      controller: trayDrag,
                      emptyMessage: viewModel.emptyPhotoTrayMessage) { id in
                viewModel.addPhoto(id, reduceMotion: reduceMotion)
            }
        case .washi:
            WashiTray(selectedID: viewModel.washiStyleID, onSelect: viewModel.selectWashi)
        case .letters:
            LetterTray(controller: trayDrag) { letter in viewModel.addLetter(letter) }
        case .text, .scissors:
            EmptyView()
        }
    }
}

/// Pure geometry and orientation helpers for `ScrapbookEditorView` across iPhone and iPad (change 107).
struct ScrapbookEditorLayout: Equatable {
    enum TrayDockEdge: String, Equatable, CaseIterable {
        case bottom
        case leading
        case trailing
    }

    enum TrayCorner: String, Equatable, CaseIterable {
        case bottomLeading
        case bottomTrailing
    }

    static let phoneDesignSize = CGSize(width: 402, height: 874)
    static let iPadDefaultPillWidth: CGFloat = 500
    static let iPadTrayEdgeInset: CGFloat = 16
    static let iPadTrayCornerInset: CGFloat = 20
    private static let baseBookWidth: CGFloat = 357.6
    private static let baseBookHeight: CGFloat = (357.6 / 2 - 7.4) * 4 / 3 + 9.5
    private static let baseMatSize = CGSize(width: 927, height: 697)
    private static let baseCoverSize = CGSize(width: 340, height: 468)

    static func iPadTrayPillWidth(for container: CGSize) -> CGFloat {
        let shortSide = min(container.width, container.height)
        guard shortSide > 0 else { return iPadDefaultPillWidth }
        return min(iPadDefaultPillWidth, max(320, shortSide - 32))
    }

    static func iPadOpenTrayDepth(hasSubTray: Bool) -> CGFloat {
        hasSubTray ? (TrayStyle.trayHeight * 2 - TrayStyle.overlap) : TrayStyle.trayHeight
    }

    static func iPadTrayRotation(for dock: TrayDockEdge) -> Angle {
        switch dock {
        case .bottom: .zero
        case .leading: .degrees(90)
        case .trailing: .degrees(-90)
        }
    }

    static func iPadOpenTrayCenter(container: CGSize, dock: TrayDockEdge, hasSubTray: Bool) -> CGPoint {
        let depth = iPadOpenTrayDepth(hasSubTray: hasSubTray)
        switch dock {
        case .bottom:
            return CGPoint(x: container.width / 2, y: container.height - iPadTrayEdgeInset - depth / 2)
        case .leading:
            return CGPoint(x: iPadTrayEdgeInset + depth / 2, y: container.height / 2)
        case .trailing:
            return CGPoint(x: container.width - iPadTrayEdgeInset - depth / 2, y: container.height / 2)
        }
    }

    static func iPadClosedTrayCenter(container: CGSize, corner: TrayCorner) -> CGPoint {
        let radius = TrayStyle.closedSize / 2
        let y = container.height - iPadTrayCornerInset - radius
        switch corner {
        case .bottomLeading:
            return CGPoint(x: iPadTrayCornerInset + radius, y: y)
        case .bottomTrailing:
            return CGPoint(x: container.width - iPadTrayCornerInset - radius, y: y)
        }
    }

    static func resolveIPadTrayDrag(
        container: CGSize,
        currentDock: TrayDockEdge,
        currentCorner: TrayCorner,
        hasSubTray: Bool,
        translation: CGSize,
        predictedEndTranslation: CGSize
    ) -> (isOpen: Bool, dock: TrayDockEdge, corner: TrayCorner) {
        let start = iPadOpenTrayCenter(container: container, dock: currentDock, hasSubTray: hasSubTray)
        let end = CGPoint(x: start.x + translation.width, y: start.y + translation.height)
        let projected = CGPoint(
            x: start.x + (translation.width + predictedEndTranslation.width) * 0.5,
            y: start.y + (translation.height + predictedEndTranslation.height) * 0.5
        )
        let nearestCorner: TrayCorner = end.x <= container.width / 2 ? .bottomLeading : .bottomTrailing

        // Outward swipe toward the currently docked edge folds the pill into a corner circle button.
        switch currentDock {
        case .bottom where translation.height > 36 && abs(translation.width) < 120:
            return (false, .bottom, nearestCorner)
        case .leading where translation.width < -36 && abs(translation.height) < 120:
            return (false, .leading, .bottomLeading)
        case .trailing where translation.width > 36 && abs(translation.height) < 120:
            return (false, .trailing, .bottomTrailing)
        default:
            break
        }

        // Dragging the pill into either bottom corner also collapses it to that corner.
        let cornerZone: CGFloat = 180
        if end.y > container.height - cornerZone && (end.x < cornerZone || end.x > container.width - cornerZone) {
            return (false, currentDock, nearestCorner)
        }

        let distLeading = max(0, projected.x)
        let distTrailing = max(0, container.width - projected.x)
        let distBottom = max(0, (container.height - projected.y) * 0.85)

        if distLeading <= distBottom && distLeading <= distTrailing {
            return (true, .leading, .bottomLeading)
        } else if distTrailing <= distBottom && distTrailing <= distLeading {
            return (true, .trailing, .bottomTrailing)
        } else {
            return (true, .bottom, currentCorner)
        }
    }

    static func resolveIPadClosedTrayDrag(
        container: CGSize,
        currentDock: TrayDockEdge,
        currentCorner: TrayCorner,
        translation: CGSize,
        predictedEndTranslation: CGSize
    ) -> (dock: TrayDockEdge, corner: TrayCorner) {
        let start = iPadClosedTrayCenter(container: container, corner: currentCorner)
        let projectedX = start.x + (translation.width + predictedEndTranslation.width) * 0.5
        let corner: TrayCorner = projectedX <= container.width / 2 ? .bottomLeading : .bottomTrailing
        let dock: TrayDockEdge
        switch currentDock {
        case .bottom:
            dock = .bottom
        case .leading, .trailing:
            dock = corner == .bottomLeading ? .leading : .trailing
        }
        return (dock, corner)
    }

    static func orientationMask(
        isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad,
        allowsLandscape: Bool
    ) -> UIInterfaceOrientationMask {
        if isPad {
            return OrientationLock.defaultMask(for: .pad)
        }
        return allowsLandscape ? [.portrait, .landscapeLeft, .landscapeRight] : .portrait
    }

    static func fitScale(
        for container: CGSize,
        isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    ) -> CGFloat {
        guard container.width > 0, container.height > 0 else { return 1 }
        if isPad {
            return min(container.width / phoneDesignSize.width, container.height / phoneDesignSize.height)
        }
        return container.width / phoneDesignSize.width
    }

    /// Scale for the green cutting mat behind `ScrapbookBookView` (keeps wood margins balanced on iPad).
    static func bookMatScale(
        for container: CGSize,
        isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    ) -> CGFloat {
        guard isPad, container.width > 0, container.height > 0 else {
            return fitScale(for: container, isPad: isPad)
        }
        return min((container.width * 0.90) / baseMatSize.width,
                   (container.height * 0.86) / baseMatSize.height)
    }

    /// Scale for the open book in `ScrapbookBookView` so it fills the iPad screen generously while leaving room
    /// for the top Back button, bottom Done pill, and page hint tooltip.
    static func bookScale(
        for container: CGSize,
        isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    ) -> CGFloat {
        guard isPad, container.width > 0, container.height > 0 else {
            return fitScale(for: container, isPad: isPad)
        }
        let matWidth = baseMatSize.width * bookMatScale(for: container, isPad: true)
        let matHeight = baseMatSize.height * bookMatScale(for: container, isPad: true)
        let maxBookWidth = min(container.width * 0.80, matWidth * 0.86)
        let maxBookHeight = min(container.height * 0.54, max(220, container.height - 270), matHeight * 0.76)
        return min(maxBookWidth / baseBookWidth, maxBookHeight / baseBookHeight)
    }

    /// Scale for the front cover in `ScrapbookCoverScreen` and `editCoverView` so it fills iPad viewports cleanly.
    static func coverScale(
        for container: CGSize,
        isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    ) -> CGFloat {
        guard isPad, container.width > 0, container.height > 0 else {
            return fitScale(for: container, isPad: isPad)
        }
        let maxCoverWidth = container.width * 0.78
        let maxCoverHeight = max(220, container.height - 250)
        return min(maxCoverWidth / baseCoverSize.width, maxCoverHeight / baseCoverSize.height)
    }

    static func iPadSpreadPageWidth(
        container: CGSize,
        safeAreaInsets: EdgeInsets = .init(),
        isLandscape: Bool,
        zoom: SpreadZoom
    ) -> CGFloat {
        if isLandscape {
            let fullHeight = container.height + safeAreaInsets.top + safeAreaInsets.bottom
            return min(container.width / 2, fullHeight * 3 / 4)
        } else {
            let availableHeight = max(240, container.height - 200)
            let fitHeightWidth = availableHeight * 3 / 4
            return zoom == .spread
                ? min(container.width / 2, fitHeightWidth)
                : min(container.width, fitHeightWidth)
        }
    }
}
