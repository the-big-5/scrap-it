import SwiftUI

/// Craft collage illustration for the empty "Resume Roll" state (Figma 1537:25997).
struct RollEmptyIllustration: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 1537:26007: Winding amber film leader ("rolls add 1")
            Image("RollEmptyLeader")
                .resizable()
                .frame(width: 99.533, height: 132.775)
                .rotationEffect(.degrees(12.42))
                .position(x: 165.67, y: 75.72)

            // 1537:26008: Disposable camera ("dispo 1")
            Image("DeskDisposableCamera")
                .resizable()
                .frame(width: 155.953, height: 116.908)
                .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 4)
                .rotationEffect(.degrees(-5.71))
                .position(x: 104.45, y: 79.26)

            // 1537:26009: Yellow 200 canister ("rolls buatan sanny 4 1")
            Image("DeskFilmRollYellow")
                .resizable()
                .frame(width: 79, height: 59)
                .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 4)
                .position(x: 39.5, y: 42.5)

            // 1537:26010: Red 400 canister ("rolls buatan sanny 2 1")
            Image("DeskFilmRollRed")
                .resizable()
                .frame(width: 54.437, height: 71.005)
                .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 4)
                .rotationEffect(.degrees(54.26))
                .position(x: 155.93, y: 129.17)

            // 1537:26011: Right film loop curling in front of camera ("rolls add 2")
            Image("RollEmptyLeader")
                .resizable()
                .frame(width: 99.533, height: 132.775)
                .mask(alignment: .trailing) {
                    Rectangle()
                        .frame(width: 63.982, height: 132.775)
                }
                .rotationEffect(.degrees(12.42))
                .position(x: 165.67, y: 75.72)

            // 1537:26012: Wincing star right
            Image("RollEmptyStarRight")
                .resizable()
                .frame(width: 46, height: 99)
                .position(x: 199.0, y: 102.5)

            // 1537:26013: Wide-eyed star left
            Image("RollEmptyStarLeft")
                .resizable()
                .frame(width: 51, height: 54)
                .position(x: 28.5, y: 79.0)

            // 1537:26014: Happy star top
            Image("RollEmptyStarTop")
                .resizable()
                .frame(width: 51, height: 65)
                .position(x: 107.5, y: 32.5)
        }
        .frame(width: 233, height: 172)
        .accessibilityHidden(true)
    }
}
