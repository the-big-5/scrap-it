import SwiftUI
import UIKit

/// Who is in the scrapbook and on which page (change 025, Figma 1516:23450); also the Editing Progress sheet of the
/// cover screen (change 026, Figma 1563:33166) with "Done Editing" / "In Progress" and no page numbers.
struct WhosHereSheet: View {
    var title = "Who's here"
    var firstTitle = "ON THIS PAGE"
    var secondTitle = "ON OTHER PAGES"
    var showsPageNumbers = true
    let onThisSpread: [WhosHereRow]
    let onOtherPages: [WhosHereRow]
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DSColor.Brand.primary.color)
                HStack {
                    CircleIconButton(systemName: "xmark", accessibilityLabel: "Close", action: onClose)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    section(firstTitle, rows: onThisSpread)
                    if !onOtherPages.isEmpty {
                        section(secondTitle, rows: onOtherPages)
                            .padding(.top, 16)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 24)
            }
        }
        .background(DSColor.Kraft.lightActive.color)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func section(_ title: String, rows: [WhosHereRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DSColor.Component.textSecondary.color)
                .padding(.horizontal, 14)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Divider().padding(.leading, 62) }
                    rowView(row)
                }
            }
            .background(DSColor.Component.surface.color, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func rowView(_ row: WhosHereRow) -> some View {
        HStack(spacing: 12) {
            avatar(row)
            (Text(row.name).font(.system(size: 16, weight: .semibold))
                + Text(row.isMe ? " (You)" : "").font(.system(size: 16)).foregroundColor(DSColor.Component.textSecondary.color))
                .foregroundStyle(DSColor.Brand.primary.color)
                .lineLimit(1)
            Spacer()
            if showsPageNumbers && !row.isMe && !onThisSpread.contains(row) {
                Text("Page \(row.pageNumber)")
                    .font(.system(size: 14))
                    .foregroundStyle(DSColor.Component.textSecondary.color)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func avatar(_ row: WhosHereRow) -> some View {
        if let data = row.avatarData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Self.color(hex: row.colorHex) ?? DSColor.Brand.primary.color)
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String(row.name.prefix(1)).uppercased())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
        }
    }

    /// Presence colors are "#RRGGBB" (change 042).
    private static func color(hex: String) -> Color? {
        let clean = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard clean.count == 6, let rgb = UInt64(clean, radix: 16) else { return nil }
        return Color(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255,
                     blue: Double(rgb & 0xFF) / 255)
    }
}
