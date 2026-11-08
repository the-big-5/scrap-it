import SwiftUI

/// Page background picker (change 013, POC list; may change with the design).
struct BackgroundPickerView: View {
    let selection: PageBackground
    let onSelect: (PageBackground) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(PageBackground.allCases) { background in
                        Button {
                            onSelect(background)
                        } label: {
                            VStack(spacing: 6) {
                                PageBackgroundView(background: background)
                                    .aspectRatio(3 / 4, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(selection == background ? Color.accentColor : Color.gray.opacity(0.4),
                                                    lineWidth: selection == background ? 3 : 0.5)
                                    )
                                Text(background.name)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Page Background")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
