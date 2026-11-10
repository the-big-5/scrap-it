import CoreGraphics
import Foundation
import Observation
import SwiftData

/// One photo of the roll on the reveal screen (change 021).
struct RevealPhoto: Identifiable, Equatable {
    let id: UUID
    let imageData: Data
    let movieData: Data?
    let timestamp: Date
    /// Width / height.
    let aspectRatio: CGFloat
}

/// Where a scattered photo lies on the mat: its center and rotation in degrees.
struct ScatterPlacement: Equatable {
    var center: CGPoint
    var rotation: Double
}

/// Roll Reveal (change 021, Figma 1323:41568 / 1323:41482 / 793:3352 / 1444:23620): shown once after End Roll.
/// Envelope with the roll name and photo count → torn open → photos scattered on the mat (draggable) or
/// tidied into a grid → photo detail with Save / Share → Start Scrapbook opens the editor.
@Observable
final class RollRevealViewModel {
    enum Stage: Equatable {
        case envelope
        case scattered
        case tidy
    }

    private(set) var rollName = ""
    private(set) var photos: [RevealPhoto] = []
    private(set) var stage: Stage = .envelope
    private(set) var placements: [UUID: ScatterPlacement] = [:]
    /// Back to front.
    private(set) var stackOrder: [UUID] = []
    private(set) var selectedPhotoID: UUID?
    private(set) var isSaving = false
    private(set) var saveMessage: String?

    static let photoLongSide: CGFloat = 150
    static let maxRotation: Double = 14
    /// Space kept free above (status bar, Tidy Up) and below (Start Scrapbook) for photo centers.
    static let scatterTopInset: CGFloat = 110
    static let scatterBottomInset: CGFloat = 120
    static let scatterSideInset: CGFloat = 30
    static let savedMessage = "Saved to Photos"
    static let saveFailedMessage = "Couldn't save. Allow ScrapIt to add photos in Settings."

    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private weak var navigator: (any Navigator)?
    @ObservationIgnored private let scrapbookID: UUID
    @ObservationIgnored private let photoSaver: any PhotoLibrarySaving
    @ObservationIgnored private var matSize: CGSize = .zero

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    init(
        modelContext: ModelContext,
        navigator: (any Navigator)?,
        scrapbookID: UUID,
        photoSaver: any PhotoLibrarySaving = PhotoLibrarySaver()
    ) {
        self.modelContext = modelContext
        self.navigator = navigator
        self.scrapbookID = scrapbookID
        self.photoSaver = photoSaver
        refresh()
    }

    // MARK: - Content

    /// "1 photo" / "N photos": the photos on this phone right now (no "/24").
    var labelText: String {
        photos.count == 1 ? "1 photo" : "\(photos.count) photos"
    }

    var isTorn: Bool { stage != .envelope }

    var tidyButtonTitle: String { stage == .tidy ? "Scatter" : "Tidy Up" }

    /// Tidy Up grid: oldest first.
    var gridPhotos: [RevealPhoto] {
        photos.sorted { $0.timestamp < $1.timestamp }
    }

    var selectedPhoto: RevealPhoto? {
        photos.first { $0.id == selectedPhotoID }
    }

    func timeText(for photo: RevealPhoto) -> String {
        Self.timeFormatter.string(from: photo.timestamp)
    }

    func stackIndex(of id: UUID) -> Int {
        stackOrder.firstIndex(of: id) ?? 0
    }

