# 042: Real-time Collaborative Scrapbook Canvas with Supabase Realtime
Status: Done

## Why
Currently, after a shared roll ends, the host and participants each receive a disconnected, personal local scrapbook. Any photos added, stickers placed, scissors cuts, background choices, and PencilKit drawings made on one device are stored solely in that device's local SwiftData store. Friends who shot a roll together cannot decorate or build the scrapbook together.

The goal is to transform the Scrapbook into a live, collaborative canvas (similar to Apple Freeform / Canva):
1. **Real-time Synchronization:** Peer edits (photos added, stickers placed, items dragged/scaled/rotated, scissors cuts, background changes, completed pencil strokes, and pages added/removed) broadcast and synchronize live across all roll participants using Supabase Realtime.
2. **Independent Browsing:** Each participant can browse and edit different pages independently while staying in sync.
3. **Presence Indicators:** Visual presence indicators in the editor header (overlapping collaborator avatar stack showing active editors and their current page) give clear awareness of who is in the room.

## Touches
flows.md (F5: Scrapbook creation & collaborative editing), ui.md (Scrapbook editor, presence header), tech.md (Scrapbook sync architecture, Supabase Realtime, data models)

## Changes
- ADDED `Core/Services/ScrapbookRealtimeService.swift`:
  - `ScrapbookRealtimeProviding` protocol and `SupabaseScrapbookRealtimeService` implementation.
  - Subscribes to Supabase Realtime channel `scrapbook:<rollCode>` (or `scrapbook:<sourceSessionID>`).
  - Broadcasts and receives typed canvas events:
    - `item_placed`: photo or sticker inserted with normalized coordinates, size, rotation, and z-index.
    - `item_transformed`: position, scale, rotation, or z-index updated.
    - `item_cut`: scissors mask polygon applied to an item.
    - `item_deleted`: item removed from page.
    - `page_background`: page background pattern/color changed.
    - `drawing_updated`: completed PencilKit `PKDrawing` data payload.
    - `page_added` / `page_moved` / `page_deleted`: multi-page structure updates.
    - `presence`: broadcasts active user identity and current page index (`CollaboratorPresence`).
- MODIFIED `Features/Scrapbook/ScrapbookViewModel.swift`:
  - Injects `ScrapbookRealtimeProviding`. Connects when the editor appears and disconnects on disappear.
  - Broadcasts local modifications immediately as actions occur.
  - Applies incoming remote events to the local SwiftData `modelContext` so edits are visible and persisted.
  - Publishes `activeCollaborators: [CollaboratorPresence]` for UI observation.
- MODIFIED `Features/Scrapbook/Components/PencilCanvasView.swift`:
  - Listens for stroke completion (finger lifted) and invokes a debounced completion handler to notify `ScrapbookViewModel` to broadcast updated `drawingData`.
- ADDED `Features/Scrapbook/Components/CollaboratorPresenceHeaderView.swift`:
  - Clean Freeform/Keynote-style top avatar stack showing connected participants with distinct color borders.
  - Displays tooltip/status indicating which page other collaborators are currently editing.
- MODIFIED `Features/Scrapbook/ScrapbookEditorView.swift`:
  - Embeds `CollaboratorPresenceHeaderView` in the top navigation bar.

## Tasks
- [x] Create `ScrapbookRealtimeProviding` protocol and `SupabaseScrapbookRealtimeService` with event broadcasting and presence channel tracking
- [x] Update `ScrapbookViewModel` to connect/disconnect to the realtime service, broadcast local mutations, and apply remote mutations into SwiftData
- [x] Update `PencilCanvasView` to signal completed drawing strokes without spamming broadcasts
- [x] Implement `CollaboratorPresenceHeaderView` and integrate it into `ScrapbookEditorView`
- [x] Synchronize page-level events (page additions, re-ordering, deletions, background selection)
- [x] Add unit tests in `ScrapItTests` for realtime event encoding/decoding, presence tracking, and ViewModel remote action application
- [x] Build and verify all unit tests pass on iOS Simulator

## Out of scope
- Live audio/video chat or cursor finger-coordinate tracking at 60fps (presence tracks active users and current page, not pointer coordinates)
- Continuous mid-stroke vector streaming (pencil drawings sync upon stroke completion)
- Offline conflict resolution algorithms beyond Last-Write-Wins (LWW)
