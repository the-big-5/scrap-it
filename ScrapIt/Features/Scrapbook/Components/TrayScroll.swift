import SwiftUI

extension EnvironmentValues {
    @Entry var trayPillWidth: CGFloat? = nil
}

/// A leather tray that scrolls sideways. The leather and its content move together (not the content inside
/// a still leather), and the tray grows with its content when it doesn't fit the screen (brief K2).
///
/// Content sits inside the stitching, centered vertically. Content taller than that area (e.g. the long pencil)
/// is cut at the bottom stitching, as if tucked into a pocket.
struct TrayScroll<Content: View, Probe: View>: View {
    /// Content area from the tray top to `contentBottom` (pt). The second tray uses 88, because its lower part
    /// is behind the main tray.
    var contentBottom: CGFloat = TrayStyle.trayHeight - TrayStyle.stitchInset
    var spacing: CGFloat = 14
    /// A fixed tray (change 026, Edit Cover): its few tools sit centered and it doesn't scroll.
    var isFixed = false
    @ViewBuilder let content: () -> Content
    @ViewBuilder var probe: () -> Probe
    @Environment(\.trayPillWidth) private var trayPillWidth

    static var contentTop: CGFloat { TrayStyle.stitchInset }

    var body: some View {
        if let pillWidth = trayPillWidth {
            let innerWidth = max(0, pillWidth - TrayStyle.stitchInset * 2)
            ZStack(alignment: .top) {
                TrayBackground(shape: RoundedRectangle(cornerRadius: 22))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: spacing) {
                        content()
                    }
                    .padding(.horizontal, 14)
                    .frame(minWidth: innerWidth, alignment: .center)
                    .frame(height: contentBottom - Self.contentTop)
                    .clipped()
                    .background { probe() }
                }
                .frame(width: innerWidth, height: contentBottom - Self.contentTop)
                .clipped()
                .padding(.top, Self.contentTop)
                .scrollDisabled(isFixed)
            }
            .frame(width: pillWidth, height: TrayStyle.trayHeight)
        } else {
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: spacing) {
                        content()
                    }
                    .padding(.horizontal, 20)
                    .frame(minWidth: geometry.size.width, alignment: isFixed ? .center : .leading)
                    .frame(height: contentBottom - Self.contentTop)
                    .clipped()
                    .padding(.top, Self.contentTop)
                    .frame(height: TrayStyle.trayHeight, alignment: .top)
                    .background(TrayBackground(shape: RoundedRectangle(cornerRadius: 22)))
                    .background { probe() }
                }
                .scrollClipDisabled()
                .scrollDisabled(isFixed)
            }
            .frame(height: TrayStyle.trayHeight)
        }
    }
}

extension TrayScroll where Probe == EmptyView {
    init(contentBottom: CGFloat = TrayStyle.trayHeight - TrayStyle.stitchInset, spacing: CGFloat = 14,
         @ViewBuilder content: @escaping () -> Content) {
        self.contentBottom = contentBottom
        self.spacing = spacing
        self.content = content
        self.probe = { EmptyView() }
    }
}

/// A tray item taller than the content area (long tools): only the top `visibleHeight` shows, centered in the
/// area; the rest goes into the "pocket" below (brief F6, K3).
struct PocketItem: View {
    let assetName: String
    let imageHeight: CGFloat
    let visibleHeight: CGFloat
    let areaHeight: CGFloat
    /// Horizontal shift so the tool's body (not its clip) is centered.
    var centerOffset: CGFloat = 0
    var lift: CGFloat = 0
    var isActive = false

    var body: some View {
        let image = Image(assetName).resizable().scaledToFit().frame(height: imageHeight)
        let top = (areaHeight - visibleHeight) / 2
        image
            .hidden()
            .frame(height: areaHeight)
            .overlay(alignment: .top) {
                image
                    .shadow(color: .black.opacity(isActive ? 0.35 : 0.18), radius: isActive ? 4 : 1.5, y: 1)
                    .offset(x: centerOffset, y: top - lift)
            }
            .contentShape(Rectangle())
    }
}