    /// Reads the roll's photos again. Friends' photos keep arriving after End Roll (change 020): before the
    /// tear they only change the count; after it they land on the mat and in the grid.
    func refresh() {
        let scrapbookID = scrapbookID
        let scrapbookDescriptor = FetchDescriptor<Scrapbook>(predicate: #Predicate { $0.id == scrapbookID })
        guard let scrapbook = try? modelContext.fetch(scrapbookDescriptor).first else { return }
        rollName = scrapbook.title
        guard let sessionID = scrapbook.sourceSessionID else { return }
        let photoDescriptor = FetchDescriptor<ScrapPhoto>(
            predicate: #Predicate { $0.sourceSessionID == sessionID },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        let stored = (try? modelContext.fetch(photoDescriptor)) ?? []
        let known = Set(photos.map(\.id))
        let added = stored.filter { !known.contains($0.id) }.map { photo in
            RevealPhoto(
                id: photo.id,
                imageData: photo.imageData,
                movieData: photo.livePhotoMovieData,
                timestamp: photo.timestamp,
                aspectRatio: ScrapbookImageLoader.shared.aspectRatio(for: photo.id, data: photo.imageData) ?? 3.0 / 4.0
            )
        }
        guard !added.isEmpty else { return }
        photos += added
        stackOrder += added.map(\.id)
        if isTorn {
            placeMissingPhotos()
        }
    }

    /// Keeps the photos up to date while the screen is open: reads them again as soon as the store saves
    /// (friends' photos are saved by the End Roll sync), so the count changes right away.
    func observePhotos() async {
        for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave).map({ _ in () }) {
            refresh()
        }
    }

    // MARK: - Envelope and mat

    func setMatSize(_ size: CGSize) {
        guard size != matSize, size.width > 0, size.height > 0 else { return }
        matSize = size
        if isTorn {
            placeMissingPhotos()
        }
    }

    /// The swipe tore the envelope open: the photos spill onto the mat.
    func tear() {
        guard stage == .envelope else { return }
        placeMissingPhotos()
        stage = .scattered
    }

    func toggleTidy() {
        switch stage {
        case .envelope: return
        case .scattered: stage = .tidy
        case .tidy: stage = .scattered
        }
    }

    func bringToFront(_ id: UUID) {
        guard stackOrder.last != id else { return }
        stackOrder.removeAll { $0 == id }
        stackOrder.append(id)
    }

    /// Drag end: the photo moves by the drag, its center kept on the mat.
    func move(_ id: UUID, by translation: CGSize) {
        guard var placement = placements[id] else { return }
        placement.center = Self.clamped(
            CGPoint(x: placement.center.x + translation.width, y: placement.center.y + translation.height),
            in: matSize
        )
        placements[id] = placement
    }

    // MARK: - Detail

    func select(_ id: UUID) {
        selectedPhotoID = id
    }

    func closeDetail() {
        selectedPhotoID = nil
    }

    /// Saves the open photo to Photos (a Live Photo as a Live Photo).
    func saveSelected() async {
        guard let photo = selectedPhoto, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await photoSaver.save(imageData: photo.imageData, movieData: photo.movieData)
            saveMessage = Self.savedMessage
        } catch {
            saveMessage = Self.saveFailedMessage
        }
    }

    func clearSaveMessage() {
        saveMessage = nil
    }

    // MARK: - Leave

    /// Opens the scrapbook editor; the reveal is not kept in the back stack, so it is never shown again.
    func startScrapbook() {
        navigator?.setStack([.scrapbook(scrapbookID)])
    }

    // MARK: - Layout

    /// Size of a scattered photo: long side 150 pt, as in Figma.
    static func cardSize(aspectRatio: CGFloat) -> CGSize {
        aspectRatio >= 1
            ? CGSize(width: photoLongSide, height: photoLongSide / aspectRatio)
            : CGSize(width: photoLongSide * aspectRatio, height: photoLongSide)
    }

    /// Spreads `count` photos over the mat: one jittered cell per photo (3 columns), cells in a shuffled
    /// order, slight rotation. Same input → same layout.
    static func scatterLayout(count: Int, in size: CGSize) -> [ScatterPlacement] {
        guard count > 0 else { return [] }
        let columns = min(3, count)
        let rows = Int((Double(count) / Double(columns)).rounded(.up))
        let area = CGRect(
            x: scatterSideInset,
            y: scatterTopInset,
            width: max(1, size.width - scatterSideInset * 2),
            height: max(1, size.height - scatterTopInset - scatterBottomInset)
        )
        let cellWidth = area.width / CGFloat(columns)
        let cellHeight = area.height / CGFloat(rows)
        var random = SeededRandom(seed: UInt64(count))
        var cells = Array(0..<(columns * rows))
        cells.shuffle(using: &random)
        return (0..<count).map { index in
            let cell = cells[index]
            let jitterX = CGFloat(random.unit() - 0.5) * cellWidth * 0.6
            let jitterY = CGFloat(random.unit() - 0.5) * cellHeight * 0.6
            let center = CGPoint(
                x: area.minX + (CGFloat(cell % columns) + 0.5) * cellWidth + jitterX,
                y: area.minY + (CGFloat(cell / columns) + 0.5) * cellHeight + jitterY
            )
            return ScatterPlacement(
                center: clamped(center, in: size),
                rotation: (random.unit() * 2 - 1) * maxRotation
            )
        }
    }

    /// Keeps a photo center on the mat.
    static func clamped(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, scatterSideInset), max(scatterSideInset, size.width - scatterSideInset)),
            y: min(max(point.y, scatterTopInset), max(scatterTopInset, size.height - scatterBottomInset))
        )
    }

    private func placeMissingPhotos() {
        guard matSize.width > 0, matSize.height > 0 else { return }
        let layout = Self.scatterLayout(count: photos.count, in: matSize)
        for (index, photo) in photos.enumerated() where placements[photo.id] == nil {
            placements[photo.id] = layout[index]
        }
    }
}

/// SplitMix64: a small repeatable generator, so the scatter layout is the same every time.
private struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
