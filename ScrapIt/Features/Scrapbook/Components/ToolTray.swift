import SwiftUI

/// Tool tray at the bottom left of the scrapbook page (change 022, Figma 1306:48941 / 1306:48947, camera POC).
/// Closed: a round red leather button. Open: the full-width main tray; the picked tool opens a second tray above.
struct ToolTray<SubTray: View>: View {
    let isOpen: Bool
    /// The raised tool (also the scissors while cutting).
    let activeTool: ScrapbookTool?
    let onOpen: () -> Void
    /// Swipe down on the main tray.
    let onClose: () -> Void
    let onSelect: (ScrapbookTool) -> Void
    /// The tools in the main tray (change 026: fewer on the cover and the spine).
    var tools: [ScrapbookTool] = ScrapbookTool.allCases
    /// Edit Cover (change 026): the main tray stays open, centered, and doesn't scroll or fold away.
    var isFixed = false
    /// Swipe down on the second tray (Edit Cover): puts the tool away. `nil`: the second tray doesn't react.
    var onCloseSubTray: (() -> Void)?
    /// Where the closed button sits in the tray's own space (change 025: `.bottomTrailing` when the tray is turned
    /// on its left side in landscape, so the button ends up at the bottom of the screen).
    var closedAlignment: Alignment = .bottomLeading
    /// Turns the closed button back upright when the whole tray is turned on its side (change 025), so the pen
    /// stands up as in Figma 1563:30642 / 1563:30756.
    var closedButtonRotation: Angle = .zero
    /// Compact floating pill width on iPad (PencilKit-style tray). `nil` keeps iPhone full-width behavior.
    var pillWidth: CGFloat? = nil
    /// Drag callbacks for moving/minimizing the open iPad floating pill in editor coordinate space.
    var onTrayDragChanged: ((CGSize) -> Void)? = nil
    var onTrayDragEnded: ((CGSize, CGSize) -> Void)? = nil
    @ViewBuilder let subTray: (ScrapbookTool) -> SubTray

    private var closedAnchor: UnitPoint {
        if pillWidth != nil { return .center }
        return closedAlignment == .bottomTrailing ? .bottomTrailing : .bottomLeading
    }

    var body: some View {
        ZStack(alignment: closedAlignment) {
            if isOpen {
                VStack(spacing: -TrayStyle.overlap) {
                    if let activeTool, activeTool.hasSubTray {
                        subTray(activeTool)
                            .frame(height: TrayStyle.trayHeight)
                            .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
                                guard let onCloseSubTray, value.translation.height > 30,
                                      value.translation.height > abs(value.translation.width) else { return }
                                onCloseSubTray()
                            })
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(0)
                    }
                    mainTray
                        .simultaneousGesture(pillWidth != nil && !isFixed ? iPadTrayDragGesture : nil)
                        .zIndex(1)
                }
                .overlay(alignment: .top) {
                    if pillWidth != nil && !isFixed {
                        Capsule()
                            .fill(Color.white.opacity(0.55))
                            .frame(width: 36, height: 4)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 28)
                            .contentShape(Rectangle())
                            .offset(y: -4)
                            .gesture(iPadTrayDragGesture)
                    }
                }
                .environment(\.trayPillWidth, pillWidth)
                .transition(.scale(scale: 0.25, anchor: closedAnchor).combined(with: .opacity))
            } else {
                closedButton
                    .simultaneousGesture(pillWidth != nil && !isFixed ? iPadTrayDragGesture : nil)
                    .transition(.scale(scale: 0.8, anchor: closedAnchor).combined(with: .opacity))
            }
        }
        .padding(.horizontal, pillWidth == nil ? 6 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isOpen)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: activeTool)
    }

    private var iPadTrayDragGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named(StickerDragController.coordinateSpace))
            .onChanged { value in
                onTrayDragChanged?(value.translation)
            }
            .onEnded { value in
                onTrayDragEnded?(value.translation, value.predictedEndTranslation)
            }
    }

    private var closedButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onOpen()
        } label: {
            ZStack {
                TrayBackground(shape: Circle())
                // The long pen sticks up from the bottom of the circle, as in Figma.
                Color.clear
                    .frame(width: TrayStyle.closedSize, height: TrayStyle.closedSize)
                    .overlay(alignment: .top) {
                        Image("tray-tool-pencil")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 220)
                            // The pen's body (not its clip) centered in the circle.
                            .offset(x: -4, y: 16)
                    }
                    // Clipped by the circle's frame, not the image's (brief K7).
                    .clipShape(Circle().inset(by: 7))
            }
            .frame(width: TrayStyle.closedSize, height: TrayStyle.closedSize)
            .rotationEffect(closedButtonRotation)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open tools")
    }

    private var mainTray: some View {
        let area = TrayStyle.trayHeight - TrayStyle.stitchInset * 2
        return TrayScroll(spacing: pillWidth == nil ? 16 : 14, isFixed: isFixed || pillWidth != nil) {
            ForEach(tools) { tool in
                let isActive = activeTool == tool
                Button {
                    // A light haptic each time a tool is picked.
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(tool)
                } label: {
                    PocketItem(assetName: tool.assetName, imageHeight: tool.imageHeight,
                               visibleHeight: tool.visibleHeight, areaHeight: area,
                               centerOffset: tool.centerOffset, lift: isActive ? 6 : 0, isActive: isActive)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tool.title)
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        } probe: {
            // Swiping down folds the tray back into the round button (not on a fixed tray).
            if !isFixed {
                ScrollPanProbe(direction: .down, onEnded: { _, translation, cancelled in
                    if !cancelled, translation.height > 30 { onClose() }
                })
            }
        }
    }
}
