import CoreGraphics
import Foundation
import Observation
import SwiftData

/// Editor tools (change 013). `arrange` = move / resize / rotate items.
enum ScrapbookTool: Equatable {
    case arrange
    case scissors
    case pencil
    case stickers
}

/// Scrapbook editor (change 013, behavior ported from the camera POC). Edit mode only for now;
/// the view mode comes with the design team's flow. Pages, items and drawings stay on this device.
@Observable
final class ScrapbookViewModel {
    static let pageFullMessage = "This page is full"
    static let maxUndoSteps = 20

    private let modelContext: ModelContext
    @ObservationIgnored private weak var navigator: (any Navigator)?
    private let sessionStore: SessionStore
    private let scrapbookID: UUID
    private let playback: LivePlaybackCoordinator
    private let imageLoader: ScrapbookImageLoader

    private(set) var scrapbook: Scrapbook?
    var currentPageID: UUID?
    var selectedItemID: UUID?
    private(set) var tool: ScrapbookTool = .arrange
    var isPhotoPickerPresented = false
    var isBackgroundPickerPresented = false
    var isDeletePageConfirmationPresented = false
    var isStickerPanelCollapsed = false
    var isSaveErrorPresented = false
    private(set) var toastMessage: String?
    /// Editor on screen; Live Photos only play while it is.
    var isVisible = false
    private var cutHistory: [CutUndoStep] = []

    init(
        modelContext: ModelContext,
        navigator: (any Navigator)? = nil,
        sessionStore: SessionStore,
        scrapbookID: UUID,
        playback: LivePlaybackCoordinator = .shared,
        imageLoader: ScrapbookImageLoader = .shared
    ) {
        self.modelContext = modelContext
        self.navigator = navigator
        self.sessionStore = sessionStore
        self.scrapbookID = scrapbookID
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
        selectedItemID = nil
        currentPageID = pages[index].id
    }

    func goToPreviousPage() { selectPage(at: currentIndex - 1) }
    func goToNextPage() { selectPage(at: currentIndex + 1) }

    func addPage() {
        guard let scrapbook else { return }
        let page = ScrapbookPage(order: (pages.last?.order ?? -1) + 1, background: currentPage?.pageBackground ?? .cream)
        modelContext.insert(page)
        page.scrapbook = scrapbook
        save()
        selectedItemID = nil
        currentPageID = page.id
    }

    func movePage(by offset: Int) {
        let target = currentIndex + offset
        guard let page = currentPage, pages.indices.contains(target) else { return }
        let other = pages[target]
        (page.order, other.order) = (other.order, page.order)
        save()
    }

    func deleteCurrentPage() {
        guard canDeletePage, let page = currentPage else { return }
        let remaining = pages.filter { $0.id != page.id }
        let neighbor = remaining[max(currentIndex - 1, 0)]
        for (index, remainingPage) in remaining.enumerated() {
            remainingPage.order = index
        }
        cutHistory.removeAll { $0.pageID == page.id }
        selectedItemID = nil
        currentPageID = neighbor.id
        modelContext.delete(page)
        save()
    }

    var currentBackground: PageBackground { currentPage?.pageBackground ?? .cream }

    func setBackground(_ background: PageBackground) {
        currentPage?.background = background.rawValue
        save()
    }

    // MARK: - Photos

