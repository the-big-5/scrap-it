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
        // Only the spread turns to landscape (change 025).
        .onChange(of: viewModel.allowsLandscape, initial: true) { _, allows in
            OrientationLock.set(allows ? [.portrait, .landscapeLeft, .landscapeRight] : .portrait)
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
            pencil.onDrawingChanged = { [viewModel] pageID, data in viewModel.updateDrawing(data, onPage: pageID) }
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
            let scale = geometry.size.width / 402
            ZStack(alignment: .bottomLeading) {
                CoverCuttingMat()

                VStack(spacing: 0) {
                    ZStack {
                        Text("Edit Cover")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DSColor.Brand.primary.color)
                        HStack {
                            Spacer()
                            if viewModel.coverSide == .front {
                                SpreadEditorButton(icon: .system("arrow.right"), accessibilityLabel: "Spine",
                                                   action: viewModel.showSpine)
                            } else {
                                SpreadEditorButton(icon: .system("checkmark"), accessibilityLabel: "Done",
                                                   action: viewModel.finishCoverEdit)
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 4)
                    Spacer(minLength: 0)
                    coverSideCell(scale: scale)
                    // Room for the color picker above the tray, so the cover sits higher (change 026).
                    Spacer(minLength: TrayStyle.trayHeight + 24 + 54 + 16)
                }
                .zIndex(viewModel.draggedItemID != nil ? 2 : 0)

                CoverColorButton(colorHex: viewModel.coverColorHex, onChange: viewModel.setCoverColor)
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
                    isFixed: true
                ) { tool in
                    subTray(for: tool)
                }
                .padding(.bottom, 4)
                .zIndex(1)

                trashCan
                    .padding(.bottom, trashBottomPadding)

                if viewModel.activeTool == .pencil && pencil.showsSizePanel {
                    PenSizePanel(controller: pencil)
                        .padding(.leading, 14)
                        .padding(.bottom, 4 + TrayStyle.trayHeight * 2 - TrayStyle.overlap + 6)
                        .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
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
        .animation(.spring(response: 0.25, dampingFraction: 0.78), value: viewModel.draggedItemID != nil)
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

                if isLandscape {
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
        .animation(.spring(response: 0.25, dampingFraction: 0.78), value: viewModel.draggedItemID != nil)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.isTrashTargeted) { _, isTargeted in isTargeted }
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.trashedItemCount)
        .onChange(of: viewModel.zoom) { updateTrayDropFrame() }
        .onChange(of: viewModel.currentPageID) { updateTrayDropFrame() }
    }

    private func portraitLayout(_ geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let pageWidth = viewModel.zoom == .spread ? width / 2 : width - 21
        return ZStack(alignment: .bottomLeading) {
            VStack(spacing: 0) {
                portraitTopBar
                Spacer(minLength: 0)
                spread(pageWidth: pageWidth, viewportWidth: width,
                       offsetX: viewModel.zoom == .right ? width - 2 * pageWidth : 0)
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

            if viewModel.activeTool == .pencil && pencil.showsSizePanel {
                // The size panel opens above the Pencil tray.
                PenSizePanel(controller: pencil)
                    .padding(.leading, 14)
                    .padding(.bottom, 4 + TrayStyle.trayHeight * 2 - TrayStyle.overlap + 6)
                    .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
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

    /// Landscape: always the spread (no zoom). Buttons run down the notch side, the tray stands up on the other.
    private func landscapeLayout(_ geometry: GeometryProxy) -> some View {
        let insets = geometry.safeAreaInsets
        let buttonsOnLeading = insets.leading >= insets.trailing
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

            if viewModel.activeTool == .pencil && pencil.showsSizePanel {
                PenSizePanel(controller: pencil)
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: buttonsOnLeading ? .bottomTrailing : .bottomLeading)
                    .padding(.horizontal, trayDepth + 12)
                    .padding(.bottom, 12)
                    .transition(.opacity)
                    .zIndex(1)
            }
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

    /// Both pages side by side; zoom slides one page into view (the other peeks at the edge and takes no touches).
    private func spread(pageWidth: CGFloat, viewportWidth: CGFloat, offsetX: CGFloat) -> some View {
        let pageHeight = pageWidth * 4 / 3
        return HStack(spacing: 0) {
            ForEach(viewModel.currentSpreadPages, id: \.id) { page in
                pageCell(page)
            }
        }
        // Pages size to this frame, so the zoom from the book scales them smoothly.
        .matchedGeometryEffect(id: ScrapbookBookView.spreadMatchID, in: spreadNamespace)
        .frame(width: pageWidth * 2, height: pageHeight, alignment: .leading)
        .offset(x: offsetX)
        .frame(width: viewportWidth, height: pageHeight, alignment: .leading)
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
        .clipShape(Rectangle().inset(by: viewModel.draggedItemID != nil ? -2000 : 0))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    private func pageCell(_ page: ScrapbookPage) -> some View {
        let isEditable = viewModel.editablePages.contains { $0.id == page.id }
        let holdsDraggedItem = page.allItems.contains { $0.id == viewModel.draggedItemID || $0.id == viewModel.selectedItemID }
        return ScrapbookPageView(
            page: page,
            photos: viewModel.photosByID,
            selectedItemID: viewModel.selectedItemID,
            photoAspect: viewModel.photoAspect(for:),
            shouldPlay: viewModel.shouldPlay(_:isInteracting:),
            actions: itemActions(for: page),
            activeDrawingID: viewModel.drawingLayerIDs[page.id],
            draggedItemID: viewModel.draggedItemID,
            isTrashTargeted: viewModel.isTrashTargeted
        )
        .scrapbookPageEdgeShadow()
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
        // An item dragged past the gutter is drawn above the other page.
        .zIndex(holdsDraggedItem ? 1 : 0)
    }

    /// The tool using touches on a page, if any.
    @ViewBuilder
    private func pageOverlay(for page: ScrapbookPage, size: CGSize) -> some View {
        let isActive = page.id == viewModel.currentPageID
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
                onDragMoved: { id, location in viewModel.updateItemDrag(itemID: id, pageLocation: location) },
                onDropInTrash: { viewModel.endItemDrag(itemID: $0) },
                onCancelDrag: { viewModel.cancelItemDrag() }
            )
            .overlay(alignment: .top) { if isActive { hint(for: .scissors) } }
            .transition(.opacity)
        } else if viewModel.isDrawing {
            // Pencil draws straight on every page on screen, each into its own layer.
            if let layerID = viewModel.drawingLayerIDs[page.id] {
                DrawingCanvasView(drawingData: viewModel.drawingData(onPage: page.id),
                                  pageID: page.id,
                                  pageSize: size,
                                  controller: pencil,
                                  remoteRevision: viewModel.remoteDrawingRevision)
                    .id(layerID)
                    .overlay(alignment: .top) { if isActive { hint(for: .pencil) } }
            }
        } else if let style = viewModel.washiStyleID.flatMap(WashiCatalog.style(withID:)) {
            WashiPullOverlay(style: style, pageSize: size,
                             hint: isActive && viewModel.hintTool == .washi ? ScrapbookTool.washi.hint(isPad: isPad) : nil) { start, end, seed in
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
            dragChanged: { id, location in viewModel.updateItemDrag(itemID: id, pageLocation: location) },
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
