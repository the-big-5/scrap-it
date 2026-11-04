import SwiftData
import SwiftUI

struct HangingLampIllustration: View {
    var body: some View {
        Image("HangingLamp")
            .resizable()
            .scaledToFit()
            .frame(width: 124, height: 225)
            .offset(y: -12)
    }
}
