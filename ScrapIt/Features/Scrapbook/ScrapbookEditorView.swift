import SwiftUI

/// Scrapbook editor (change 013). Opens right after a roll ends and from Profile, in edit mode.
/// Temporary look from the camera POC until the design team's flow is ready.
struct ScrapbookEditorView: View {
    @State private var viewModel: ScrapbookViewModel
    @State private var stickerController = StickerDragController()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: ScrapbookViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrapTheme.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                hint
                pageArea
                pageIndicator
                if viewModel.tool == .arrange {
                    toolbar
                }
            }
            .padding(.bottom, viewModel.tool == .arrange ? 8 : 0)

            if viewModel.tool == .stickers, let sheet = viewModel.currentStickerSheet {
                StickerPanel(
                    set: viewModel.stickerSet,
                    sheet: sheet,
                    controller: stickerController,
                    isCollapsed: $viewModel.isStickerPanelCollapsed,
                    onClose: {
                        guard stickerController.session == nil else { return }
                        viewModel.finishTool()
                    },
                    onNewSheet: viewModel.takeNewStickerSheet
                )
                .transition(.move(edge: .bottom))
            }

            StickerDragLayer(controller: stickerController)

            if let message = viewModel.toastMessage {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.regularMaterial))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 60)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: StickerDragController.coordinateSpace)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.tool)
        .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $viewModel.isPhotoPickerPresented) {
            ScrapbookPhotoPickerView(photos: viewModel.rollPhotos, limit: viewModel.remainingSlots) { ids in
                viewModel.addPhotos(ids, reduceMotion: reduceMotion)
            }
        }
        .sheet(isPresented: $viewModel.isBackgroundPickerPresented) {
            BackgroundPickerView(selection: viewModel.currentBackground, onSelect: viewModel.setBackground)
                .presentationDetents([.medium])
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
        }
        .onDisappear {
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
                if viewModel.tool == .scissors || viewModel.canUndoCut {
                    Button(action: viewModel.undoLastCut) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .disabled(!viewModel.canUndoCut)
                    .accessibilityLabel("Undo cut")
                    .padding(.trailing, 12)
                }
                if viewModel.tool == .scissors || viewModel.tool == .pencil {
                    Button("Done", action: viewModel.finishTool)
                        .fontWeight(.semibold)
                }
            }
        }
        .foregroundStyle(ScrapTheme.charcoal)
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var hint: some View {
        switch viewModel.tool {
        case .scissors:
            Text("Drag across a photo to cut. Long press to move.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(ScrapTheme.secondaryText)
        case .pencil:
            Text("Draw with your finger or Apple Pencil.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(ScrapTheme.secondaryText)
        case .arrange, .stickers:
            EmptyView()
        }
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
                actions: viewModel.tool == .arrange || viewModel.tool == .stickers ? itemActions : nil
            )
            .overlay {
                PencilCanvasView(
                    drawingData: page.drawingData,
                    isActive: viewModel.tool == .pencil,
                    onChange: { [pageID = page.id, viewModel] data in viewModel.updateDrawing(data, pageID: pageID) },
                    onStrokeCompleted: { [pageID = page.id, viewModel] data in viewModel.updateDrawing(data, pageID: pageID) }
                )
                .id(page.id)
                .allowsHitTesting(viewModel.tool == .pencil)
            }
            .overlay {
                if viewModel.tool == .scissors {
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
                    .transition(.opacity)
                }
            }
            .onFrameChange(in: .named(StickerDragController.coordinateSpace)) { frame in
                stickerController.pageFrame = frame
            }
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .padding(.horizontal)
            .frame(maxHeight: .infinity)
        } else {
            Spacer()
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
            deselect: { viewModel.selectItem(nil) }
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

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            toolButton("Photos", systemImage: "plus", action: viewModel.presentPhotoPicker)
            Spacer()
            toolButton("Background", systemImage: "paintpalette") {
                viewModel.isBackgroundPickerPresented = true
            }
            Spacer()
            toolButton("Stickers", systemImage: "face.smiling") { viewModel.selectTool(.stickers) }
            Spacer()
            toolButton("Scissors", systemImage: "scissors") { viewModel.selectTool(.scissors) }
                .disabled(viewModel.isCurrentPageFull)
            Spacer()
            toolButton("Pencil", systemImage: "pencil.tip") { viewModel.selectTool(.pencil) }
            Spacer()
            Menu {
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
                toolLabel("Pages", systemImage: "doc.on.doc")
            }
        }
        .foregroundStyle(ScrapTheme.charcoal)
        .padding(.horizontal, 20)
    }

    private func toolButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            toolLabel(title, systemImage: systemImage)
        }
    }

    private func toolLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
            Text(title)
                .font(.system(size: 10, weight: .medium))
        }
        .frame(minWidth: 44, minHeight: 44)
    }
}
