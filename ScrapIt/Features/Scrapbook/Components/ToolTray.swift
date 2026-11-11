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
    /// Where the closed button sits in the tray's own space (change 025: `.bottomTrailing` when the tray is turned
    /// on its left side in landscape, so the button ends up at the bottom of the screen).
    var closedAlignment: Alignment = .bottomLeading
    /// Turns the closed button back upright when the whole tray is turned on its side (change 025), so the pen
    /// stands up as in Figma 1563:30642 / 1563:30756.
    var closedButtonRotation: Angle = .zero
    @ViewBuilder let subTray: (ScrapbookTool) -> SubTray

    private var closedAnchor: UnitPoint { closedAlignment == .bottomTrailing ? .bottomTrailing : .bottomLeading }

    var body: some View {
        ZStack(alignment: closedAlignment) {
            if isOpen {
                VStack(spacing: -TrayStyle.overlap) {
                    if let activeTool, activeTool.hasSubTray {
                        subTray(activeTool)
                            .frame(height: TrayStyle.trayHeight)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(0)
                    }
                    mainTray
                        .zIndex(1)
                }
                .transition(.scale(scale: 0.25, anchor: closedAnchor).combined(with: .opacity))
            } else {
                closedButton
                    .transition(.scale(scale: 0.8, anchor: closedAnchor).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 6)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isOpen)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: activeTool)
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
        return TrayScroll(spacing: 16) {
            ForEach(ScrapbookTool.allCases) { tool in
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
            // Swiping down folds the tray back into the round button.
            ScrollPanProbe(direction: .down, onEnded: { _, translation, cancelled in
                if !cancelled, translation.height > 30 { onClose() }
            })
        }
    }
}
