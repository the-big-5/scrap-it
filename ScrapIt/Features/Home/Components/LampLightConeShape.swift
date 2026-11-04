import SwiftData
import SwiftUI

struct LampLightConeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topWidth: CGFloat = 92
        path.move(to: CGPoint(x: rect.midX - topWidth / 2, y: 120))
        path.addLine(to: CGPoint(x: rect.midX + topWidth / 2, y: 120))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
