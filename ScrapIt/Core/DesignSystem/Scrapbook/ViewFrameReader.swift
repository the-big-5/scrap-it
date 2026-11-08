import SwiftUI

extension View {
    /// Reports the view's frame in a coordinate space on appear and whenever it changes (POC).
    func onFrameChange(in space: CoordinateSpace, perform action: @escaping (CGRect) -> Void) -> some View {
        background(
            GeometryReader { geometry in
                let frame = geometry.frame(in: space)
                Color.clear
                    .onAppear { action(frame) }
                    .onChange(of: frame) { _, newFrame in action(newFrame) }
            }
        )
    }
}
