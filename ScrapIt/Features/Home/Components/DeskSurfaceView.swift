import SwiftUI

struct DeskSurfaceView: View {
    var body: some View {
        ZStack {
            Color(red: 0.60, green: 0.33, blue: 0.19) // #9A5531 leather brown
                .ignoresSafeArea()

            Image("DeskSurface")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}
