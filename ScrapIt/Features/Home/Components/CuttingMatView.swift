import SwiftUI

struct CuttingMatView: View {
    var body: some View {
        ZStack {
            Image("DeskCuttingMat")
                .resizable()
                .scaledToFit()

            Image("DeskMeasurements")
                .resizable()
                .scaledToFit()
        }
        .frame(width: 402, height: 421)
        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 5)
        .allowsHitTesting(false)
    }
}
