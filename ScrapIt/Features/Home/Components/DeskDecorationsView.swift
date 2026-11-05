import SwiftUI

struct DeskDecorationsView: View {
    var onTapBooks: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Folder / stationery top-left (stat 1)
            Image("DeskFolder")
                .resizable()
                .scaledToFit()
                .frame(width: 312, height: 416)
                .rotationEffect(.degrees(-70.96))
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 4)
                .position(x: 170, y: 150)
                .allowsHitTesting(false)

            // Tape 1 top-left
            Image("DeskTape1")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 67)
                .position(x: 10, y: 200)
                .allowsHitTesting(false)

            // Stationery element 2 (pins/eraser near top)
            Image("DeskStationery2")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 50)
                .position(x: 80, y: 80)
                .allowsHitTesting(false)

            // Stationery element 4 (clip top-left)
            Image("DeskStationery4")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 35)
                .rotationEffect(.degrees(-14.68))
                .position(x: 30, y: 110)
                .allowsHitTesting(false)

            // Bottom-left stacked books
            Group {
                Image("DeskBookBottom")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 226, height: 301)
                    .rotationEffect(.degrees(-24.38))
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 4)
                    .position(x: 90, y: 660)

                Button(action: onTapBooks) {
                    Image("DeskBookTop")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 192, height: 265)
                        .rotationEffect(.degrees(6.35))
                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .position(x: 118, y: 640)
                .accessibilityLabel("Scrapbook Memories and Guide")
            }

            // Decorative film rolls
            Group {
                Image("DeskFilmRoll4")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 85)
                    .shadow(color: .black.opacity(0.20), radius: 6, x: 0, y: 4)
                    .position(x: 330, y: 500)

                Image("DeskFilmRoll3")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 80)
                    .rotationEffect(.degrees(46.7))
                    .shadow(color: .black.opacity(0.20), radius: 6, x: 0, y: 4)
                    .position(x: 300, y: 580)

                Image("DeskFilmRoll2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 105)
                    .rotationEffect(.degrees(54.26))
                    .shadow(color: .black.opacity(0.20), radius: 6, x: 0, y: 4)
                    .position(x: 235, y: 520)
            }
            .allowsHitTesting(false)

            // Ruler bottom-right
            Image("DeskRuler")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 230)
                .position(x: 270, y: 720)
                .allowsHitTesting(false)

            // Stationery element 1 (clips right)
            Image("DeskStationery1")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 50)
                .position(x: 330, y: 395)
                .allowsHitTesting(false)

            // Stationery element 5 (bottom-right clip)
            Image("DeskStationery5")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 35)
                .rotationEffect(.degrees(-158.83))
                .position(x: 360, y: 440)
                .allowsHitTesting(false)

            // Stationery element 3 (bottom center)
            Image("DeskStationery3")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 50)
                .position(x: 200, y: 760)
                .allowsHitTesting(false)

            // Tape 2 bottom-right
            Image("DeskTape2")
                .resizable()
                .scaledToFit()
                .frame(width: 55, height: 60)
                .position(x: 360, y: 830)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
