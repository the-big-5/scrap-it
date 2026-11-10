import SwiftUI

/// Typing plain text (change 022, camera POC): the keyboard opens at once, the colors sit under the field,
/// Done saves. Empty text isn't added (or removes an existing text).
struct TextEditorOverlay: View {
    @Binding var draft: String
    @Binding var color: TextItemColor
    let onDone: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onDone)

            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button("Done", action: onDone)
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                TextField("Type something", text: $draft, axis: .vertical)
                    .font(TextItemStyle.font(size: 30))
                    .foregroundStyle(color.color)
                    .multilineTextAlignment(.center)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(color == .white ? Color.black.opacity(0.35) : Color.white.opacity(0.92))
                    )

                HStack(spacing: 12) {
                    ForEach(TextItemColor.allCases) { option in
                        Button {
                            color = option
                        } label: {
                            Circle()
                                .fill(option.color)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(.white, lineWidth: color == option ? 3 : 1))
                                .shadow(color: .black.opacity(0.3), radius: 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.rawValue.capitalized)
                        .accessibilityAddTraits(color == option ? .isSelected : [])
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .onAppear { isFocused = true }
    }
}
