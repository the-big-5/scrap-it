import CoreGraphics
import Foundation
import Observation
import SwiftData

/// Main tray tools, left to right as in Figma (change 022).
enum ScrapbookTool: String, CaseIterable, Identifiable {
    case scissors, pencil, sticker, photo, washi, letters, text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scissors: "Scissors"
        case .pencil: "Pencil"
        case .sticker: "Stickers"
        case .photo: "Photos"
        case .washi: "Washi"
        case .letters: "Letters"
        case .text: "Text"
        }
    }

    /// Scissors turn cut mode on / off and Text opens the typing screen; the others open a second tray.
    var hasSubTray: Bool { self != .text && self != .scissors }

    /// Shown only the first time the tool is turned on in a scrapbook [Draft text]. Apple Pencil is only
    /// mentioned on iPad (iPhones don't support it).
    func hint(isPad: Bool) -> String? {
        switch self {
        case .scissors: "Drag across a photo to cut. Long press to move."
        case .pencil: isPad ? "Draw with your finger or Apple Pencil." : "Draw with your finger."
        case .washi: "Put your finger on the page and pull to stick washi tape"
        default: nil
        }
    }
}

/// Plain text being typed (change 022). `itemID == nil` = new text.
struct TextEditorState: Equatable {
    var itemID: UUID?
    var draft = ""
    var color: TextItemColor = .black
}

/// What was dragged from a tray onto the page (change 022).
enum TrayDropPayload {
    case photo(UUID)
    case letter(LetterDefinition)
}

/// Scrapbook editor (change 013, behavior ported from the camera POC). Pages are always editable (change 022):
/// the tool tray replaces the toolbar and edit mode.
@Observable
final class ScrapbookViewModel {
    static let pageFullMessage = "This page is full"
    static let maxUndoSteps = 20
    /// Taps on letters within this time line up to the right (change 022).
    static let letterRunInterval: TimeInterval = 3

    private let modelContext: ModelContext
    @ObservationIgnored private weak var navigator: (any Navigator)?
    private let sessionStore: SessionStore
    private let scrapbookID: UUID
    private let playback: LivePlaybackCoordinator
    private let imageLoader: ScrapbookImageLoader
    private let realtimeService: any ScrapbookRealtimeProviding
    let currentUser: UserProfile?

    private(set) var scrapbook: Scrapbook?
    var currentPageID: UUID?
    var selectedItemID: UUID?
    var isBackgroundPickerPresented = false
    var isDeletePageConfirmationPresented = false
    var isSaveErrorPresented = false
    // Tool tray (change 022)
    private(set) var isTrayOpen = false
    /// The tool whose second tray is open.
    private(set) var activeTool: ScrapbookTool?
    private(set) var isCutting = false
    private(set) var washiStyleID: String?
    private(set) var stickerSetID = StickerCatalog.travel.id
    private(set) var isStickerSheetOpen = false
    /// The drawing layer being drawn while Pencil is on.
    private(set) var activeDrawingID: UUID?
    var textEditor: TextEditorState?
    private(set) var viewerPhotoID: UUID?
    /// The tool whose one-time hint is showing.
    private(set) var hintTool: ScrapbookTool?
    @ObservationIgnored private var lastLetter: (id: UUID, time: Date)?
    @ObservationIgnored private var drawingSaveTask: Task<Void, Never>?
    @ObservationIgnored private var hasPendingDrawingBroadcast = false
    private(set) var remoteDrawingRevision = 0
    private(set) var toastMessage: String?
    /// Editor on screen; Live Photos only play while it is.
    var isVisible = false
    private var cutHistory: [CutUndoStep] = []
    private(set) var activeCollaborators: [CollaboratorPresence] = []
    private var isApplyingRemoteEvent = false
    // Drag-to-trash (change 062)
    private(set) var draggedItemID: UUID?
    private(set) var isTrashTargeted = false
    var trashDropFrame: CGRect = .zero
    var pageGlobalFrame: CGRect = .zero
    private(set) var trashedItemCount = 0

    init(
        modelContext: ModelContext,
        navigator: (any Navigator)? = nil,
        sessionStore: SessionStore,
        scrapbookID: UUID,
        currentUser: UserProfile? = nil,
        realtimeService: (any ScrapbookRealtimeProviding)? = nil,
        playback: LivePlaybackCoordinator = .shared,
        imageLoader: ScrapbookImageLoader = .shared
    ) {
        self.modelContext = modelContext
        self.navigator = navigator
        self.sessionStore = sessionStore
        self.scrapbookID = scrapbookID
        self.currentUser = currentUser
        if let realtimeService {
            self.realtimeService = realtimeService
        } else if let config = SupabaseConfig.load() {
            self.realtimeService = SupabaseScrapbookRealtimeService(config: config)
        } else {
            self.realtimeService = NoopScrapbookRealtimeService()
        }
        self.playback = playback
        self.imageLoader = imageLoader
        load()
    }

    // MARK: - Loading

