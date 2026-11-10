import SwiftUI

/// Scrapbook editor (change 013). Opens after the Roll Reveal and from Profile. Pages are always editable; tools are
/// in the leather tray at the bottom left (change 022, ported from the camera POC). Background, pages and undo are
/// at the top right.
struct ScrapbookEditorView: View {
    @State private var viewModel: ScrapbookViewModel
    @State private var stickerController = StickerDragController()
    @State private var trayDrag = TrayDragController()
    @State private var pencil = PencilController()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    init(viewModel: ScrapbookViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ScrapTheme.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 8) {
                header
                GeometryReader { geometry in
                    // 3:4 page that the two open trays never cover.
                    let pageWidth = max(min(geometry.size.width - 16,
                                            (geometry.size.height - TrayStyle.reservedHeight - 36) * 3 / 4), 120)
                    VStack(spacing: 8) {
                        pageArea
                            .frame(width: pageWidth, height: pageWidth * 4 / 3)
                        pageIndicator
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
            }

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

            if viewModel.activeTool == .pencil && pencil.showsSizePanel {
                // The size panel opens above the Pencil tray.
                PenSizePanel(controller: pencil)
                    .padding(.leading, 14)
                    .padding(.bottom, 4 + TrayStyle.trayHeight * 2 - TrayStyle.overlap + 6)
                    .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
            }

            StickerDragLayer(controller: stickerController)
            TrayDragLayer(controller: trayDrag)

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
            }

            if viewModel.textEditor != nil {
                TextEditorOverlay(
                    draft: Binding(get: { viewModel.textEditor?.draft ?? "" }, set: { viewModel.textEditor?.draft = $0 }),
                    color: Binding(get: { viewModel.textEditor?.color ?? .black }, set: { viewModel.textEditor?.color = $0 }),
                    onDone: viewModel.commitTextEditor
                )
                .transition(.opacity)
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
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $viewModel.isBackgroundPickerPresented) {
            BackgroundPickerView(selection: viewModel.currentBackground, onSelect: viewModel.setBackground)
                .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: Binding(get: { viewModel.viewerPhoto != nil },
                                              set: { if !$0 { viewModel.closePhotoViewer() } })) {
            if let photo = viewModel.viewerPhoto {
                ScrapbookPhotoViewer(photo: photo, onClose: viewModel.closePhotoViewer)
            }
        }
        .confirmationDialog("Delete this page?", isPresented: $viewModel.isDeletePageConfirmationPresented, titleVisibility: .visible) {
            Button("Delete Page", role: .destructive, action: viewModel.deleteCurrentPage)
        }
        .alert("Couldn't save the change", isPresented: $viewModel.isSaveErrorPresented) {
            Button("OK", role: .cancel) {}
        }
        .onAppear {
            viewModel.load()
            viewModel.isVisible = true
            viewModel.connectRealtimeOnAppear()
            stickerController.onPlace = { [viewModel, stickerController] sticker, center, width, rotation in
                viewModel.placeSticker(sticker, center: center, width: width, rotation: rotation,
                                       pageFrame: stickerController.pageFrame)
            }
            trayDrag.onDrop = { [viewModel, reduceMotion] payload, point in
                switch payload {
                case .photo(let id, _): viewModel.dropFromTray(.photo(id), at: point, reduceMotion: reduceMotion)
                case .letter(let letter): viewModel.dropFromTray(.letter(letter), at: point)
                }
            }
            pencil.onDrawingChanged = { [viewModel] data in viewModel.updateActiveDrawing(data) }
        }
        .onDisappear {
            viewModel.editorDidDisappear()
            viewModel.isVisible = false
            viewModel.disconnectRealtime()
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text(viewModel.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(ScrapTheme.charcoal)
                .lineLimit(1)
                .padding(.horizontal, 110)

            HStack {
                BackCircleButton(action: viewModel.goBack)

                CollaboratorPresenceHeaderView(collaborators: viewModel.activeCollaborators)
                    .padding(.leading, 6)

                Spacer()
                if viewModel.isCutting {
                    Button(action: viewModel.undoLastCut) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .disabled(!viewModel.canUndoCut)
                    .accessibilityLabel("Undo cut")
                    .padding(.trailing, 12)
                } else if viewModel.activeDrawingID != nil {
                    Button(action: pencil.undo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .disabled(!pencil.canUndo)
                    .accessibilityLabel("Undo stroke")
                    .padding(.trailing, 12)
                }
                pageMenu
            }
        }
        .foregroundStyle(ScrapTheme.charcoal)
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var pageMenu: some View {
        Menu {
            Button {
                viewModel.isBackgroundPickerPresented = true
            } label: {
                Label("Background", systemImage: "paintpalette")
            }
            Divider()
            Button(action: viewModel.addPage) {
                Label("Add Page", systemImage: "plus.rectangle.on.rectangle")
            }
            Button { viewModel.movePage(by: -1) } label: {
                Label("Move Left", systemImage: "arrow.left")
            }
            .disabled(!viewModel.canGoToPreviousPage)
            Button { viewModel.movePage(by: 1) } label: {
                Label("Move Right", systemImage: "arrow.right")
            }
            .disabled(!viewModel.canGoToNextPage)
            Button(role: .destructive) {
                viewModel.isDeletePageConfirmationPresented = true
            } label: {
                Label("Delete Page", systemImage: "trash")
            }
            .disabled(!viewModel.canDeletePage)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 22))
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Page options")
    }

    // MARK: - Page

    @ViewBuilder
    private var pageArea: some View {
        if let page = viewModel.currentPage {
            ScrapbookPageView(
                page: page,
                photos: viewModel.photosByID,
                selectedItemID: viewModel.selectedItemID,
                photoAspect: viewModel.photoAspect(for:),
                shouldPlay: viewModel.shouldPlay(_:isInteracting:),
                actions: itemActions,
                onSwipePage: viewModel.allowsPageSwipe ? { viewModel.swipePage(by: $0) } : nil,
                activeDrawingID: viewModel.activeDrawingID
            )
            .id(page.id)
            .transition(.opacity)
            .onFrameChange(in: .named(StickerDragController.coordinateSpace)) { frame in
                stickerController.pageFrame = frame
            }
            .onFrameChange(in: .global) { frame in
                trayDrag.pageFrame = frame
            }
            .overlay {
                GeometryReader { geometry in
                    pageOverlay(size: geometry.size)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
    }

    /// The tool using touches on the page, if any.
    @ViewBuilder
    private func pageOverlay(size: CGSize) -> some View {
        if viewModel.isCutting {
            ScissorsToolView(
                itemAt: { viewModel.itemID(at: $0, pageSize: $1, photosOnly: false) },
                isOverPhoto: { viewModel.itemID(at: $0, pageSize: $1, photosOnly: true) != nil },
                itemFrame: viewModel.itemFrame,
                onSelect: viewModel.selectItem,
                onMove: { id, frame in
                    viewModel.setItemFrame(itemID: id, centerX: frame.centerX, centerY: frame.centerY,
                                           width: frame.width, rotation: frame.rotation)
                },
                onFinishMove: { viewModel.finishItemManipulation(itemID: $0) },
                onCut: { viewModel.cut(along: $0, pageSize: $1) }
            )
            .overlay(alignment: .top) { hint(for: .scissors) }
            .transition(.opacity)
        } else if let drawingID = viewModel.activeDrawingID {
            DrawingCanvasView(drawingData: viewModel.activeDrawingData, pageSize: size, controller: pencil)
                .id(drawingID)
                .overlay(alignment: .top) { hint(for: .pencil) }
        } else if let style = viewModel.washiStyleID.flatMap(WashiCatalog.style(withID:)) {
            WashiPullOverlay(style: style, pageSize: size,
                             hint: viewModel.hintTool == .washi ? ScrapbookTool.washi.hint(isPad: isPad) : nil) { start, end, seed in
                viewModel.addWashi(from: start, to: end, seed: seed, pageSize: size)
            }
        } else if viewModel.isStickerSheetOpen, let sheet = viewModel.currentStickerSheet {
            StickerSheetOverlay(
                set: viewModel.stickerSet,
                sheet: sheet,
                controller: stickerController,
                pageSize: size,
                onClose: viewModel.closeStickerSheet,
                onNewSheet: viewModel.takeNewStickerSheet
            )
            .transition(.scale(scale: 0.3, anchor: .bottomLeading).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func hint(for tool: ScrapbookTool) -> some View {
        if viewModel.hintTool == tool, let text = tool.hint(isPad: isPad) {
            ScrapbookHintCapsule(text: text)
                .padding(.top, 10)
                .transition(.opacity)
        }
    }

    private var itemActions: ScrapbookItemActions {
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
            deselect: viewModel.tapEmptyPage,
            doubleTap: viewModel.doubleTapItem,
            editText: viewModel.editText
        )
    }

    private var pageIndicator: some View {
        VStack(spacing: 4) {
            HStack(spacing: 20) {
                Button(action: viewModel.goToPreviousPage) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!viewModel.canGoToPreviousPage)
                Text(viewModel.pageIndicatorText)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(ScrapTheme.secondaryText)
                Button(action: viewModel.goToNextPage) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!viewModel.canGoToNextPage)
            }
            .foregroundStyle(ScrapTheme.charcoal)
            if viewModel.isLowPowerPaused {
                Text("Live Photos paused in Low Power Mode")
                    .font(.caption)
                    .foregroundStyle(ScrapTheme.secondaryText)
            }
        }
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
            PhotoTray(photos: viewModel.trayPhotos, aspectRatio: viewModel.aspectRatio(of:), controller: trayDrag) { id in
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