    /// Only this roll's photos (own and friends'), oldest first.
    var rollPhotos: [ScrapPhoto] {
        (scrapbook?.photos ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    var photosByID: [UUID: ScrapPhoto] {
        Dictionary((scrapbook?.photos ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func presentPhotoPicker() {
        guard !isCurrentPageFull else {
            showToast(Self.pageFullMessage)
            return
        }
        isPhotoPickerPresented = true
    }

    /// Placed slightly scattered and overlapping, as if glued by hand (POC). Ignores ids not in this roll.
    func addPhotos(_ ids: [UUID], reduceMotion: Bool = false) {
        guard let page = currentPage else { return }
        let known = photosByID
        let ids = Array(ids.filter { known[$0] != nil }.prefix(remainingSlots))
        guard !ids.isEmpty else { return }
        var zIndex = page.maxZIndex
        let spread = Double(ids.count - 1) * 0.02
        for (index, id) in ids.enumerated() {
            zIndex += 1
            let step = Double(index) * 0.04 - spread
            let item = ScrapbookItem(
                photoID: id,
                centerX: min(max(0.5 + step + .random(in: -0.08...0.08), 0.1), 0.9),
                centerY: min(max(0.5 + step + .random(in: -0.08...0.08), 0.1), 0.9),
                width: 0.45,
                rotation: .random(in: -6...6) * .pi / 180,
                zIndex: zIndex,
                loopEnabled: !reduceMotion
            )
            modelContext.insert(item)
            item.page = page
        }
        save()
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

    /// End of a drag / pinch / rotate in arrange mode. `translation` in page points.
    func commitTransform(itemID: UUID, translation: CGSize, scale: CGFloat, rotationDelta: Double, pageSize: CGSize) {
        guard let item = item(itemID), pageSize.width > 0, pageSize.height > 0 else { return }
        item.centerX = min(max(item.centerX + translation.width / pageSize.width, 0), 1)
        item.centerY = min(max(item.centerY + translation.height / pageSize.height, 0), 1)
        item.width = min(max(item.width * scale, ScrapbookItem.minWidth), ScrapbookItem.maxWidth)
        item.rotation = ScrapbookItemLayout.snappedRotation(item.rotation + rotationDelta)
        save()
    }

    /// Live position / size while the scissors move an item (long-press or two fingers).
    func setItemFrame(itemID: UUID, centerX: Double, centerY: Double, width: Double, rotation: Double) {
        guard let item = item(itemID) else { return }
        item.centerX = centerX
        item.centerY = centerY
        item.width = min(max(width, ScrapbookItem.minWidth), ScrapbookItem.maxWidth)
        item.rotation = rotation
    }

    func finishItemManipulation(itemID: UUID) {
        guard let item = item(itemID) else { return }
        item.centerX = min(max(item.centerX, 0), 1)
        item.centerY = min(max(item.centerY, 0), 1)
        item.rotation = ScrapbookItemLayout.snappedRotation(item.rotation)
        save()
    }

    func bringToFront(_ itemID: UUID) {
        guard let page = currentPage, let item = item(itemID) else { return }
        item.zIndex = page.maxZIndex + 1
        save()
    }

    func sendToBack(_ itemID: UUID) {
        guard let page = currentPage, let item = item(itemID) else { return }
        item.zIndex = page.minZIndex - 1
        save()
    }

    func toggleMotion(_ itemID: UUID) {
        guard let item = item(itemID) else { return }
        item.loopEnabled.toggle()
        save()
    }

    func removeItem(_ itemID: UUID) {
        guard let item = item(itemID) else { return }
        if selectedItemID == itemID { selectedItemID = nil }
        modelContext.delete(item)
        save()
    }

    // MARK: - Tools

    func selectTool(_ newTool: ScrapbookTool) {
        selectedItemID = nil
        if newTool == .stickers {
            isStickerPanelCollapsed = false
            _ = currentStickerSheet
            save()
        }
        tool = newTool
    }

    func finishTool() {
        tool = .arrange
        selectedItemID = nil
    }

    // MARK: - Stickers

    let stickerSet = StickerCatalog.travel

    /// The newest sheet for the set; a full new one is created when there is none.
    var currentStickerSheet: StickerSheet? {
        guard let scrapbook else { return nil }
        let sheets = (scrapbook.stickerSheets ?? []).filter { $0.setID == stickerSet.id }
        if let sheet = sheets.max(by: { $0.createdAt < $1.createdAt }) {
            return sheet
        }
        let sheet = StickerSheet(setID: stickerSet.id)
        modelContext.insert(sheet)
        sheet.scrapbook = scrapbook
        return sheet
    }

    func takeNewStickerSheet() {
        currentStickerSheet?.usedStickerIDs = []
        save()
    }

    /// A sticker dropped on the page. `center` and `width` in the same space as `pageFrame`.
    /// Returns `false` when it must go back to the sheet.
    func placeSticker(_ sticker: StickerDefinition, center: CGPoint, width: CGFloat, rotation: Double, pageFrame: CGRect) -> Bool {
        guard let page = currentPage, let sheet = currentStickerSheet, pageFrame.width > 0, pageFrame.height > 0 else {
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
        return save()
    }

    // MARK: - Scissors

    var canUndoCut: Bool { !cutHistory.isEmpty }

    /// Topmost item whose shape contains the page point. Stickers can't be cut (`photosOnly`).
    func itemID(at point: CGPoint, pageSize: CGSize, photosOnly: Bool) -> UUID? {
        guard let page = currentPage else { return nil }
        return page.sortedItems.reversed().first { item in
            if photosOnly && item.stickerID != nil { return false }
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

        for item in page.sortedItems.reversed() where item.stickerID == nil {
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
            return true
        }
        return false
    }

    /// Undoes the last cut: new pieces are removed, the original comes back exactly as before.
    func undoLastCut() {
        guard let step = cutHistory.popLast(),
              let page = pages.first(where: { $0.id == step.pageID }) else { return }
        for piece in page.allItems where step.newPieceIDs.contains(piece.id) {
            if selectedItemID == piece.id { selectedItemID = nil }
            modelContext.delete(piece)
        }
        if let original = page.allItems.first(where: { $0.id == step.original.id }) {
            step.original.restore(into: original)
        } else {
            let restored = ScrapbookItem(centerX: 0, centerY: 0, width: 0, rotation: 0, zIndex: 0)
            step.original.restore(into: restored)
            modelContext.insert(restored)
            restored.page = page
        }
        save()
    }

    // MARK: - Pencil

    func drawingData(for page: ScrapbookPage) -> Data? { page.drawingData }

    func updateDrawing(_ data: Data?, pageID: UUID) {
        guard let page = pages.first(where: { $0.id == pageID }), page.drawingData != data else { return }
        page.drawingData = data
        save()
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
