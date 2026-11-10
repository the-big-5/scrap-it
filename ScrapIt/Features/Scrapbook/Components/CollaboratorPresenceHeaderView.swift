import SwiftUI
import UIKit

struct CollaboratorPresenceHeaderView: View {
    let collaborators: [CollaboratorPresence]
    @State private var isDetailPopoverPresented = false

    var body: some View {
        if !collaborators.isEmpty {
            Button(action: { isDetailPopoverPresented.toggle() }) {
                HStack(spacing: 6) {
                    // Overlapping avatar stack (Freeform / Keynote style)
                    HStack(spacing: -8) {
                        ForEach(collaborators.prefix(3)) { collaborator in
                            avatarCircle(for: collaborator)
                        }
                        if collaborators.count > 3 {
                            moreCountCircle(count: collaborators.count - 3)
                        }
                    }

                    // Status text if 1 collaborator
                    if let first = collaborators.first, collaborators.count == 1 {
                        Text("\(first.name) • p. \(first.currentPageIndex + 1)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ScrapTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.85)))
                .overlay(
                    Capsule()
                        .strokeBorder(DSColor.Kraft.lightActive.color, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isDetailPopoverPresented) {
                collaboratorsList
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    @ViewBuilder
    private func avatarCircle(for collaborator: CollaboratorPresence) -> some View {
        if let avatarData = collaborator.avatarData, let image = UIImage(data: avatarData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 26, height: 26)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 1.5)
                )
        } else {
            let initial = String(collaborator.name.prefix(1)).uppercased()
            let color = Color(hex: collaborator.colorHex) ?? DSColor.Brand.primary.color

            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 26, height: 26)

                Text(initial.isEmpty ? "?" : initial)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)

                Circle()
                    .strokeBorder(Color.white, lineWidth: 1.5)
                    .frame(width: 26, height: 26)
            }
        }
    }

    private func moreCountCircle(count: Int) -> some View {
        ZStack {
            Circle()
                .fill(DSColor.Kraft.normal.color)
                .frame(width: 26, height: 26)

            Text("+\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DSColor.Brand.primary.color)

            Circle()
                .strokeBorder(Color.white, lineWidth: 1.5)
                .frame(width: 26, height: 26)
        }
    }

    private var collaboratorsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active Editors")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DSColor.Brand.primary.color)
                .padding(.bottom, 2)

            ForEach(collaborators) { collaborator in
                HStack(spacing: 8) {
                    avatarCircle(for: collaborator)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(collaborator.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DSColor.Brand.primary.color)

                        Text("Viewing Page \(collaborator.currentPageIndex + 1)")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(ScrapTheme.secondaryText)
                    }
                }
            }
        }
        .padding(14)
        .frame(minWidth: 160)
    }
}

private extension Color {
    init?(hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") {
            clean.removeFirst()
        }
        guard clean.count == 6, let rgb = UInt64(clean, radix: 16) else { return nil }
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
