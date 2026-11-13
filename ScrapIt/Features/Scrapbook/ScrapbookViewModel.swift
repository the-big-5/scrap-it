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

/// Book view on the desk, or the spread zoomed in for decorating (change 025).
enum ScrapbookEditorMode: Equatable {
    case book
    case edit
    /// The closed book after Done (change 026).
    case cover
    /// Decorating the front cover or the spine (change 026).
    case editCover
}

/// The side of the cover being decorated (change 026).
enum CoverSide: Equatable {
    case front, spine

    var role: ScrapbookPage.Role {
        switch self {
        case .front: .front
        case .spine: .spine
        }
    }
}

/// The paper cards over the cover screen (change 026).
enum FinishCard: Equatable {
    /// Host, someone still In Progress: "Ready to close the scrapbook?"
    case confirmSave
    /// Host after saving: "Scrapbook Complete!"
    case complete
    /// Participant after Done Editing: "Nice Work!"
    case niceWork
}

/// One person in the Editing Progress sheet (change 026).
struct EditingProgressRow: Identifiable, Equatable {
    let id: String
    let name: String
    let colorHex: String
    let avatarData: Data?
    let isMe: Bool
}

/// Edit view zoom: both pages, or one page filling the screen (change 025).
enum SpreadZoom: Equatable {
    case spread, left, right

    var next: SpreadZoom {
        switch self {
        case .spread: .left
        case .left: .right
        case .right: .spread
        }
    }
}

/// One person in the Who's here sheet (change 025).
struct WhosHereRow: Identifiable, Equatable {
    let id: String
    let name: String
    let colorHex: String
    let avatarData: Data?
    /// 1-based.
    let pageNumber: Int
    let isMe: Bool
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
    static let maxUndoSteps = 50
    static let pageHintShownKey = "scrapbookPageHintShown"
    /// Text on the spine: font size relative to the spine's width (about 20 pt on the 74 pt Figma spine).
    static let spineTextSize: Double = 0.27
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
    /// The active page: new items go here (change 025: the zoomed page, or the page last touched on the spread).
    var currentPageID: UUID?
    var selectedItemID: UUID?
    var isSaveErrorPresented = false
    // Book view and spreads (change 025)
    private(set) var mode: ScrapbookEditorMode = .book {
        didSet { updateHostDoneStatus() }
    }
    private(set) var spreadIndex = 0
    private(set) var zoom: SpreadZoom = .spread
    /// "More pages to fill!" under the book, once per user.
    private(set) var showsPageHint: Bool
    /// "Welcome to your scrapbook!" on the book (change 125): once per scrapbook on this phone.
    private(set) var showsWelcome = false
    var isBackConfirmationPresented = false
    /// "Done editing your pages?" after ✓ in the book view (change 125, Figma 1708:45425).
    var isDoneConfirmationPresented = false
    var isWhosHerePresented = false
    // Cover and finishing (change 026)
    private(set) var coverSide: CoverSide = .front
    private(set) var finishCard: FinishCard?
    var isEditingProgressPresented = false
    /// Members' profile photos from the room (change 044 `RollParticipant` avatars), so friends who aren't
    /// online still show their photo (change 026).
    private(set) var memberAvatars: [String: Data] = [:]
    @ObservationIgnored private let roomService: (any RollRoomServicing)?
    @ObservationIgnored private let defaults: UserDefaults
    // Undo / redo for every change in the edit view (change 025)
    private var undoStack: [EditorSnapshot] = []
    /// The cover color picker is open and hasn't recorded its undo step yet (change 121).
    private var isCoverColorUndoPending = false
    private var redoStack: [EditorSnapshot] = []
    @ObservationIgnored private var manipulationSnapshot: EditorSnapshot?
    // Tool tray (change 022)
    private(set) var isTrayOpen = false
    /// The tool whose second tray is open.
    private(set) var activeTool: ScrapbookTool?
    private(set) var isCutting = false
    private(set) var washiStyleID: String?
    private(set) var stickerSetID = StickerCatalog.travel.id
    private(set) var isStickerSheetOpen = false
    /// The drawing layer being drawn on each page that takes touches while Pencil is on (page id → layer id;
    /// change 025: both pages of the spread).
    private(set) var drawingLayerIDs: [UUID: UUID] = [:]
    var textEditor: TextEditorState?
    private(set) var viewerPhotoID: UUID?
    /// The tool whose one-time hint is showing.
    private(set) var hintTool: ScrapbookTool?
    @ObservationIgnored private var lastLetter: (id: UUID, time: Date)?
    @ObservationIgnored private var drawingSaveTask: Task<Void, Never>?
    /// Layers with strokes not sent to friends yet.
    @ObservationIgnored private var pendingDrawingLayerIDs: Set<UUID> = []
    private(set) var remoteDrawingRevision = 0
    private(set) var toastMessage: String?
    /// Editor on screen; Live Photos only play while it is.
    var isVisible = false
    private(set) var activeCollaborators: [CollaboratorPresence] = []
    private var isApplyingRemoteEvent = false
    // Drag-to-trash (change 062)
    private(set) var draggedItemID: UUID?
    private(set) var isTrashTargeted = false
    var trashDropFrame: CGRect = .zero
    /// Each page's frame on screen (global), for the trash drop target (change 025: two pages on the spread).
    var pageGlobalFrames: [UUID: CGRect] = [:]
    private(set) var trashedItemCount = 0

