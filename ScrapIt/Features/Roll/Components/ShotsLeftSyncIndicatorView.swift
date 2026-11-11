import SwiftUI

/// Subtle rotating yellow progress arc indicator around the 83x83 outer dial rim (change 058).
/// Displayed while CloudKit slot claims or background photo synchronization is in flight.
struct ShotsLeftSyncIndicatorView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let angle = (time.truncatingRemainder(dividingBy: 1.0)) * 360.0

            ZStack {
                // Subtle ambient track around the dial perimeter
                Circle()
                    .inset(by: 1.5)
                    .stroke(DSColor.Brand.secondary.color.opacity(0.25), lineWidth: 2.0)

                // Rotating active amber progress arc
                Circle()
                    .inset(by: 1.5)
                    .trim(from: 0.0, to: 0.30)
                    .stroke(
                        DSColor.Brand.secondary.color,
                        style: StrokeStyle(lineWidth: 3.0, lineCap: .round)
                    )
                    .rotationEffect(.degrees(angle))
            }
            .frame(width: 83, height: 83)
        }
        .frame(width: 83, height: 83)
        .allowsHitTesting(false)
    }
}
