import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

struct FilmCanisterFilterRow: View {
    let filter: RollFilter
    let isSelected: Bool
    let onSelect: () -> Void

    private let sampleScenes: [(icon: String, label: String)] = [
        ("person.2.fill", "Friends"),
        ("cup.and.saucer.fill", "Cafe"),
        ("sun.max.fill", "Golden Hr"),
        ("sparkles", "Night Out")
    ]

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 0) {
                // Canister body on the left
                FilmCanisterBadge(filter: filter, isSelected: isSelected)
                    .padding(.leading, 30)
                    .zIndex(1)

                // Horizontal sprocketed film roll with sample carousel frames
                VStack(spacing: 0) {
                    FilmSprocketStrip()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(0..<sampleScenes.count, id: \.self) { index in
                                let sample = sampleScenes[index]
                                ZStack {
                                    Rectangle()
                                        .fill(
                                            isSelected
                                                ? AnyShapeStyle(frameBackground(for: filter, index: index))
                                                : AnyShapeStyle(ScrapTheme.filmStripDark)
                                        )
                                        .frame(width: 96, height: 84)

                                    if isSelected {
                                        VStack(spacing: 6) {
                                            Image(systemName: sample.icon)
                                                .font(.system(size: 22))
                                                .foregroundStyle(frameForeground(for: filter))
                                            Text(sample.label)
                                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(frameForeground(for: filter).opacity(0.85))
                                        }
                                        .transition(.opacity.combined(with: .scale))
                                    }
                                }
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.black, lineWidth: 1.5)
                                )
                            }
                        }
                    }
                    .frame(height: 84)
                    .background(ScrapTheme.filmStripDark)

                    FilmSprocketStrip()
                }
                .offset(x: -6)
            }
            .scaleEffect(isSelected ? 1.0 : 0.97, anchor: .leading)
        }
        .buttonStyle(.plain)
    }

    private func frameBackground(for filter: RollFilter, index: Int) -> LinearGradient {
        switch filter {
        case .cinematicBW400:
            let shade = 0.20 + Double(index % 2) * 0.08
            return LinearGradient(
                colors: [Color(white: shade + 0.12), Color(white: shade)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .colorPrint200:
            return LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.30, blue: 0.20),
                    Color(red: 0.24, green: 0.19, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func frameForeground(for filter: RollFilter) -> Color {
        switch filter {
        case .cinematicBW400:
            return Color(white: 0.92)
        case .colorPrint200:
            return Color(red: 0.99, green: 0.85, blue: 0.52)
        }
    }
}