    init(
        modelContext: ModelContext,
        navigator: (any Navigator)? = nil,
        sessionStore: SessionStore,
        scrapbookID: UUID,
        currentUser: UserProfile? = nil,
        realtimeService: (any ScrapbookRealtimeProviding)? = nil,
        playback: LivePlaybackCoordinator = .shared,
        imageLoader: ScrapbookImageLoader = .shared,
        defaults: UserDefaults = .standard,
        roomService: (any RollRoomServicing)? = nil
    ) {
        self.roomService = roomService
        self.defaults = defaults
        let showsHint = !defaults.bool(forKey: Self.pageHintShownKey)
        showsPageHint = showsHint
        if showsHint {
            // Once per user: it counts as shown as soon as a book view opens with it.
            defaults.set(true, forKey: Self.pageHintShownKey)
        }
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

    /// Fetches the scrapbook and makes sure its pages fill whole spreads: a new scrapbook gets one spread (two pages),
    /// an odd page count gets one more empty page (change 025).
    func load() {
        let id = scrapbookID
        scrapbook = (try? modelContext.fetch(FetchDescriptor<Scrapbook>(predicate: #Predicate { $0.id == id })))?.first
        guard scrapbook != nil else { return }
        while pages.count < 2 || !pages.count.isMultiple(of: 2) {
            appendPage()
        }
        if migratePageDrawings() {
            save()
        }
        spreadIndex = min(spreadIndex, max(spreadCount - 1, 0))
        if currentPageID == nil || !currentSpreadPages.contains(where: { $0.id == currentPageID }) {
            currentPageID = currentSpreadPages.first?.id
        }
        // Done with the pages, finished, or locked: it opens on the closed book (change 026).
        if mode == .book, hasFinishedPages || isReadOnly {
            mode = .cover
        }
        showWelcomeIfNeeded()
    }

    private var welcomeShownKey: String { "scrapbookWelcomeShown-\(scrapbookID.uuidString)" }

    private func showWelcomeIfNeeded() {
        guard mode == .book, isBookEditable, !defaults.bool(forKey: welcomeShownKey) else { return }
        showsWelcome = true
    }

    /// A tap anywhere dismisses the welcome card, for good on this phone.
    func dismissWelcome() {
        showsWelcome = false
        defaults.set(true, forKey: welcomeShownKey)
    }

    var title: String { scrapbook?.title ?? "" }

    // MARK: - Pages

    var pages: [ScrapbookPage] { scrapbook?.sortedPages ?? [] }

    /// The book's pages plus the cover sides (front, spine), for lookups by page ID (change 026).
    private var pagesAndCover: [ScrapbookPage] { scrapbook?.pages ?? [] }

    /// The active page, or the cover side being decorated (change 026).
    var currentPage: ScrapbookPage? {
        (scrapbook?.pages ?? []).first { $0.id == currentPageID } ?? pages.first
    }

    var currentIndex: Int {
        pages.firstIndex { $0.id == currentPage?.id } ?? 0
    }

    var isCurrentPageFull: Bool { (currentPage?.allItems.count ?? 0) >= ScrapbookPage.maxItems }
    var remainingSlots: Int { ScrapbookPage.maxItems - (currentPage?.allItems.count ?? 0) }

    /// Index sent to friends: the page's place in the book, or -1 / -2 for the front cover / spine (change 026).
    private func pageIndex(of page: ScrapbookPage?) -> Int {
        switch page?.role.flatMap(ScrapbookPage.Role.init(rawValue:)) {
        case .front: Self.frontCoverEventIndex
        case .spine: Self.spineEventIndex
        case nil: pages.firstIndex { $0.id == page?.id } ?? currentIndex
        }
    }

    static let frontCoverEventIndex = -1
    static let spineEventIndex = -2

    /// The page a friend's event is about: a page of the book, or the front cover / spine.
    private func page(atEventIndex index: Int) -> ScrapbookPage? {
        switch index {
        case Self.frontCoverEventIndex: coverPage(.front)
        case Self.spineEventIndex: coverPage(.spine)
        default: pages.indices.contains(index) ? pages[index] : nil
        }
    }

    /// Adds an empty page at the end (same background as the last page) and tells friends.
    private func appendPage() {
        guard let scrapbook else { return }
        let newOrder = (pages.last?.order ?? -1) + 1
        let page = ScrapbookPage(order: newOrder, background: pages.last?.pageBackground ?? .cream)
        modelContext.insert(page)
        page.scrapbook = scrapbook
        save()
        broadcast(ScrapbookEvent(type: .pageAdded, pageIndex: newOrder, senderID: senderID, background: page.background))
    }

    // MARK: - Book and spreads (change 025)

    /// Pages two at a time: 1–2, 3–4, …
    var spreads: [[ScrapbookPage]] {
        let pages = pages
        return stride(from: 0, to: pages.count, by: 2).map { Array(pages[$0..<min($0 + 2, pages.count)]) }
    }

    var spreadCount: Int { (pages.count + 1) / 2 }

    var currentSpreadPages: [ScrapbookPage] {
        let spreads = spreads
        return spreads.indices.contains(spreadIndex) ? spreads[spreadIndex] : []
    }

    var leftPage: ScrapbookPage? { currentSpreadPages.first }
    var rightPage: ScrapbookPage? { currentSpreadPages.count > 1 ? currentSpreadPages[1] : nil }

    /// Swipe on the book: next / previous spread. Past the last spread comes the Add page spread: blank, not saved,
    /// until "+ Add page" adds its two pages (change 121). A finished book has none (change 026).
    func swipeSpread(by delta: Int) {
        dismissPageHint()
        let target = spreadIndex + delta
        let lastIndex = isBookEditable ? spreadCount : spreadCount - 1
        guard target >= 0, target <= lastIndex else { return }
        spreadIndex = target
        selectedItemID = nil
        lastLetter = nil
        currentPageID = leftPage?.id
        updatePresence()
    }

    /// The blank spread past the last one, offering "+ Add page" (change 121).
    var isAtAddPageSpread: Bool { isBookEditable && spreadIndex >= spreadCount }

    /// "+ Add page": two empty pages where the Add page spread was; they're the spread on screen now.
    func addPages() {
        guard isAtAddPageSpread else { return }
        appendPage()
        appendPage()
        currentPageID = leftPage?.id
        updatePresence()
    }

    func dismissPageHint() {
        guard showsPageHint else { return }
        showsPageHint = false
        defaults.set(true, forKey: Self.pageHintShownKey)
    }

    /// The pages can still change: not done with them, and not locked (change 026).
    var isBookEditable: Bool { !hasFinishedPages && !isReadOnly }

    /// Reading a finished book's pages zoomed in: the two-page view without tools (change 125).
    var isReadingPages: Bool { mode == .edit && !isBookEditable }

    /// Tapping the book zooms into the edit view for the spread on screen, showing both pages; a finished book
    /// opens it read only (change 125).
    func openSpread() {
        // The Add page spread has no pages to edit yet (change 121).
        guard isBookEditable || isReadOnly || hasFinishedPages, !isAtAddPageSpread else { return }
        dismissPageHint()
        zoom = .spread
        currentPageID = leftPage?.id
        selectedItemID = nil
        clearHistory()
        mode = .edit
        if isBookEditable { updatePresence() }
    }

    /// X in the edit view: back to the book view on the same spread.
    func closeSpread() {
        cancelItemDrag()
        if textEditor != nil { commitTextEditor() }
        closeTray()
        selectedItemID = nil
        zoom = .spread
        clearHistory()
        mode = .book
    }

    /// Spread → left page → right page → spread.
    func cycleZoom() {
        // Pencil follows the pages on screen.
        let wasDrawing = isDrawing
        endDrawing()
        zoom = zoom.next
        selectedItemID = nil
        defer { if wasDrawing { beginDrawing() } }
        switch zoom {
        case .spread: break
        case .left: activatePage(leftPage?.id)
        case .right: activatePage((rightPage ?? leftPage)?.id)
        }
    }

    /// Only the spread turns to landscape (change 025).
    var allowsLandscape: Bool { mode == .edit && zoom == .spread }

    /// Ensures iPad landscape edit view always displays and enables touches on both pages.
    func ensureSpreadForLandscape() {
        guard mode == .edit, zoom != .spread else { return }
        let wasDrawing = isDrawing
        endDrawing()
        zoom = .spread
        selectedItemID = nil
        if wasDrawing { beginDrawing() }
    }

    /// Pages that take touches in the edit view: the zoomed page, or both pages of the spread.
    var editablePages: [ScrapbookPage] {
        if mode == .editCover {
            return coverPage(coverSide.role).map { [$0] } ?? []
        }
        switch zoom {
        case .spread: return currentSpreadPages
        case .left: return leftPage.map { [$0] } ?? []
        case .right: return (rightPage ?? leftPage).map { [$0] } ?? []
        }
    }

    /// A touch on a page of the spread makes it the active page (where tapped-in items go).
    func activatePage(_ id: UUID?) {
        guard let id, id != currentPageID, currentSpreadPages.contains(where: { $0.id == id }) else { return }
        lastLetter = nil
        currentPageID = id
        updatePresence()
    }

    /// Back in the book view asks first; Yes leaves the scrapbook.
    func requestBack() {
        dismissPageHint()
        isBackConfirmationPresented = true
    }

    /// "Go to Home": the Craft tab, also when the scrapbook was opened from another tab (change 121).
    func confirmBack() {
        isBackConfirmationPresented = false
        backToHome()
    }

    // MARK: - Cover and finishing (change 026)

    /// The roll's host saves the scrapbook; participants mark themselves done.
    var isHost: Bool {
        guard let sessionID = scrapbook?.sourceSessionID,
              let session = (try? modelContext.fetch(FetchDescriptor<CaptureSession>(predicate: #Predicate { $0.id == sessionID })))?.first
        else { return true }
        return session.hostUserID == senderID
    }

    var hasFinishedPages: Bool { scrapbook?.hasFinishedPages ?? false }
    var isLocked: Bool { scrapbook?.isLocked ?? false }
    var isDoneEditing: Bool { scrapbook?.doneEditingMemberIDs.contains(senderID) ?? false }

    /// Locked by the host, or a participant who tapped Done Editing: nothing can be changed any more.
    var isReadOnly: Bool { isLocked || (!isHost && isDoneEditing) }

    /// The buttons under the closed book.
    enum CoverActions: Equatable {
        /// Edit Cover + Save Scrapbook
        case host
        /// Edit Cover + Done Editing
        case participant
        /// Back to Home
        case finished
    }

    var coverActions: CoverActions {
        if isReadOnly { return .finished }
        return isHost ? .host : .participant
    }

    /// Pencil, Stickers, Washi, Letters, Text on the front; Pencil, Stickers, Text on the spine; all on the pages.
    var availableTools: [ScrapbookTool] {
        guard mode == .editCover else { return ScrapbookTool.allCases }
        switch coverSide {
        case .front: return [.pencil, .sticker, .washi, .letters, .text]
        case .spine: return [.pencil, .sticker, .text]
        }
    }

    var coverColorHex: String { scrapbook?.displayedCoverColorHex ?? Scrapbook.defaultCoverColorHex }

    func coverPage(_ role: ScrapbookPage.Role) -> ScrapbookPage? {
        scrapbook?.coverPage(role)
    }

    /// The front cover or spine, created the first time (here or by a friend's event).
    @discardableResult
    private func ensureCoverPage(_ role: ScrapbookPage.Role) -> ScrapbookPage? {
        if let page = coverPage(role) { return page }
        guard let scrapbook else { return nil }
        let page = ScrapbookPage(order: 0)
        page.role = role.rawValue
        modelContext.insert(page)
        page.scrapbook = scrapbook
        save()
        return page
    }

    /// ✓ in the book view (change 125): the book closes on the cover screen, the confirmation step. Nothing is
    /// finished yet: Done Editing (participant) or Save Scrapbook (host) finish; ‹ goes back to editing.
    func finishScrapbook() {
        guard let scrapbook, !isReadOnly else { return }
        closeTray()
        selectedItemID = nil
        scrapbook.hasFinishedPages = true
        save()
        mode = .cover
    }

    /// ✓ in the book view asks first (change 125, Figma 1708:45425).
    func requestFinish() {
        guard !isReadOnly else { return }
        dismissPageHint()
        isDoneConfirmationPresented = true
    }

    /// "Edit Cover" on that card: the pages wait on the cover screen, and Edit Cover opens to finish the cover.
    func confirmFinish() {
        isDoneConfirmationPresented = false
        finishScrapbook()
        editCover()
    }

    /// ‹ on the cover screen (change 125): back to the book, editing again.
    func backToEditing() {
        guard let scrapbook, !isReadOnly else { return }
        scrapbook.hasFinishedPages = false
        save()
        mode = .book
    }

    /// Edit Cover: the front, with the tray already open.
    func editCover() {
        guard !isReadOnly, ensureCoverPage(.front) != nil, ensureCoverPage(.spine) != nil else { return }
        showCoverSide(.front)
        // Undo / redo in Edit Cover start empty (change 121).
        clearHistory()
        mode = .editCover
    }

    /// "Edit book spine →" in Edit Cover: on to the spine.
    func showSpine() {
        showCoverSide(.spine)
    }

    /// ‹ on the spine: back to the front cover, edits kept (change 121).
    func showFront() {
        showCoverSide(.front)
    }

    private func showCoverSide(_ side: CoverSide) {
        closeTray()
        selectedItemID = nil
        coverSide = side
        currentPageID = coverPage(side.role)?.id
        isTrayOpen = true
    }

    /// ✓ in Edit Cover (front or spine): back to the cover screen.
    func finishCoverEdit() {
        cancelItemDrag()
        if textEditor != nil { commitTextEditor() }
        closeTray()
        selectedItemID = nil
        coverSide = .front
        mode = .cover
    }

    /// The color picker opened: its first change is one undo step (change 121).
    func coverColorPickerOpened() {
        isCoverColorUndoPending = true
    }

    /// The color picker under the cover; the texture stays visible over any color.
    func setCoverColor(_ hex: String) {
        guard let scrapbook, !isReadOnly, !(scrapbook.coverColorPicked && scrapbook.coverColorHex == hex) else { return }
        // One undo step per opening of the color picker (it reports every change while dragging), change 121.
        if isCoverColorUndoPending {
            recordUndo()
            isCoverColorUndoPending = false
        }
        scrapbook.coverColorHex = hex
        scrapbook.coverColorPicked = true
        if save() {
            broadcast(ScrapbookEvent(type: .coverColor, pageIndex: Self.frontCoverEventIndex, senderID: senderID,
                                     coverColor: hex))
        }
    }

    /// Participant: Done Editing → "Nice Work!"; read-only from now on.
    func doneEditing() {
        guard !isHost, !isReadOnly else { return }
        markDoneEditing()
        finishCard = .niceWork
    }

    /// Host: Save Scrapbook asks first only while someone is still In Progress.
    func requestSave() {
        guard isHost, !isLocked else { return }
        // Asks only while someone else is still editing: the host is In Progress until Save (change 125).
        if editingInProgress.allSatisfy(\.isMe) {
            saveScrapbook()
        } else {
            finishCard = .confirmSave
        }
    }

    /// Locks the scrapbook for everyone, then "Scrapbook Complete!".
    func saveScrapbook() {
        guard let scrapbook, isHost, !isLocked else { return }
        if !isDoneEditing { markDoneEditing() }
        scrapbook.isLocked = true
        scrapbook.lockedAt = .now
        save()
        broadcast(ScrapbookEvent(type: .scrapbookLocked, pageIndex: 0, senderID: senderID))
        let room = roomLocation
        if let roomService, let room {
            Task { try? await roomService.lockScrapbook(inRoom: room.code, zoneOwnerName: room.owner) }
        }
        finishCard = .complete
    }

    func dismissFinishCard() {
        finishCard = nil
    }

    /// "View Bookshelf": the Profile tab.
    func viewBookshelf() {
        finishCard = nil
        navigator?.popToRoot()
        navigator?.selectedTab = .profile
    }

    /// "Back to Home": the Home tab.
    func backToHome() {
        navigator?.popToRoot()
        navigator?.selectedTab = .home
    }

    /// A finished or locked scrapbook can still be read: the book opens without any tools.
    func openReadOnlyBook() {
        guard isReadOnly || hasFinishedPages else { return }
        mode = .book
    }

    /// Back from the read-only book: the closed book again.
    func closeReadOnlyBook() {
        mode = .cover
    }

    /// The host is done while on the cover screen (with Edit Cover and Save Scrapbook) and In Progress while on the
    /// pages or in Edit Cover, until Save Scrapbook (change 125).
    private func updateHostDoneStatus() {
        guard isHost, !isLocked, let scrapbook else { return }
        let isDone = scrapbook.doneEditingMemberIDs.contains(senderID)
        if mode == .cover, !isDone {
            markDoneEditing()
        } else if mode != .cover, isDone {
            resumeEditingStatus()
        }
    }

    private func resumeEditingStatus() {
        guard let scrapbook else { return }
        scrapbook.doneEditingMemberIDs.removeAll { $0 == senderID }
        save()
        broadcast(ScrapbookEvent(type: .editingResumed, pageIndex: 0, senderID: senderID, memberID: senderID))
        if let roomService, let room = roomLocation {
            let userID = senderID
            Task { try? await roomService.resumeEditing(userID: userID, inRoom: room.code, zoneOwnerName: room.owner) }
        }
    }

    private var hostUserID: String? {
        guard let sessionID = scrapbook?.sourceSessionID else { return nil }
        return (try? modelContext.fetch(FetchDescriptor<CaptureSession>(predicate: #Predicate { $0.id == sessionID })))?
            .first?.hostUserID
    }

    private func markDoneEditing() {
        guard let scrapbook else { return }
        if !scrapbook.doneEditingMemberIDs.contains(senderID) {
            scrapbook.doneEditingMemberIDs.append(senderID)
            save()
        }
        broadcast(ScrapbookEvent(type: .editingDone, pageIndex: 0, senderID: senderID, memberID: senderID))
        let room = roomLocation
        if let roomService, let room {
            let userID = senderID
            Task { try? await roomService.markDoneEditing(userID: userID, inRoom: room.code, zoneOwnerName: room.owner) }
        }
    }

    private var roomLocation: (code: String, owner: String?)? {
        guard let sessionID = scrapbook?.sourceSessionID,
              let session = (try? modelContext.fetch(FetchDescriptor<CaptureSession>(predicate: #Predicate { $0.id == sessionID })))?.first,
              !session.rollCode.isEmpty else { return nil }
        return (session.rollCode, session.ckZoneOwnerName)
    }

    /// Reads who is done and whether it's locked from the room, so offline friends count too.
    func refreshFinishStatus() async {
        guard let roomService, let room = roomLocation,
              let snapshot = try? await roomService.fetchRoom(code: room.code, zoneOwnerName: room.owner) else { return }
        for participant in snapshot.participants {
            if let avatar = participant.avatarData { memberAvatars[participant.userID] = avatar }
        }
        applyFinishStatus(doneIDs: snapshot.doneEditingUserIDs, locked: snapshot.scrapbookLocked)
        // The host's status goes both ways (change 125): on friends' phones it follows the room.
        if !isHost, let scrapbook, let hostID = hostUserID, !snapshot.scrapbookLocked,
           !snapshot.doneEditingUserIDs.contains(hostID), scrapbook.doneEditingMemberIDs.contains(hostID) {
            scrapbook.doneEditingMemberIDs.removeAll { $0 == hostID }
            save()
        }
    }

    private func applyFinishStatus(doneIDs: [String], locked: Bool) {
        guard let scrapbook else { return }
        let merged = Array(Set(scrapbook.doneEditingMemberIDs).union(doneIDs)).sorted()
        if merged != scrapbook.doneEditingMemberIDs.sorted() {
            scrapbook.doneEditingMemberIDs = merged
        }
        if locked && !scrapbook.isLocked {
            lockFromFriend()
        }
        save()
    }

    /// The host saved while this phone was editing: everything turns read-only on the closed book.
    private func lockFromFriend() {
        guard let scrapbook else { return }
        scrapbook.isLocked = true
        scrapbook.lockedAt = scrapbook.lockedAt ?? .now
        cancelItemDrag()
        textEditor = nil
        closeTray()
        selectedItemID = nil
        if mode == .edit || mode == .editCover || mode == .book {
            mode = .cover
        }
    }

    /// A member's profile photo: mine from my profile (the same as the Profile tab), a friend's from their live
    /// presence or else from the room.
    private func avatar(for memberID: String) -> Data? {
        if memberID == senderID { return currentUser?.avatarData }
        return activeCollaborators.first { $0.id == memberID }?.avatarData ?? memberAvatars[memberID]
    }

    /// Everyone in the roll (members of the scrapbook), with the host and me included.
    private var memberRows: [EditingProgressRow] {
        guard let scrapbook else { return [] }
        var rows: [EditingProgressRow] = []
        for (index, id) in scrapbook.memberIDs.enumerated() where !rows.contains(where: { $0.id == id }) {
            let name = scrapbook.memberNames.indices.contains(index) ? scrapbook.memberNames[index] : "Friend"
            rows.append(EditingProgressRow(id: id, name: id == senderID ? userName : name,
                                           colorHex: Self.presenceColorHex(for: id), avatarData: avatar(for: id),
                                           isMe: id == senderID))
        }
        if !rows.contains(where: { $0.isMe }) {
            rows.append(EditingProgressRow(id: senderID, name: userName, colorHex: userColorHex,
                                           avatarData: avatar(for: senderID), isMe: true))
        }
        return rows.sorted { $0.isMe && !$1.isMe }
    }

    var editingDone: [EditingProgressRow] {
        let done = Set(scrapbook?.doneEditingMemberIDs ?? [])
        return memberRows.filter { done.contains($0.id) }
    }

    var editingInProgress: [EditingProgressRow] {
        let done = Set(scrapbook?.doneEditingMemberIDs ?? [])
        return memberRows.filter { !done.contains($0.id) }
    }

    // MARK: - Who's here (change 025)

    private var spreadPageNumbers: Set<Int> { [spreadIndex * 2 + 1, spreadIndex * 2 + 2] }

    private var allPresenceRows: [WhosHereRow] {
        let me = WhosHereRow(id: senderID, name: userName, colorHex: userColorHex, avatarData: currentUser?.avatarData,
                             pageNumber: currentIndex + 1, isMe: true)
        let others = activeCollaborators.filter { $0.id != senderID }.map {
            WhosHereRow(id: $0.id, name: $0.name, colorHex: $0.colorHex, avatarData: $0.avatarData ?? memberAvatars[$0.id],
                        pageNumber: $0.currentPageIndex + 1, isMe: false)
        }
        return [me] + others
    }

    /// People on this spread, me first.
    var whosHereOnThisSpread: [WhosHereRow] {
        allPresenceRows.filter { $0.isMe || spreadPageNumbers.contains($0.pageNumber) }
    }

    var whosHereOnOtherPages: [WhosHereRow] {
        allPresenceRows.filter { !$0.isMe && !spreadPageNumbers.contains($0.pageNumber) }
            .sorted { $0.pageNumber < $1.pageNumber }
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
        recordUndo()
        let item = ScrapbookItem(
            photoID: id,
            centerX: point.map { Double($0.x) } ?? min(max(0.5 + .random(in: -0.08...0.08), 0.1), 0.9),
            centerY: point.map { Double($0.y) } ?? min(max(0.5 + .random(in: -0.08...0.08), 0.1), 0.9),
            width: 0.45,
            rotation: .random(in: -6...6) * .pi / 180,
            zIndex: frontZIndex(on: page),
            loopEnabled: !reduceMotion
        )
        modelContext.insert(item)
        item.page = page
        guard save() else { return false }
        broadcast(ScrapbookEvent(type: .itemPlaced, pageIndex: pageIndex(of: currentPage), senderID: senderID, item: item.toPayload()))
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

    /// An item on the pages that take touches (the spread's two pages, or the zoomed page).
    private func item(_ id: UUID) -> ScrapbookItem? {
        for page in editablePages {
            if let item = page.allItems.first(where: { $0.id == id }) { return item }
        }
        return currentPage?.allItems.first { $0.id == id }
    }

    /// Selecting an item brings it to the front and makes its page the active page.
    func selectItem(_ id: UUID?) {
        selectedItemID = id
        guard let id, let item = item(id), let page = item.page else { return }
        activatePage(page.id)
        // In front of both pages of the spread: they share one layer order (change 104).
        let layer = layerPages(of: page).flatMap(\.allItems)
        let top = layer.map(\.zIndex).max() ?? 0
        if item.zIndex < top || layer.filter({ $0.zIndex == item.zIndex }).count > 1 {
            item.zIndex = top + 1
        }
    }

    /// The items of a spread's pages back to front in one layer order (change 104): by layer, the left page's item
    /// first on a tie.
    func layerOrder(of pages: [ScrapbookPage]) -> [SpreadItem] {
        pages.enumerated()
            .flatMap { index, page in page.allItems.map { SpreadItem(pageIndex: index, page: page, item: $0) } }
            .sorted { ($0.item.zIndex, $0.pageIndex) < ($1.item.zIndex, $1.pageIndex) }
    }

    /// The pages sharing one layer order with `page`: both pages of its spread (change 104), or a cover side alone.
    func layerPages(of page: ScrapbookPage) -> [ScrapbookPage] {
        spreads.first { $0.contains { $0.id == page.id } } ?? [page]
    }

    /// In front of everything on the page's spread.
    private func frontZIndex(on page: ScrapbookPage) -> Int {
        (layerPages(of: page).flatMap(\.allItems).map(\.zIndex).max() ?? 0) + 1
    }

    /// Behind everything on the page's spread.
    private func backZIndex(on page: ScrapbookPage) -> Int {
        (layerPages(of: page).flatMap(\.allItems).map(\.zIndex).min() ?? 0) - 1
    }

    /// End of a drag / pinch / rotate. `translation` in page points. On the spread an item dropped past the gutter
    /// moves to the other page (change 025); a zoomed page keeps its items.
    func commitTransform(itemID: UUID, translation: CGSize, scale: CGFloat, rotationDelta: Double, pageSize: CGSize) {
        guard let item = item(itemID), let fromPage = item.page, pageSize.width > 0, pageSize.height > 0 else { return }
        recordUndo()
        var centerX = item.centerX + translation.width / pageSize.width
        var targetPage = fromPage
        if zoom == .spread, let left = leftPage, let right = rightPage {
            if fromPage.id == left.id, centerX > 1, right.allItems.count < ScrapbookPage.maxItems {
                targetPage = right
                centerX -= 1
            } else if fromPage.id == right.id, centerX < 0, left.allItems.count < ScrapbookPage.maxItems {
                targetPage = left
                centerX += 1
            }
        }
        item.centerX = min(max(centerX, 0), 1)
        item.centerY = min(max(item.centerY + translation.height / pageSize.height, 0), 1)
        item.width = min(max(item.width * scale, item.widthRange.lowerBound), item.widthRange.upperBound)
        item.rotation = ScrapbookItemLayout.snappedRotation(item.rotation + rotationDelta)
        if targetPage.id != fromPage.id {
            let fromIndex = pageIndex(of: fromPage)
            item.zIndex = frontZIndex(on: targetPage)
            item.page = targetPage
            currentPageID = targetPage.id
            guard save() else { return }
            // Friends get the move to the other page as a remove plus a place.
            broadcast(ScrapbookEvent(type: .itemRemoved, pageIndex: fromIndex, senderID: senderID, itemID: item.id))
            broadcast(ScrapbookEvent(type: .itemPlaced, pageIndex: pageIndex(of: targetPage), senderID: senderID,
                                     item: item.toPayload()))
            return
        }
        save()
        broadcastItemTransformed(item)
    }

    /// Live position / size while the scissors move an item (long-press or two fingers).
    func setItemFrame(itemID: UUID, centerX: Double, centerY: Double, width: Double, rotation: Double) {
        guard let item = item(itemID) else { return }
        if manipulationSnapshot == nil {
            manipulationSnapshot = snapshot()
        }
        item.centerX = centerX
        item.centerY = centerY
        item.width = min(max(width, item.widthRange.lowerBound), item.widthRange.upperBound)
        item.rotation = rotation
    }

    func finishItemManipulation(itemID: UUID) {
        guard let item = item(itemID) else { return }
        if let before = manipulationSnapshot {
            pushUndo(before)
            manipulationSnapshot = nil
        }
        item.centerX = min(max(item.centerX, 0), 1)
        item.centerY = min(max(item.centerY, 0), 1)
        item.rotation = ScrapbookItemLayout.snappedRotation(item.rotation)
        save()
        broadcastItemTransformed(item)
    }

    func bringToFront(_ itemID: UUID) {
        guard let item = item(itemID), let page = item.page else { return }
        recordUndo()
        item.zIndex = frontZIndex(on: page)
        save()
        broadcastItemTransformed(item)
    }

    func sendToBack(_ itemID: UUID) {
        guard let item = item(itemID), let page = item.page else { return }
        recordUndo()
        item.zIndex = backZIndex(on: page)
        save()
        broadcastItemTransformed(item)
    }

    func toggleMotion(_ itemID: UUID) {
        guard let item = item(itemID) else { return }
        recordUndo()
        item.loopEnabled.toggle()
        save()
        broadcastItemTransformed(item)
    }

    func removeItem(_ itemID: UUID) {
        guard let item = item(itemID) else { return }
        recordUndo()
        let index = pageIndex(of: item.page)
        if selectedItemID == itemID { selectedItemID = nil }
        restoreStickerSlotsIfUnused(for: [item], excludingIDs: [itemID])
        modelContext.delete(item)
        if save() {
            broadcast(ScrapbookEvent(type: .itemRemoved, pageIndex: index, senderID: senderID, itemID: itemID))
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
        let pageFrame = item(itemID)?.page.flatMap { pageGlobalFrames[$0.id] } ?? .zero
        let globalPoint = CGPoint(
            x: pageFrame.minX + pageLocation.x,
            y: pageFrame.minY + pageLocation.y
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
            pageIndex: pageIndex(of: item.page),
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

    func openTray() {
        isTrayOpen = true
    }

    /// Swipe down on the main tray: it folds back and the active tool turns off.
    func closeTray() {
        setActiveTool(nil)
        setCutting(false)
        isTrayOpen = false
    }

    /// Edit Cover: swiping the second tray down puts the tool away; the main tray stays.
    func closeSubTray() {
        setActiveTool(nil)
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

    /// Tap on an empty spot of a page: deselect, close the second tray, and make that page active.
    func tapEmptyPage(_ pageID: UUID? = nil) {
        selectedItemID = nil
        setActiveTool(nil)
        activatePage(pageID)
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

    /// A polaroid or letter dropped from the tray. `point` normalized to the pages on screen: the zoomed page, or
    /// both pages of the spread side by side (the half it lands on picks the page).
    func dropFromTray(_ payload: TrayDropPayload, at point: CGPoint, reduceMotion: Bool = false) -> Bool {
        var point = point
        if mode == .edit, zoom == .spread, let left = leftPage, let right = rightPage {
            let isRight = point.x >= 0.5
            activatePage(isRight ? right.id : left.id)
            point.x = isRight ? (point.x - 0.5) * 2 : point.x * 2
        }
        switch payload {
        case .photo(let id): return addPhoto(id, at: point, reduceMotion: reduceMotion)
        case .letter(let letter): return addLetter(letter, at: point)
        }
    }

    // MARK: - Letters

    /// A cut-out letter. Taps within 3 s line up to the right and wrap at the page edge; a drag drops it at `point`.
    @discardableResult
    func addLetter(_ letter: LetterDefinition, at point: CGPoint? = nil, now: Date = .now) -> Bool {
        guard let page = currentPage, hasRoom() else { return false }
        recordUndo()
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
                                 rotation: .random(in: -8...8) * .pi / 180, zIndex: frontZIndex(on: page))
        item.letterID = letter.id
        modelContext.insert(item)
        item.page = page
        lastLetter = point == nil ? (item.id, now) : nil
        let saved = save()
        if saved {
            broadcast(ScrapbookEvent(type: .itemPlaced, pageIndex: pageIndex(of: currentPage), senderID: senderID, item: item.toPayload()))
        }
        return saved
    }

    // MARK: - Washi

    func selectWashi(_ style: WashiStyle) {
        // A swipe down that starts on a roll also lands as a tap after the tray closed (Edit Cover); with the
        // Washi tool put away, a roll can't be picked.
        guard activeTool == .washi else { return }
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
        recordUndo()
        let item = ScrapbookItem(
            centerX: Double((start.x + end.x) / 2 / pageSize.width),
            centerY: Double((start.y + end.y) / 2 / pageSize.height),
            width: length,
            rotation: Double(atan2(end.y - start.y, end.x - start.x)),
            zIndex: frontZIndex(on: page)
        )
        item.washiID = styleID
        item.washiLength = length
        item.tearSeed = seed
        modelContext.insert(item)
        item.page = page
        let saved = save()
        if saved {
            broadcast(ScrapbookEvent(type: .itemPlaced, pageIndex: pageIndex(of: currentPage), senderID: senderID, item: item.toPayload()))
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
            guard text != item.text || state.color.rawValue != item.textColor else { return }
            recordUndo()
            if text.isEmpty {
                if selectedItemID == id { selectedItemID = nil }
                modelContext.delete(item)
                if save() {
                    broadcast(ScrapbookEvent(type: .itemRemoved, pageIndex: pageIndex(of: currentPage), senderID: senderID, itemID: id))
                }
            } else {
                item.text = text
                item.textColor = state.color.rawValue
                if save() {
                    broadcast(ScrapbookEvent(
                        type: .itemTextUpdated,
                        pageIndex: pageIndex(of: currentPage),
                        senderID: senderID,
                        itemID: item.id,
                        text: text,
                        textColor: item.textColor
                    ))
                }
            }
        } else if !text.isEmpty, hasRoom() {
            recordUndo()
            // On the spine the text stands upright along it (change 026).
            let isSpine = page.role == ScrapbookPage.Role.spine.rawValue
            let item = ScrapbookItem(centerX: 0.5, centerY: isSpine ? 0.5 : 0.4,
                                     width: isSpine ? Self.spineTextSize : TextItemStyle.defaultSize,
                                     rotation: isSpine ? -.pi / 2 : 0, zIndex: frontZIndex(on: page))
            item.text = text
            item.textColor = state.color.rawValue
            modelContext.insert(item)
            item.page = page
            if save() {
                broadcast(ScrapbookEvent(type: .itemPlaced, pageIndex: pageIndex(of: currentPage), senderID: senderID, item: item.toPayload()))
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
                pageIndex: pageIndex(of: currentPage),
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
        recordUndo()
        // On the narrow spine a sheet-sized sticker would already be wider than the spine and couldn't grow; it lands
        // at 60% of the spine's width so it can still be made bigger (change 103).
        let isSpine = page.role == ScrapbookPage.Role.spine.rawValue
        let item = ScrapbookItem(
            stickerID: sticker.id,
            centerX: (center.x - pageFrame.minX) / pageFrame.width,
            centerY: (center.y - pageFrame.minY) / pageFrame.height,
            width: isSpine ? min(width / pageFrame.width, 0.6) : width / pageFrame.width,
            rotation: rotation,
            zIndex: frontZIndex(on: page)
        )
        modelContext.insert(item)
        item.page = page
        sheet.usedStickerIDs.append(sticker.id)
        let saved = save()
        if saved {
            broadcast(ScrapbookEvent(type: .itemPlaced, pageIndex: pageIndex(of: currentPage), senderID: senderID, item: item.toPayload()))
        }
        return saved
    }

    // MARK: - Scissors

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

    /// The topmost item at a point of the two-page view (one pair of scissors over both pages, change 126): both
    /// pages' items in their shared layer order (change 104), front first.
    func itemID(atSpread point: CGPoint, pageSize: CGSize, photosOnly: Bool) -> UUID? {
        layerOrder(of: currentSpreadPages).reversed().first { entry in
            let item = entry.item
            switch item.kind {
            case .photo: break
            case .drawing, .text: return false
            case .sticker, .letter, .washi: if photosOnly { return false }
            }
            let pagePoint = CGPoint(x: point.x - CGFloat(entry.pageIndex) * pageSize.width, y: point.y)
            let box = ScrapbookItemLayout.boxSize(of: item, photoAspect: photoAspect(for: item), pageSize: pageSize)
            let local = ScrapbookItemLayout.normalizedPoint(pagePoint, in: item, box: box, pageSize: pageSize)
            return CutGeometry.contains(item.maskPolygon ?? CutGeometry.unitSquare, local)
        }?.item.id
    }

    /// A point of the two-page view in the item's own page space.
    func pagePoint(fromSpread point: CGPoint, itemID: UUID, pageWidth: CGFloat) -> CGPoint {
        let index = item(itemID)?.page.flatMap { page in currentSpreadPages.firstIndex { $0.id == page.id } } ?? 0
        return CGPoint(x: point.x - CGFloat(index) * pageWidth, y: point.y)
    }

    /// Cuts the topmost photo the stroke crosses on the active page (a zoomed page, the cover). See `cut(candidates:)`.
    @discardableResult
    func cut(along pagePath: [CGPoint], pageSize: CGSize) -> Bool {
        guard let page = currentPage else { return false }
        return cut(candidates: page.sortedItems.reversed().map { (page, $0, pagePath) }, pageSize: pageSize)
    }

    /// The two-page view (change 126): the stroke, in spread space, is matched against both pages' photos front
    /// first, so an item across the gutter can be cut on either side.
    @discardableResult
    func cut(alongSpread spreadPath: [CGPoint], pageSize: CGSize) -> Bool {
        let candidates = layerOrder(of: currentSpreadPages).reversed().map { entry in
            (entry.page, entry.item, spreadPath.map { CGPoint(x: $0.x - CGFloat(entry.pageIndex) * pageSize.width, y: $0.y) })
        }
        return cut(candidates: candidates, pageSize: pageSize)
    }

    /// Cuts the first photo the stroke cuts, front to back. Every crossing of the whole stroke splits, so one stroke
    /// can make more than two pieces; with auto-complete (change 126) a stroke stopping short is continued to the
    /// edge and a rough loop cuts out its inside. Pieces move ±3 pt apart so the cut shows. `true` if something was cut.
    private func cut(candidates: [(page: ScrapbookPage, item: ScrapbookItem, path: [CGPoint])], pageSize: CGSize) -> Bool {
        guard pageSize.width > 0, pageSize.height > 0 else { return false }
        for (page, item, pagePath) in candidates where item.kind == .photo {
            let box = ScrapbookItemLayout.boxSize(of: item, photoAspect: photoAspect(for: item), pageSize: pageSize)
            let path = CutGeometry.simplify(pagePath, tolerance: 1.5)
            let localPath = path.map { ScrapbookItemLayout.normalizedPoint($0, in: item, box: box, pageSize: pageSize) }
            let mask = item.maskPolygon ?? CutGeometry.unitSquare
            let freeSlots = ScrapbookPage.maxItems - page.allItems.count
            guard freeSlots > 0 else {
                // The page is full: only say so when the stroke was on this photo.
                if localPath.contains(where: { CutGeometry.contains(mask, $0) }) {
                    showToast(Self.pageFullMessage)
                    return false
                }
                continue
            }
            guard let pieces = CutGeometry.autoCompletedPieces(mask, by: localPath,
                                                               minimumArea: CutGeometry.minimumPieceArea,
                                                               maxPieces: freeSlots + 1) else { continue }

            let before = snapshot()
            let newPieceIDs = pieces.dropFirst().map { _ in UUID() }
            let originalCenter = CutGeometry.centroid(mask)
            var zIndex = frontZIndex(on: page) - 1
            var pieceItems = [item]
            item.maskPolygon = pieces[0]
            for (polygon, id) in zip(pieces.dropFirst(), newPieceIDs) {
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
            pushUndo(before)
            broadcast(ScrapbookEvent(
                type: .itemCut,
                pageIndex: pageIndex(of: page),
                senderID: senderID,
                itemID: item.id,
                maskData: item.maskData,
                newPieces: pieceItems.dropFirst().map { $0.toPayload() }
            ))
            return true
        }
        return false
    }

    // MARK: - Pencil (drawing layers, change 022)

    var isDrawing: Bool { !drawingLayerIDs.isEmpty }

    /// The layer being drawn on the active page.
    var activeDrawingID: UUID? { currentPageID.flatMap { drawingLayerIDs[$0] } }

    /// On every page that takes touches (both pages of the spread), strokes go into the frontmost item if it's a
    /// drawing layer; otherwise a new layer is created in front, so drawings stack with photos in the order they
    /// were added. `false` when no page has room.
    @discardableResult
    func beginDrawing() -> Bool {
        for page in editablePages {
            if let top = page.sortedItems.last, top.kind == .drawing {
                drawingLayerIDs[page.id] = top.id
            } else if page.allItems.count < ScrapbookPage.maxItems {
                let item = ScrapbookItem(centerX: 0.5, centerY: 0.5, width: 1, rotation: 0, zIndex: frontZIndex(on: page))
                item.drawingData = Data()
                modelContext.insert(item)
                item.page = page
                drawingLayerIDs[page.id] = item.id
                if save() {
                    broadcast(ScrapbookEvent(type: .itemPlaced, pageIndex: pageIndex(of: page), senderID: senderID,
                                             item: item.toPayload()))
                }
            }
        }
        guard isDrawing else {
            showToast(Self.pageFullMessage)
            return false
        }
        showHintOnce(.pencil)
        return true
    }

    private func drawingLayer(onPage pageID: UUID) -> ScrapbookItem? {
        guard let id = drawingLayerIDs[pageID] else { return nil }
        return pagesAndCover.first { $0.id == pageID }?.allItems.first { $0.id == id }
    }

    func drawingData(onPage pageID: UUID) -> Data? {
        drawingLayer(onPage: pageID)?.drawingData
    }

    var activeDrawingData: Data? {
        currentPageID.flatMap(drawingData(onPage:))
    }

    func updateActiveDrawing(_ data: Data?) {
        guard let pageID = currentPageID else { return }
        updateDrawing(data, onPage: pageID)
    }

    /// After each stroke on a page (`nil` = no strokes left). Saved 0.5 s after the last change.
    func updateDrawing(_ data: Data?, onPage pageID: UUID) {
        updateDrawings([pageID: data])
    }

    /// One stroke's changes by page: one undo step, also when a stroke changes both pages of the spread (change 104).
    func updateDrawings(_ changes: [UUID: Data?]) {
        let layers = changes.compactMap { pageID, data in drawingLayer(onPage: pageID).map { (pageID, $0, data) } }
        guard !layers.isEmpty else { return }
        recordUndo()
        for (pageID, item, data) in layers {
            activatePage(pageID)
            item.drawingData = data ?? Data()
            pendingDrawingLayerIDs.insert(item.id)
        }
        drawingSaveTask?.cancel()
        drawingSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            self.flushDrawingBroadcasts()
        }
    }

    private func flushDrawingBroadcasts() {
        let pending = pendingDrawingLayerIDs
        pendingDrawingLayerIDs.removeAll()
        guard save() else { return }
        for item in pagesAndCover.flatMap(\.allItems) where pending.contains(item.id) {
            broadcastDrawingUpdated(item)
        }
    }

    /// Leaving Pencil: saves, and removes layers that have no strokes.
    func endDrawing() {
        guard isDrawing else { return }
        drawingSaveTask?.cancel()
        let layers = drawingLayerIDs
        drawingLayerIDs.removeAll()
        if hintTool == .pencil { hintTool = nil }
        for (pageID, itemID) in layers {
            guard let page = pagesAndCover.first(where: { $0.id == pageID }),
                  let item = page.allItems.first(where: { $0.id == itemID }),
                  item.drawingData?.isEmpty != false else { continue }
            pendingDrawingLayerIDs.remove(itemID)
            modelContext.delete(item)
            if save() {
                broadcast(ScrapbookEvent(type: .itemRemoved, pageIndex: pageIndex(of: page), senderID: senderID, itemID: itemID))
            }
        }
        flushDrawingBroadcasts()
    }

    private func broadcastDrawingUpdated(_ item: ScrapbookItem) {
        broadcast(ScrapbookEvent(
            type: .drawingUpdated,
            pageIndex: pageIndex(of: item.page),
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

    // MARK: - Undo / redo (change 025)

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// The spread's pages and the sticker sheets as they are now.
    /// The pages undo / redo cover: the spread on screen, or both cover sides in Edit Cover (change 121).
    private var undoPages: [ScrapbookPage] {
        guard mode == .editCover else { return currentSpreadPages }
        return [ScrapbookPage.Role.front, .spine].compactMap { coverPage($0) }
    }

    private func snapshot() -> EditorSnapshot {
        EditorSnapshot(
            pages: undoPages.map { page in (page.id, page.allItems.map { ItemState($0) }) },
            coverColor: mode == .editCover ? scrapbook.map { ($0.coverColorHex, $0.coverColorPicked) } : nil,
            stickerUsage: Dictionary((scrapbook?.stickerSheets ?? []).map { ($0.id, $0.usedStickerIDs) },
                                     uniquingKeysWith: { first, _ in first })
        )
    }

    /// Called right before a change on this phone. A new change clears the redo steps.
    private func recordUndo() {
        pushUndo(snapshot())
    }

    private func pushUndo(_ snapshot: EditorSnapshot) {
        undoStack.append(snapshot)
        if undoStack.count > Self.maxUndoSteps { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        manipulationSnapshot = nil
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(snapshot())
        restore(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(snapshot())
        restore(next)
    }

    /// Puts the spread back as it was and tells friends with the existing events (last write wins).
    private func restore(_ target: EditorSnapshot) {
        cancelItemDrag()
        let pagesByID = Dictionary(undoPages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var currentItems: [UUID: ScrapbookItem] = [:]
        for page in pagesByID.values {
            for item in page.allItems { currentItems[item.id] = item }
        }
        var events: [ScrapbookEvent] = []
        var wantedIDs = Set<UUID>()

        for (pageID, states) in target.pages {
            guard let page = pagesByID[pageID] else { continue }
            let index = pageIndex(of: page)
            for state in states {
                wantedIDs.insert(state.id)
                if let item = currentItems[state.id] {
                    let before = ItemState(item)
                    let oldPage = item.page
                    guard before != state || oldPage?.id != pageID else { continue }
                    state.apply(to: item)
                    if oldPage?.id != pageID {
                        item.page = page
                        events.append(ScrapbookEvent(type: .itemRemoved, pageIndex: pageIndex(of: oldPage),
                                                     senderID: senderID, itemID: item.id))
                        events.append(ScrapbookEvent(type: .itemPlaced, pageIndex: index, senderID: senderID,
                                                     item: item.toPayload()))
                        continue
                    }
                    events.append(ScrapbookEvent(
                        type: .itemTransformed, pageIndex: index, senderID: senderID, itemID: item.id,
                        centerX: item.centerX, centerY: item.centerY, width: item.width, rotation: item.rotation,
                        zIndex: item.zIndex, loopEnabled: item.loopEnabled
                    ))
                    if before.text != state.text || before.textColor != state.textColor, let text = state.text {
                        events.append(ScrapbookEvent(type: .itemTextUpdated, pageIndex: index, senderID: senderID,
                                                     itemID: item.id, text: text, textColor: state.textColor))
                    }
                    if before.drawingData != state.drawingData {
                        events.append(ScrapbookEvent(type: .drawingUpdated, pageIndex: index, senderID: senderID,
                                                     itemID: item.id, zIndex: item.zIndex, drawingData: item.drawingData))
                    }
                    if before.maskData != state.maskData {
                        events.append(ScrapbookEvent(type: .itemCut, pageIndex: index, senderID: senderID,
                                                     itemID: item.id, maskData: item.maskData, newPieces: []))
                    }
                } else {
                    let item = ScrapbookItem(centerX: 0, centerY: 0, width: 0, rotation: 0, zIndex: 0)
                    state.apply(to: item)
                    modelContext.insert(item)
                    item.page = page
                    events.append(ScrapbookEvent(type: .itemPlaced, pageIndex: index, senderID: senderID,
                                                 item: item.toPayload()))
                }
            }
        }
        for (id, item) in currentItems where !wantedIDs.contains(id) {
            if selectedItemID == id { selectedItemID = nil }
            events.append(ScrapbookEvent(type: .itemRemoved, pageIndex: pageIndex(of: item.page), senderID: senderID,
                                         itemID: id))
            modelContext.delete(item)
        }
        for sheet in scrapbook?.stickerSheets ?? [] {
            if let used = target.stickerUsage[sheet.id] { sheet.usedStickerIDs = used }
        }
        if let color = target.coverColor, let scrapbook,
           color.hex != scrapbook.coverColorHex || color.picked != scrapbook.coverColorPicked {
            scrapbook.coverColorHex = color.hex
            scrapbook.coverColorPicked = color.picked
            events.append(ScrapbookEvent(type: .coverColor, pageIndex: Self.frontCoverEventIndex, senderID: senderID,
                                         coverColor: color.hex))
        }
        guard save() else { return }
        events.forEach(broadcast)

        // The open Pencil canvases show the restored strokes; a layer that went away gets a fresh one.
        if isDrawing {
            drawingSaveTask?.cancel()
            pendingDrawingLayerIDs.removeAll()
            drawingLayerIDs.removeAll()
            beginDrawing()
            remoteDrawingRevision &+= 1
        }
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
            guard let payload = event.item,
                  let page = page(atEventIndex: event.pageIndex)
                    ?? (event.pageIndex < 0 ? ensureCoverPage(event.pageIndex == Self.frontCoverEventIndex ? .front : .spine) : nil)
            else { return }
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
                if let newPieces = event.newPieces, let page = page(atEventIndex: event.pageIndex) {
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
            guard let restoredPayload = event.restoredItem, let page = page(atEventIndex: event.pageIndex) else { return }
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
                if let pageID = drawingLayerIDs.first(where: { $0.value == itemID })?.key {
                    pendingDrawingLayerIDs.remove(itemID)
                    drawingLayerIDs[pageID] = nil
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
            guard let page = page(atEventIndex: event.pageIndex)
                    ?? (event.pageIndex < 0 ? ensureCoverPage(event.pageIndex == Self.frontCoverEventIndex ? .front : .spine) : nil)
            else { return }
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
                        zIndex: event.zIndex ?? frontZIndex(on: page)
                    )
                    layer.id = itemID
                    layer.drawingData = nextData
                    modelContext.insert(layer)
                    layer.page = page
                }
                save()
                if drawingLayerIDs.values.contains(itemID) {
                    remoteDrawingRevision &+= 1
                }
            } else {
                page.drawingData = event.drawingData
                save()
            }

        case .editingDone:
            guard let memberID = event.memberID else { return }
            applyFinishStatus(doneIDs: [memberID], locked: false)

        case .editingResumed:
            guard let memberID = event.memberID, let scrapbook, !scrapbook.isLocked else { return }
            scrapbook.doneEditingMemberIDs.removeAll { $0 == memberID }
            save()

        case .scrapbookLocked:
            applyFinishStatus(doneIDs: [event.senderID], locked: true)

        case .coverColor:
            guard let hex = event.coverColor, let scrapbook else { return }
            scrapbook.coverColorHex = hex
            scrapbook.coverColorPicked = true
            save()

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

/// Everything about one item, for undo / redo (change 025).
private struct ItemState: Equatable {
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
    let letterID: String?
    let text: String?
    let textColor: String?
    let washiID: String?
    let washiLength: Double?
    let tearSeed: Int?
    let drawingData: Data?

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
        letterID = item.letterID
        text = item.text
        textColor = item.textColor
        washiID = item.washiID
        washiLength = item.washiLength
        tearSeed = item.tearSeed
        drawingData = item.drawingData
    }

    func apply(to item: ScrapbookItem) {
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
        item.letterID = letterID
        item.text = text
        item.textColor = textColor
        item.washiID = washiID
        item.washiLength = washiLength
        item.tearSeed = tearSeed
        item.drawingData = drawingData
    }
}

/// The spread's pages and the sticker sheets before a change.
private struct EditorSnapshot {
    let pages: [(pageID: UUID, items: [ItemState])]
    /// Edit Cover only (change 121): the cover color and whether it was picked.
    let coverColor: (hex: String, picked: Bool)?
    let stickerUsage: [UUID: [String]]
}

/// An item of a spread with its page and the page's place in the spread (0 = left), change 104.
struct SpreadItem: Identifiable {
    let pageIndex: Int
    let page: ScrapbookPage
    let item: ScrapbookItem
    var id: UUID { item.id }
}
