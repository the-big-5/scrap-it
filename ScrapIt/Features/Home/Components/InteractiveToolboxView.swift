import SwiftUI

struct ToolboxRattleState: Equatable {
    var boxOffset: CGSize = .zero
    var boxDegrees: Double = 0
    var toolOffset: CGSize = .zero
    var toolDegrees: Double = 0
}

/// Layered open red toolbox (`stat 1`) whose interior tools rattle with independent
/// secondary inertia inside their compartments whenever the toolbox shakes.
struct InteractiveToolboxView: View {
    private struct ToolSpec {
        let asset: String
        let normCenter: CGPoint
        let normSize: CGSize
        let offsetMultiplier: CGSize
        let rotationMultiplier: Double
    }

    private static let tools: [ToolSpec] = [
        ToolSpec(
            asset: "DeskToolboxRuler",
            normCenter: CGPoint(x: 0.65104, y: 0.44971),
            normSize: CGSize(width: 0.10677, height: 0.41113),
            offsetMultiplier: CGSize(width: 0.50, height: 0.55),
            rotationMultiplier: 0.50
        ),
        ToolSpec(
            asset: "DeskToolboxPencils",
            normCenter: CGPoint(x: 0.59701, y: 0.46875),
            normSize: CGSize(width: 0.07682, height: 0.35938),
            offsetMultiplier: CGSize(width: -0.95, height: 0.55),
            rotationMultiplier: -0.85
        ),
        ToolSpec(
            asset: "DeskToolboxCutter",
            normCenter: CGPoint(x: 0.36198, y: 0.37012),
            normSize: CGSize(width: 0.07812, height: 0.22852),
            offsetMultiplier: CGSize(width: 0.65, height: -0.70),
            rotationMultiplier: 0.80
        ),
        ToolSpec(
            asset: "DeskToolboxScissors",
            normCenter: CGPoint(x: 0.46354, y: 0.40674),
            normSize: CGSize(width: 0.17969, height: 0.31543),
            offsetMultiplier: CGSize(width: -0.75, height: 0.45),
            rotationMultiplier: -0.85
        ),
        ToolSpec(
            asset: "DeskToolboxEraser",
            normCenter: CGPoint(x: 0.36719, y: 0.70166),
            normSize: CGSize(width: 0.05729, height: 0.11426),
            offsetMultiplier: CGSize(width: 1.10, height: -0.95),
            rotationMultiplier: 1.30
        ),
        ToolSpec(
            asset: "DeskToolboxTapePink",
            normCenter: CGPoint(x: 0.45182, y: 0.73145),
            normSize: CGSize(width: 0.10417, height: 0.09766),
            offsetMultiplier: CGSize(width: -0.85, height: 0.70),
            rotationMultiplier: -1.10
        ),
        ToolSpec(
            asset: "DeskToolboxTapeBlue",
            normCenter: CGPoint(x: 0.45703, y: 0.64062),
            normSize: CGSize(width: 0.09635, height: 0.09961),
            offsetMultiplier: CGSize(width: 1.05, height: -0.80),
            rotationMultiplier: 1.25
        ),
        ToolSpec(
            asset: "DeskToolboxNotes",
            normCenter: CGPoint(x: 0.62956, y: 0.76221),
            normSize: CGSize(width: 0.16016, height: 0.11621),
            offsetMultiplier: CGSize(width: -0.80, height: -0.75),
            rotationMultiplier: 0.90
        ),
    ]

    let boxSize: CGSize
    let layoutScale: CGFloat
    let rattle: ToolboxRattleState

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("DeskToolboxBase")
                .resizable()
                .frame(width: boxSize.width, height: boxSize.height)

            ForEach(Self.tools, id: \.asset) { tool in
                Image(tool.asset)
                    .resizable()
                    .frame(
                        width: boxSize.width * tool.normSize.width,
                        height: boxSize.height * tool.normSize.height
                    )
                    .shadow(color: .black.opacity(0.16), radius: layoutScale * 1.5, x: 0, y: layoutScale * 1.5)
                    .rotationEffect(.degrees(rattle.toolDegrees * tool.rotationMultiplier))
                    .offset(
                        x: rattle.toolOffset.width * tool.offsetMultiplier.width * layoutScale,
                        y: rattle.toolOffset.height * tool.offsetMultiplier.height * layoutScale
                    )
                    .position(
                        x: boxSize.width * tool.normCenter.x,
                        y: boxSize.height * tool.normCenter.y
                    )
            }
        }
        .frame(width: boxSize.width, height: boxSize.height)
    }
}