    /// Fetches the scrapbook and makes sure it has a first page (new rolls and restored scrapbooks start empty).
    func load() {
        let id = scrapbookID
        scrapbook = (try? modelContext.fetch(FetchDescriptor<Scrapbook>(predicate: #Predicate { $0.id == id })))?.first
        guard let scrapbook else { return }
        if scrapbook.sortedPages.isEmpty {
            let page = ScrapbookPage(order: 0)
            modelContext.insert(page)
            page.scrapbook = scrapbook
            save()
        }
        if migratePageDrawings() {
            save()
        }
        if currentPageID == nil || !pages.contains(where: { $0.id == currentPageID }) {
            currentPageID = pages.first?.id
        }
    }

    var title: String { scrapbook?.title ?? "" }

    // MARK: - Pages

    var pages: [ScrapbookPage] { scrapbook?.sortedPages ?? [] }

    var currentPage: ScrapbookPage? {
        pages.first { $0.id == currentPageID } ?? pages.first
    }

    var currentIndex: Int {
        pages.firstIndex { $0.id == currentPage?.id } ?? 0
    }

    var pageIndicatorText: String { "\(currentIndex + 1) / \(max(pages.count, 1))" }
    var canGoToPreviousPage: Bool { currentIndex > 0 }
    var canGoToNextPage: Bool { currentIndex < pages.count - 1 }
    var canDeletePage: Bool { pages.count > 1 }
    var isCurrentPageFull: Bool { (currentPage?.allItems.count ?? 0) >= ScrapbookPage.maxItems }
    var remainingSlots: Int { ScrapbookPage.maxItems - (currentPage?.allItems.count ?? 0) }

    func selectPage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        showPage(pages[index].id)
        updatePresence()
    }

    /// Swipe on an empty area of the page: -1 previous, +1 next.
    func swipePage(by delta: Int) {
        guard allowsPageSwipe else { return }
        selectPage(at: currentIndex + delta)
    }

    /// Pencil keeps drawing on the new page, in that page's own layer.
    private func showPage(_ id: UUID) {
        let isDrawing = activeDrawingID != nil
        endDrawing()
        selectedItemID = nil
        lastLetter = nil
        currentPageID = id
        if isDrawing { beginDrawing() }
    }

    func goToPreviousPage() { selectPage(at: currentIndex - 1) }
    func goToNextPage() { selectPage(at: currentIndex + 1) }

    func addPage() {
        guard let scrapbook else { return }
        let newOrder = (pages.last?.order ?? -1) + 1
        let page = ScrapbookPage(order: newOrder, background: currentPage?.pageBackground ?? .cream)
        modelContext.insert(page)
        page.scrapbook = scrapbook
        save()
        showPage(page.id)
        broadcast(ScrapbookEvent(type: .pageAdded, pageIndex: newOrder, senderID: senderID, background: page.background))
        updatePresence()
    }

    func movePage(by offset: Int) {
        let fromIndex = currentIndex
        let target = currentIndex + offset
        guard let page = currentPage, pages.indices.contains(target) else { return }
        let other = pages[target]
        (page.order, other.order) = (other.order, page.order)
        save()
        broadcast(ScrapbookEvent(type: .pageMoved, pageIndex: fromIndex, senderID: senderID, targetPageIndex: target))
        updatePresence()
    }

    func deleteCurrentPage() {
        guard canDeletePage, let page = currentPage else { return }
        setActiveTool(nil)
        let deletedIndex = currentIndex
        let remaining = pages.filter { $0.id != page.id }
        let neighbor = remaining[max(currentIndex - 1, 0)]
        for (index, remainingPage) in remaining.enumerated() {
            remainingPage.order = index
        }
        cutHistory.removeAll { $0.pageID == page.id }
        selectedItemID = nil
        currentPageID = neighbor.id
        restoreStickerSlotsIfUnused(for: page.allItems, excludingIDs: Set(page.allItems.map(\.id)))
        modelContext.delete(page)
        save()
        broadcast(ScrapbookEvent(type: .pageDeleted, pageIndex: deletedIndex, senderID: senderID))
        updatePresence()
    }

    var currentBackground: PageBackground { currentPage?.pageBackground ?? .cream }

    func setBackground(_ background: PageBackground) {
        currentPage?.background = background.rawValue
        save()
        broadcast(ScrapbookEvent(type: .pageBackground, pageIndex: currentIndex, senderID: senderID, background: background.rawValue))
    }

    // MARK: - Photos

    /// Only this roll's photos (own and friends'), oldest first.
    var rollPhotos: [ScrapPhoto] {
        if let sessionID = scrapbook?.sourceSessionID {
            let descriptor = FetchDescriptor<ScrapPhoto>(
                predicate: #Predicate { $0.sourceSessionID == sessionID },
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            if let fetched = try? modelContext.fetch(descriptor), !fetched.isEmpty {
                return fetched
            }
        }
        return (scrapbook?.photos ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    var photosByID: [UUID: ScrapPhoto] {
        Dictionary(rollPhotos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Photos currently placed on any page of this scrapbook (single-use across collaborators).
    var placedPhotoIDs: Set<UUID> {
        Set(pages.flatMap(\.allItems).compactMap(\.photoID))
    }

    /// Photos tray: newest first, excluding photos already placed on a page.
    var trayPhotos: [ScrapPhoto] {
        let placed = placedPhotoIDs
        return rollPhotos.reversed().filter { !placed.contains($0.id) }
    }

    var emptyPhotoTrayMessage: String {
        rollPhotos.isEmpty
            ? "Photos from this roll appear here."
            : "All photos from this roll are on the scrapbook."
    }

    /// A photo tapped in the tray (`point == nil`: around the middle, slightly scattered as if glued by hand)
    /// or dropped at `point` (normalized to the page). Ignores photos not in this roll or already placed.
    @discardableResult
    func addPhoto(_ id: UUID, at point: CGPoint? = nil, reduceMotion: Bool = false) -> Bool {
        guard photosByID[id] != nil, !placedPhotoIDs.contains(id), let page = currentPage, hasRoom() else { return false }
        let item = ScrapbookItem(
            photoID: id,
            centerX: point.map { Double($0.x) } ?? min(max(0.5 + .random(in: -0.08...0.08), 0.1), 0.9),
            centerY: point.map { Double($0.y) } ?? min(max(0.5 + .random(in: -0.08...0.08), 0.1), 0.9),
            width: 0.45,
            rotation: .random(in: -6...6) * .pi / 180,
            zIndex: page.maxZIndex + 1,
            loopEnabled: !reduceMotion
        )
        modelContext.insert(item)
        item.page = page
        guard save() else { return false }
        broadcast(ScrapbookEvent(type: .itemPlaced, pageIndex: currentIndex, senderID: senderID, item: item.toPayload()))
        return true
    }

    func aspectRatio(of photo: ScrapPhoto) -> CGFloat {
        imageLoader.aspectRatio(for: photo.id, data: photo.imageData) ?? 3 / 4
    }

    func photoAspect(for item: ScrapbookItem) -> CGFloat? {
        guard let photoID = item.photoID, let photo = photosByID[photoID] else { return nil }
        return imageLoader.aspectRatio(for: photoID, data: photo.imageData)
    }

    func isLive(_ item: ScrapbookItem) -> Bool {
        guard let photoID = item.photoID else { return false }
        return photosByID[photoID]?.livePhotoMovieData != nil
    }

    func shouldPlay(_ item: ScrapbookItem, isInteracting: Bool) -> Bool {
        isVisible && playback.allowsPlayback && item.loopEnabled && isLive(item) && !isInteracting
    }

    var isLowPowerPaused: Bool { playback.isLowPowerMode }

    // MARK: - Items

    private func item(_ id: UUID) -> ScrapbookItem? {
        currentPage?.allItems.first { $0.id == id }
    }

    /// Selecting an item brings it to the front.
    func selectItem(_ id: UUID?) {
        selectedItemID = id
        guard let id, let page = currentPage, let item = item(id) else { return }
        if item.zIndex < page.maxZIndex || page.allItems.filter({ $0.zIndex == item.zIndex }).count > 1 {
            item.zIndex = page.maxZIndex + 1
        }
    }

    /// End of a drag / pinch / rotate. `translation` in page points.
    func commitTransform(itemID: UUID, translation: CGSize, scale: CGFloat, rotationDelta: Double, pageSize: CGSize) {
        guard let item = item(itemID), pageSize.width > 0, pageSize.height > 0 else { return }
        item.centerX = min(max(item.centerX + translation.width / pageSize.width, 0), 1)
        item.centerY = min(max(item.centerY + translation.height / pageSize.height, 0), 1)
        item.width = min(max(item.width * scale, item.widthRange.lowerBound), item.widthRange.upperBound)
        item.rotation = ScrapbookItemLayout.snappedRotation(item.rotation + rotationDelta)
        save()
        broadcastItemTransformed(item)
    }

    /// Live position / size while the scissors move an item (long-press or two fingers).
    func setItemFrame(itemID: UUID, centerX: Double, centerY: Double, width: Double, rotation: Double) {
        guard let item = item(itemID) else { return }
        item.centerX = centerX
        item.centerY = centerY
        item.width = min(max(width, item.widthRange.lowerBound), item.widthRange.upperBound)
        item.rotation = rotation
    }

    func finishItemManipulation(itemID: UUID) {
        guard let item = item(itemID) else { return }
        item.centerX = min(max(item.centerX, 0), 1)
        item.centerY = min(max(item.centerY, 0), 1)
        item.rotation = ScrapbookItemLayout.snappedRotation(item.rotation)
        save()
        broadcastItemTransformed(item)
    }

    func bringToFront(_ itemID: UUID) {
        guard let page = currentPage, let item = item(itemID) else { return }
        item.zIndex = page.maxZIndex + 1
        save()
        broadcastItemTransformed(item)
    }

    func sendToBack(_ itemID: UUID) {
        guard let page = currentPage, let item = item(itemID) else { return }
        item.zIndex = page.minZIndex - 1
        save()
        broadcastItemTransformed(item)
    }

    func toggleMotion(_ itemID: UUID) {
        guard let item = item(itemID) else { return }
        item.loopEnabled.toggle()
        save()
        broadcastItemTransformed(item)
    }

    func removeItem(_ itemID: UUID) {
        guard let item = item(itemID) else { return }
        if selectedItemID == itemID { selectedItemID = nil }
        restoreStickerSlotsIfUnused(for: [item], excludingIDs: [itemID])
        modelContext.delete(item)
        if save() {
            broadcast(ScrapbookEvent(type: .itemRemoved, pageIndex: currentIndex, senderID: senderID, itemID: itemID))
        }
    }

    private func restoreStickerSlotsIfUnused(for removedItems: [ScrapbookItem], excludingIDs: Set<UUID>) {
        for stickerID in Set(removedItems.compactMap(\.stickerID)) {
            let stillPlaced = pages.flatMap(\.allItems).contains {
                !excludingIDs.contains($0.id) && $0.stickerID == stickerID
            }
            guard !stillPlaced,
                  let match = StickerCatalog.sticker(withID: stickerID),
                  let sheet = existingSheet(for: match.set) else { continue }
            sheet.usedStickerIDs.removeAll { $0 == stickerID }
        }
    }

    func updateItemDrag(itemID: UUID, pageLocation: CGPoint) {
        draggedItemID = itemID
        let globalPoint = CGPoint(
            x: pageGlobalFrame.minX + pageLocation.x,
            y: pageGlobalFrame.minY + pageLocation.y
        )
        isTrashTargeted = !trashDropFrame.isEmpty && trashDropFrame.insetBy(dx: -24, dy: -24).contains(globalPoint)
    }

    @discardableResult
    func endItemDrag(itemID: UUID) -> Bool {
        let shouldDelete = draggedItemID == itemID && isTrashTargeted
        draggedItemID = nil
        isTrashTargeted = false
        guard shouldDelete else { return false }
        removeItem(itemID)
        trashedItemCount &+= 1
        return true
    }

    func cancelItemDrag(for itemID: UUID? = nil) {
        if let itemID, draggedItemID != itemID { return }
        draggedItemID = nil
        isTrashTargeted = false
    }

    /// Double tap: a photo opens full screen, a text opens for editing.
    func doubleTapItem(_ itemID: UUID) {
        guard let item = item(itemID) else { return }
        switch item.kind {
        case .photo: viewerPhotoID = item.photoID
        case .text: editText(itemID)
        default: break
        }
    }

    var viewerPhoto: ScrapPhoto? { viewerPhotoID.flatMap { photosByID[$0] } }

    func closePhotoViewer() {
        viewerPhotoID = nil
    }

    private func broadcastItemTransformed(_ item: ScrapbookItem) {
        broadcast(ScrapbookEvent(
            type: .itemTransformed,
            pageIndex: currentIndex,
            senderID: senderID,
            itemID: item.id,
            centerX: item.centerX,
            centerY: item.centerY,
            width: item.width,
            rotation: item.rotation,
            zIndex: item.zIndex,
            loopEnabled: item.loopEnabled
        ))
    }

    // MARK: - Tool tray

    /// The raised tool in the main tray (the scissors while cutting).
    var raisedTool: ScrapbookTool? { isCutting ? .scissors : activeTool }

    /// Page swipes and item moves only while no tool uses touches on the page.
    var allowsPageSwipe: Bool {
        !isCutting && activeDrawingID == nil && washiStyleID == nil && !isStickerSheetOpen
    }

    func openTray() {
        isTrayOpen = true
    }

    /// Swipe down on the main tray: it folds back and the active tool turns off.
    func closeTray() {
        setActiveTool(nil)
        setCutting(false)
        isTrayOpen = false
    }

    func selectTrayTool(_ tool: ScrapbookTool) {
        selectedItemID = nil
        switch tool {
        case .scissors:
            setActiveTool(nil)
            setCutting(!isCutting)
        case .text:
            setCutting(false)
            setActiveTool(nil)
            textEditor = TextEditorState()
        default:
            setCutting(false)
            setActiveTool(activeTool == tool ? nil : tool)
        }
    }

    /// Tap on an empty spot of the page: deselect and close the second tray.
    func tapEmptyPage() {
        selectedItemID = nil
        setActiveTool(nil)
    }

    private func setActiveTool(_ tool: ScrapbookTool?) {
        guard tool != activeTool else { return }
        cancelItemDrag()
        switch activeTool {
        case .pencil: endDrawing()
        case .washi: setWashi(nil)
        case .sticker: isStickerSheetOpen = false
        default: break
        }
        activeTool = tool
        if tool == .pencil, !beginDrawing() {
            activeTool = nil
        }
    }

    private func setCutting(_ isOn: Bool) {
        guard isOn != isCutting else { return }
        cancelItemDrag()
        isCutting = isOn
        if isOn {
            showHintOnce(.scissors)
        } else if hintTool == .scissors {
            hintTool = nil
        }
    }

    /// The tool's hint shows only the first time it's turned on in this scrapbook.
    private func showHintOnce(_ tool: ScrapbookTool) {
        guard let scrapbook, !scrapbook.shownToolHints.contains(tool.rawValue) else { return }
        scrapbook.shownToolHints.append(tool.rawValue)
        save()
        hintTool = tool
    }

    private func hasRoom() -> Bool {
        guard !isCurrentPageFull else {
            showToast(Self.pageFullMessage)
            return false
        }
        return true
    }

    /// A polaroid or letter dropped from the tray. `point` normalized to the page.
    func dropFromTray(_ payload: TrayDropPayload, at point: CGPoint, reduceMotion: Bool = false) -> Bool {
        switch payload {
        case .photo(let id): addPhoto(id, at: point, reduceMotion: reduceMotion)
        case .letter(let letter): addLetter(letter, at: point)
        }
    }

    // MARK: - Letters

    /// A cut-out letter. Taps within 3 s line up to the right and wrap at the page edge; a drag drops it at `point`.
    @discardableResult
    func addLetter(_ letter: LetterDefinition, at point: CGPoint? = nil, now: Date = .now) -> Bool {
        guard let page = currentPage, hasRoom() else { return false }
        let width = Double(LetterCatalog.placedHeight * letter.aspectRatio)
        // Letter height in page heights (the page is 3:4), plus line spacing.
        let lineHeight = Double(LetterCatalog.placedHeight) * 3 / 4 * 1.2
        let center: CGPoint
        if let point {
            center = point
        } else if let last = lastLetter, now.timeIntervalSince(last.time) < Self.letterRunInterval,
                  let previous = page.allItems.first(where: { $0.id == last.id }) {
            var x = previous.centerX + previous.width / 2 + width / 2 + 0.005
            var y = previous.centerY
            if x + width / 2 > 0.97 {
                x = 0.05 + width / 2
                y += lineHeight
            }
            center = CGPoint(x: x, y: min(y, 0.95))
        } else {
            center = CGPoint(x: 0.12 + width / 2, y: 0.35)
        }
        let item = ScrapbookItem(centerX: center.x, centerY: center.y, width: width,
                                 rotation: .random(in: -8...8) * .pi / 180, zIndex: page.maxZIndex + 1)
        item.letterID = letter.id
        modelContext.insert(item)
        item.page = page
        lastLetter = point == nil ? (item.id, now) : nil
        let saved = save()
        if saved {
            broadcast(ScrapbookEvent(type: .itemPlaced, pageIndex: currentIndex, senderID: senderID, item: item.toPayload()))
        }
        return saved
    }

    // MARK: - Washi

    func selectWashi(_ style: WashiStyle) {
        setWashi(washiStyleID == style.id ? nil : style.id)
    }

    private func setWashi(_ id: String?) {
        washiStyleID = id
        if id != nil {
            showHintOnce(.washi)
        } else if hintTool == .washi {
            hintTool = nil
        }
    }

    /// A torn washi piece from `start` to `end` (page points), in front of everything. Pulls shorter than the
    /// minimum length are cancelled.
    func addWashi(from start: CGPoint, to end: CGPoint, seed: Int, pageSize: CGSize) -> Bool {
        guard let styleID = washiStyleID, let page = currentPage, pageSize.width > 0, pageSize.height > 0 else { return false }
        let length = Double(hypot(end.x - start.x, end.y - start.y) / pageSize.width)
        guard length >= WashiCatalog.minimumLength, hasRoom() else { return false }
        let item = ScrapbookItem(
            centerX: Double((start.x + end.x) / 2 / pageSize.width),
            centerY: Double((start.y + end.y) / 2 / pageSize.height),
            width: length,
            rotation: Double(atan2(end.y - start.y, end.x - start.x)),
            zIndex: page.maxZIndex + 1
        )
        item.washiID = styleID
        item.washiLength = length
        item.tearSeed = seed
        modelContext.insert(item)
        item.page = page
        let saved = save()
        if saved {
            broadcast(ScrapbookEvent(type: .itemPlaced, pageIndex: currentIndex, senderID: senderID, item: item.toPayload()))
        }
        return saved
    }

    // MARK: - Text

    func editText(_ itemID: UUID) {
        guard let item = item(itemID), item.kind == .text else { return }
        textEditor = TextEditorState(itemID: itemID, draft: item.text ?? "", color: TextItemColor.from(item.textColor))
    }

    /// Done or a tap outside: a new text goes to the middle (y 40%). Empty text isn't added; clearing an existing
    /// text removes it.
    func commitTextEditor() {
        guard let state = textEditor else { return }
        textEditor = nil
        guard let page = currentPage else { return }
        let text = state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id = state.itemID, let item = item(id) {
            if text.isEmpty {
                if selectedItemID == id { selectedItemID = nil }
                modelContext.delete(item)
                if save() {
                    broadcast(ScrapbookEvent(type: .itemRemoved, pageIndex: currentIndex, senderID: senderID, itemID: id))
                }
            } else {
                item.text = text
                item.textColor = state.color.rawValue
                if save() {
                    broadcast(ScrapbookEvent(
                        type: .itemTextUpdated,
                        pageIndex: currentIndex,
                        senderID: senderID,
                        itemID: item.id,
                        text: text,
                        textColor: item.textColor
                    ))
                }
            }
        } else if !text.isEmpty, hasRoom() {
            let item = ScrapbookItem(centerX: 0.5, centerY: 0.4, width: TextItemStyle.defaultSize,
                                     rotation: 0, zIndex: page.maxZIndex + 1)
            item.text = text
            item.textColor = state.color.rawValue
            modelContext.insert(item)
            item.page = page
            if save() {
                broadcast(ScrapbookEvent(type: .itemPlaced, pageIndex: currentIndex, senderID: senderID, item: item.toPayload()))
            }
        }
    }

    // MARK: - Stickers

    var stickerSet: StickerSet { StickerCatalog.set(withID: stickerSetID) ?? StickerCatalog.travel }

    /// The newest sheet of a set, without creating one (tray thumbnails).
    func existingSheet(for set: StickerSet) -> StickerSheet? {
        (scrapbook?.stickerSheets ?? []).filter { $0.setID == set.id }.max { $0.createdAt < $1.createdAt }
    }

    var stickerTraySheets: [(set: StickerSet, sheet: StickerSheet?)] {
        StickerCatalog.sets.map { ($0, existingSheet(for: $0)) }
    }

    /// The newest sheet for the open set; a full new one is created when there is none.
    var currentStickerSheet: StickerSheet? { sheet(for: stickerSet) }

    private func sheet(for set: StickerSet) -> StickerSheet? {
        guard let scrapbook else { return nil }
        if let sheet = existingSheet(for: set) {
            return sheet
        }
        let sheet = StickerSheet(setID: set.id)
        modelContext.insert(sheet)
        sheet.scrapbook = scrapbook
        return sheet
    }

    /// Tapping a sheet in the tray opens it on the page; the same sheet again puts it back.
    func toggleStickerSheet(_ set: StickerSet) {
        if isStickerSheetOpen && stickerSetID == set.id {
            isStickerSheetOpen = false
        } else {
            stickerSetID = set.id
            _ = currentStickerSheet
            save()
            isStickerSheetOpen = true
        }
    }

    func closeStickerSheet() {
        isStickerSheetOpen = false
    }

    func takeNewStickerSheet() {
        currentStickerSheet?.usedStickerIDs = []
        if save() {
            broadcast(ScrapbookEvent(
                type: .stickerSheetReset,
                pageIndex: currentIndex,
                senderID: senderID,
                stickerSetID: stickerSetID
            ))
        }
    }

    /// A sticker dropped on the page. `center` and `width` in the same space as `pageFrame`.
    /// Returns `false` when it must go back to the sheet.
    func placeSticker(_ sticker: StickerDefinition, center: CGPoint, width: CGFloat, rotation: Double, pageFrame: CGRect) -> Bool {
        guard let page = currentPage, let set = StickerCatalog.sticker(withID: sticker.id)?.set,
              let sheet = sheet(for: set), pageFrame.width > 0, pageFrame.height > 0 else {
            return false
        }
        guard !sheet.isUsed(sticker) else { return false }
        guard page.allItems.count < ScrapbookPage.maxItems else {
            showToast(Self.pageFullMessage)
            return false
        }
        let item = ScrapbookItem(
            stickerID: sticker.id,
            centerX: (center.x - pageFrame.minX) / pageFrame.width,
            centerY: (center.y - pageFrame.minY) / pageFrame.height,
            width: width / pageFrame.width,
            rotation: rotation,
            zIndex: page.maxZIndex + 1
        )
        modelContext.insert(item)
        item.page = page
        sheet.usedStickerIDs.append(sticker.id)
        let saved = save()
        if saved {
            broadcast(ScrapbookEvent(type: .itemPlaced, pageIndex: currentIndex, senderID: senderID, item: item.toPayload()))
        }
        return saved
    }

    // MARK: - Scissors

    var canUndoCut: Bool { !cutHistory.isEmpty }

    /// Topmost item whose shape contains the page point. Only photos can be cut (`photosOnly`); drawing layers
    /// and text are skipped.
    func itemID(at point: CGPoint, pageSize: CGSize, photosOnly: Bool) -> UUID? {
        guard let page = currentPage else { return nil }
        return page.sortedItems.reversed().first { item in
            switch item.kind {
            case .photo: break
            case .drawing, .text: return false
            case .sticker, .letter, .washi: if photosOnly { return false }
            }
            let box = ScrapbookItemLayout.boxSize(of: item, photoAspect: photoAspect(for: item), pageSize: pageSize)
            let local = ScrapbookItemLayout.normalizedPoint(point, in: item, box: box, pageSize: pageSize)
            return CutGeometry.contains(item.maskPolygon ?? CutGeometry.unitSquare, local)
        }?.id
    }

    func itemFrame(_ itemID: UUID) -> (centerX: Double, centerY: Double, width: Double, rotation: Double)? {
        guard let item = item(itemID) else { return nil }
        return (item.centerX, item.centerY, item.width, item.rotation)
    }

    /// Cuts the topmost photo the stroke crosses. Every crossing of the whole stroke splits, so one stroke
    /// can make more than two pieces. Pieces move ±3 pt apart so the cut shows. `true` if something was cut.
    @discardableResult
    func cut(along pagePath: [CGPoint], pageSize: CGSize) -> Bool {
        guard let page = currentPage, pageSize.width > 0, pageSize.height > 0 else { return false }
        let freeSlots = ScrapbookPage.maxItems - page.allItems.count
        guard freeSlots > 0 else {
            showToast(Self.pageFullMessage)
            return false
        }
        let path = CutGeometry.simplify(pagePath, tolerance: 1.5)

        for item in page.sortedItems.reversed() where item.kind == .photo {
            let box = ScrapbookItemLayout.boxSize(of: item, photoAspect: photoAspect(for: item), pageSize: pageSize)
            let localPath = path.map { ScrapbookItemLayout.normalizedPoint($0, in: item, box: box, pageSize: pageSize) }
            guard let pieces = CutGeometry.splitAll(item.maskPolygon ?? CutGeometry.unitSquare, by: localPath,
                                                    minimumArea: CutGeometry.minimumPieceArea,
                                                    maxPieces: freeSlots + 1) else { continue }

            let step = CutUndoStep(original: ItemSnapshot(item), pageID: page.id,
                                   newPieceIDs: pieces.dropFirst().map { _ in UUID() })
            let originalCenter = CutGeometry.centroid(item.maskPolygon ?? CutGeometry.unitSquare)
            var zIndex = page.maxZIndex
            var pieceItems = [item]
            item.maskPolygon = pieces[0]
            for (polygon, id) in zip(pieces.dropFirst(), step.newPieceIDs) {
                zIndex += 1
                let piece = ScrapbookItem(photoID: item.photoID, centerX: item.centerX, centerY: item.centerY,
                                          width: item.width, rotation: item.rotation, zIndex: zIndex,
                                          loopEnabled: item.loopEnabled)
                piece.id = id
                piece.maskPolygon = polygon
                modelContext.insert(piece)
                piece.page = page
                pieceItems.append(piece)
            }

            let center = ScrapbookItemLayout.pagePoint(originalCenter, in: item, box: box, pageSize: pageSize)
            let offsets: [CGVector] = zip(pieces, pieceItems).map { polygon, piece in
                let pieceCenter = ScrapbookItemLayout.pagePoint(CutGeometry.centroid(polygon), in: piece, box: box, pageSize: pageSize)
                let dx = pieceCenter.x - center.x, dy = pieceCenter.y - center.y
                let length = max(hypot(dx, dy), 0.001)
                return CGVector(dx: dx / length * 3 / pageSize.width, dy: dy / length * 3 / pageSize.height)
            }
            for (piece, offset) in zip(pieceItems, offsets) {
                piece.centerX += offset.dx
                piece.centerY += offset.dy
            }

            guard save() else { return false }
            cutHistory.append(step)
            if cutHistory.count > Self.maxUndoSteps { cutHistory.removeFirst() }
            broadcast(ScrapbookEvent(
                type: .itemCut,
                pageIndex: currentIndex,
                senderID: senderID,
                itemID: item.id,
                maskData: item.maskData,
                newPieces: pieceItems.dropFirst().map { $0.toPayload() }
            ))
            return true
        }
        return false
    }

    /// Undoes the last cut: new pieces are removed, the original comes back exactly as before.
    func undoLastCut() {
        guard let step = cutHistory.popLast(),
              let page = pages.first(where: { $0.id == step.pageID }) else { return }
        let pageIndex = pages.firstIndex { $0.id == page.id } ?? currentIndex
        for piece in page.allItems where step.newPieceIDs.contains(piece.id) {
            if selectedItemID == piece.id { selectedItemID = nil }
            modelContext.delete(piece)
        }
        let restoredItem: ScrapbookItem
        if let original = page.allItems.first(where: { $0.id == step.original.id }) {
            step.original.restore(into: original)
            restoredItem = original
        } else {
            let restored = ScrapbookItem(centerX: 0, centerY: 0, width: 0, rotation: 0, zIndex: 0)
            step.original.restore(into: restored)
            modelContext.insert(restored)
            restored.page = page
            restoredItem = restored
        }
        if save() {
            broadcast(ScrapbookEvent(
                type: .itemCutUndone,
                pageIndex: pageIndex,
                senderID: senderID,
                restoredItem: restoredItem.toPayload(),
                removedPieceIDs: step.newPieceIDs
            ))
        }
    }

    // MARK: - Pencil (drawing layers, change 022)

    /// Strokes go into the frontmost item if it's a drawing layer; otherwise a new layer is created in front, so
    /// drawings stack with photos in the order they were added. `false` when the page is full.
    @discardableResult
    func beginDrawing() -> Bool {
        guard let page = currentPage else { return false }
        if let top = page.sortedItems.last, top.kind == .drawing {
            activeDrawingID = top.id
        } else {
            guard hasRoom() else { return false }
            let item = ScrapbookItem(centerX: 0.5, centerY: 0.5, width: 1, rotation: 0, zIndex: page.maxZIndex + 1)
            item.drawingData = Data()
            modelContext.insert(item)
            item.page = page
            activeDrawingID = item.id
            if save() {
                broadcast(ScrapbookEvent(type: .itemPlaced, pageIndex: currentIndex, senderID: senderID, item: item.toPayload()))
            }
        }
        showHintOnce(.pencil)
        return true
    }

    var activeDrawingData: Data? {
        guard let id = activeDrawingID else { return nil }
        return currentPage?.allItems.first { $0.id == id }?.drawingData
    }

    /// After each stroke or undo (`nil` = no strokes left). Saved 0.5 s after the last change.
    func updateActiveDrawing(_ data: Data?) {
        guard let id = activeDrawingID, let item = currentPage?.allItems.first(where: { $0.id == id }) else { return }
        item.drawingData = data ?? Data()
        hasPendingDrawingBroadcast = true
        drawingSaveTask?.cancel()
        drawingSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            self.hasPendingDrawingBroadcast = false
            if self.save() {
                self.broadcastDrawingUpdated(item)
            }
        }
    }

    /// Leaving Pencil: saves, and removes the layer if it has no strokes.
    func endDrawing() {
        guard let id = activeDrawingID else { return }
        drawingSaveTask?.cancel()
        let pendingBroadcast = hasPendingDrawingBroadcast
        hasPendingDrawingBroadcast = false
        activeDrawingID = nil
        if hintTool == .pencil { hintTool = nil }
        for (pageIndex, page) in pages.enumerated() {
            guard let item = page.allItems.first(where: { $0.id == id }) else { continue }
            if item.drawingData?.isEmpty != false {
                modelContext.delete(item)
                if save() {
                    broadcast(ScrapbookEvent(type: .itemRemoved, pageIndex: pageIndex, senderID: senderID, itemID: id))
                }
            } else {
                if save(), pendingBroadcast {
                    broadcastDrawingUpdated(item)
                }
            }
            return
        }
        save()
    }

    private func broadcastDrawingUpdated(_ item: ScrapbookItem) {
        let pageIndex = pages.firstIndex { $0.id == item.page?.id } ?? currentIndex
        broadcast(ScrapbookEvent(
            type: .drawingUpdated,
            pageIndex: pageIndex,
            senderID: senderID,
            itemID: item.id,
            zIndex: item.zIndex,
            drawingData: item.drawingData
        ))
    }

    /// Before change 022 a page had one drawing; it becomes one drawing layer at the back. Same 600 × 800 space,
    /// so it doesn't move. `true` if a page changed.
    private func migratePageDrawings() -> Bool {
        var changed = false
        for page in pages {
            guard let data = page.drawingData else { continue }
            let item = ScrapbookItem(centerX: 0.5, centerY: 0.5, width: 1, rotation: 0, zIndex: page.minZIndex - 1)
            item.drawingData = data
            modelContext.insert(item)
            item.page = page
            page.drawingData = nil
            changed = true
        }
        return changed
    }

    /// The editor left the screen: an open drawing is saved.
    func editorDidDisappear() {
        cancelItemDrag()
        endDrawing()
    }

    // MARK: - Realtime Collaboration

    var senderID: String {
        currentUser?.appleUserID ?? "anonymous-\(scrapbookID.uuidString.prefix(4))"
    }

    var userName: String {
        currentUser?.name ?? "Friend"
    }

    var userColorHex: String {
        Self.presenceColorHex(for: senderID)
    }

    static func presenceColorHex(for identifier: String) -> String {
        let colors = ["#E50935", "#27AE60", "#2F80ED", "#E2B93B", "#9B51E0", "#FF6B6B", "#4ECDC4"]
        let hash = abs(identifier.hashValue)
        return colors[hash % colors.count]
    }

    var resolvedRollCode: String? {
        if let sessionID = scrapbook?.sourceSessionID {
            let session = (try? modelContext.fetch(FetchDescriptor<CaptureSession>(predicate: #Predicate { $0.id == sessionID })))?.first
            if let code = session?.rollCode, !code.isEmpty {
                return code
            }
        }
        return scrapbookID.uuidString.prefix(6).uppercased()
    }

    func connectRealtime() async {
        guard let rollCode = resolvedRollCode else { return }
        let avatarThumbnail = ProfileAvatarProcessor.thumbnail(
            from: currentUser?.avatarData,
            maxPixelSize: 80,
            compressionQuality: 0.55
        )
        let presence = CollaboratorPresence(
            id: senderID,
            name: userName,
            colorHex: userColorHex,
            currentPageIndex: currentIndex,
            avatarData: avatarThumbnail
        )
        await realtimeService.connect(
            rollCode: rollCode,
            currentUser: presence,
            onEvent: { [weak self] event in
                self?.handleRemoteEvent(event)
            },
            onPresenceUpdate: { [weak self] collaborators in
                self?.activeCollaborators = collaborators
            }
        )
    }

    func connectRealtimeOnAppear() {
        Task { [weak self] in
            await self?.connectRealtime()
        }
    }

    func disconnectRealtime() {
        Task { [weak self] in
            await self?.realtimeService.disconnect()
        }
    }

    func updatePresence() {
        Task { [weak self] in
            guard let self else { return }
            await self.realtimeService.updatePresence(pageIndex: self.currentIndex)
        }
    }

    private func broadcast(_ event: ScrapbookEvent) {
        guard !isApplyingRemoteEvent else { return }
        Task { [weak self] in
            await self?.realtimeService.broadcastEvent(event)
        }
    }

    func handleRemoteEvent(_ event: ScrapbookEvent) {
        isApplyingRemoteEvent = true
        defer { isApplyingRemoteEvent = false }

        switch event.type {
        case .itemPlaced:
            guard let payload = event.item, pages.indices.contains(event.pageIndex) else { return }
            let page = pages[event.pageIndex]
            if !page.allItems.contains(where: { $0.id == payload.id }) {
                let item = ScrapbookItem(payload: payload)
                modelContext.insert(item)
                item.page = page
                if let stickerID = payload.stickerID,
                   let match = StickerCatalog.sticker(withID: stickerID),
                   let sheet = sheet(for: match.set),
                   !sheet.usedStickerIDs.contains(stickerID) {
                    sheet.usedStickerIDs.append(stickerID)
                }
                save()
            }

        case .itemTransformed:
            guard let itemID = event.itemID else { return }
            if let item = (try? modelContext.fetch(FetchDescriptor<ScrapbookItem>(predicate: #Predicate { $0.id == itemID })))?.first {
                if let cx = event.centerX { item.centerX = cx }
                if let cy = event.centerY { item.centerY = cy }
                if let w = event.width { item.width = w }
                if let rot = event.rotation { item.rotation = rot }
                if let z = event.zIndex { item.zIndex = z }
                if let loopEnabled = event.loopEnabled {
                    item.loopEnabled = loopEnabled
                }
                save()
            }

        case .itemTextUpdated:
            guard let itemID = event.itemID, let text = event.text else { return }
            if let item = (try? modelContext.fetch(FetchDescriptor<ScrapbookItem>(predicate: #Predicate { $0.id == itemID })))?.first {
                item.text = text
                if let textColor = event.textColor {
                    item.textColor = textColor
                }
                save()
            }

        case .itemCut:
            guard let itemID = event.itemID else { return }
            if let item = (try? modelContext.fetch(FetchDescriptor<ScrapbookItem>(predicate: #Predicate { $0.id == itemID })))?.first {
                item.maskData = event.maskData
                if let newPieces = event.newPieces, pages.indices.contains(event.pageIndex) {
                    let page = pages[event.pageIndex]
                    for piecePayload in newPieces {
                        if !page.allItems.contains(where: { $0.id == piecePayload.id }) {
                            let piece = ScrapbookItem(payload: piecePayload)
                            modelContext.insert(piece)
                            piece.page = page
                        }
                    }
                }
                save()
            }

        case .itemCutUndone:
            guard let restoredPayload = event.restoredItem, pages.indices.contains(event.pageIndex) else { return }
            let page = pages[event.pageIndex]
            if let removedIDs = event.removedPieceIDs {
                for piece in page.allItems where removedIDs.contains(piece.id) {
                    if selectedItemID == piece.id { selectedItemID = nil }
                    modelContext.delete(piece)
                }
            }
            if let existing = page.allItems.first(where: { $0.id == restoredPayload.id }) {
                existing.centerX = restoredPayload.centerX
                existing.centerY = restoredPayload.centerY
                existing.width = restoredPayload.width
                existing.rotation = restoredPayload.rotation
                existing.zIndex = restoredPayload.zIndex
                existing.loopEnabled = restoredPayload.loopEnabled
                existing.maskData = restoredPayload.maskData
            } else {
                let restored = ScrapbookItem(payload: restoredPayload)
                modelContext.insert(restored)
                restored.page = page
            }
            save()

        case .itemRemoved:
            guard let itemID = event.itemID else { return }
            cancelItemDrag(for: itemID)
            if let item = (try? modelContext.fetch(FetchDescriptor<ScrapbookItem>(predicate: #Predicate { $0.id == itemID })))?.first {
                if selectedItemID == itemID { selectedItemID = nil }
                if activeDrawingID == itemID {
                    drawingSaveTask?.cancel()
                    hasPendingDrawingBroadcast = false
                    activeDrawingID = nil
                }
                restoreStickerSlotsIfUnused(for: [item], excludingIDs: [itemID])
                modelContext.delete(item)
                save()
            }

        case .pageBackground:
            guard let bgString = event.background, pages.indices.contains(event.pageIndex) else { return }
            pages[event.pageIndex].background = bgString
            save()

        case .drawingUpdated:
            guard pages.indices.contains(event.pageIndex) else { return }
            let page = pages[event.pageIndex]
            if let itemID = event.itemID {
                let nextData = event.drawingData ?? Data()
                if let existing = page.allItems.first(where: { $0.id == itemID }) {
                    existing.drawingData = nextData
                    if let z = event.zIndex { existing.zIndex = z }
                } else {
                    let layer = ScrapbookItem(
                        centerX: 0.5,
                        centerY: 0.5,
                        width: 1,
                        rotation: 0,
                        zIndex: event.zIndex ?? (page.maxZIndex + 1)
                    )
                    layer.id = itemID
                    layer.drawingData = nextData
                    modelContext.insert(layer)
                    layer.page = page
                }
                save()
                if activeDrawingID == itemID {
                    remoteDrawingRevision &+= 1
                }
            } else {
                page.drawingData = event.drawingData
                save()
            }

        case .stickerSheetReset:
            guard let setID = event.stickerSetID, let set = StickerCatalog.set(withID: setID) else { return }
            sheet(for: set)?.usedStickerIDs = []
            save()

        case .pageAdded:
            guard let scrapbook else { return }
            let order = event.pageIndex
            let bg = PageBackground(rawValue: event.background ?? "") ?? .cream
            let page = ScrapbookPage(order: order, background: bg)
            modelContext.insert(page)
            page.scrapbook = scrapbook
            save()

        case .pageMoved:
            guard let target = event.targetPageIndex,
                  pages.indices.contains(event.pageIndex),
                  pages.indices.contains(target) else { return }
            let from = pages[event.pageIndex]
            let to = pages[target]
            (from.order, to.order) = (to.order, from.order)
            save()

        case .pageDeleted:
            guard pages.indices.contains(event.pageIndex) else { return }
            cancelItemDrag()
            let page = pages[event.pageIndex]
            let remaining = pages.filter { $0.id != page.id }
            for (index, remainingPage) in remaining.enumerated() {
                remainingPage.order = index
            }
            if currentPageID == page.id, let neighbor = remaining.first {
                currentPageID = neighbor.id
            }
            restoreStickerSlotsIfUnused(for: page.allItems, excludingIDs: Set(page.allItems.map(\.id)))
            modelContext.delete(page)
            save()
        }
    }

    // MARK: - Navigation, feedback

    func goBack() {
        navigator?.popToRoot()
    }

    func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            if self?.toastMessage == message { self?.toastMessage = nil }
        }
    }

    @discardableResult
    private func save() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            isSaveErrorPresented = true
            return false
        }
    }
}

/// Full copy of an item before a cut, for undo.
private struct ItemSnapshot {
    let id: UUID
    let photoID: UUID?
    let stickerID: String?
    let centerX: Double
    let centerY: Double
    let width: Double
    let rotation: Double
    let zIndex: Int
    let loopEnabled: Bool
    let maskData: Data?

    init(_ item: ScrapbookItem) {
        id = item.id
        photoID = item.photoID
        stickerID = item.stickerID
        centerX = item.centerX
        centerY = item.centerY
        width = item.width
        rotation = item.rotation
        zIndex = item.zIndex
        loopEnabled = item.loopEnabled
        maskData = item.maskData
    }

    func restore(into item: ScrapbookItem) {
        item.id = id
        item.photoID = photoID
        item.stickerID = stickerID
        item.centerX = centerX
        item.centerY = centerY
        item.width = width
        item.rotation = rotation
        item.zIndex = zIndex
        item.loopEnabled = loopEnabled
        item.maskData = maskData
    }
}

private struct CutUndoStep {
    let original: ItemSnapshot
    let pageID: UUID
    /// New pieces from one stroke; the original item becomes the first piece.
    let newPieceIDs: [UUID]
}
