import SwiftUI

enum DSTextFieldKind: CaseIterable, Sendable {
    case plain
    case password
    case search
    /// Multi-line, 112pt tall.
    case caption
}

/// Figma "Input" (647:3718). States follow the Figma description:
/// Initial = empty and resting. Filled = has a value or is focused (leather border, soft ring).
/// Error = border and helper text in error color; helper says what to fix.
struct DSTextField: View {
    let label: LocalizedStringKey?
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var kind: DSTextFieldKind = .plain
    var errorMessage: LocalizedStringKey?

    @FocusState private var isFocused: Bool
    @State private var isRevealed = false

    init(
        _ label: LocalizedStringKey? = nil,
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        kind: DSTextFieldKind = .plain,
        errorMessage: LocalizedStringKey? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.kind = kind
        self.errorMessage = errorMessage
    }

    private static let labelFont = Font.system(size: 13, weight: .semibold)
    private static let helperFont = Font.system(size: 13, weight: .regular)
    private static let valueFont = DSTypography.normalRegular.font
    /// Caption text uses line height 1.45× (Figma).
    private static let captionTypography = DSTypographyToken(family: .sfPro, weight: .regular, size: 16, lineHeight: 23.2)
    private static let cornerRadius: CGFloat = 12

    private var isError: Bool { errorMessage != nil }
    private var isActive: Bool { isFocused || !text.isEmpty }

    private var fieldBackground: DSColorToken {
        isActive || isError ? DSColor.Component.surface : DSColor.Component.field
    }

    private var borderColor: DSColorToken? {
        if isError { return DSColor.Component.inputError }
        return isActive ? DSColor.Camera.leather : nil
    }

    private var iconColor: DSColorToken {
        isActive ? DSColor.Brand.primary : DSColor.Component.placeholder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                Text(label)
                    .font(Self.labelFont)
                    .foregroundStyle(DSColor.Brand.primary)
            }
            field
            if let errorMessage {
                Text(errorMessage)
                    .font(Self.helperFont)
                    .foregroundStyle(DSColor.Component.inputError)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var field: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        return HStack(alignment: kind == .caption ? .top : .center, spacing: 10) {
            if kind == .search {
                DSIcon.search.image(size: 20)
                    .foregroundStyle(iconColor)
            }
            input
            trailingAccessory
        }
        .padding(.horizontal, 16)
        .padding(.vertical, kind == .caption ? 14 : 0)
        .frame(height: kind == .caption ? 112 : 48, alignment: kind == .caption ? .topLeading : .leading)
        .background(shape.fill(fieldBackground))
        .overlay {
            if let borderColor {
                shape.strokeBorder(borderColor, lineWidth: 1.5)
            }
        }
        .background {
            // Soft focus ring: 4pt, leather at 12% (Figma shadow 0 0 0 4).
            if isActive && !isError {
                RoundedRectangle(cornerRadius: Self.cornerRadius + 4, style: .continuous)
                    .fill(DSColor.Camera.leather.opacity(0.12))
                    .padding(-4)
            }
        }
        .contentShape(shape)
        .onTapGesture { isFocused = true }
        .animation(.easeOut(duration: 0.15), value: isActive)
    }

    @ViewBuilder
    private var input: some View {
        let prompt = Text(placeholder).foregroundStyle(DSColor.Component.placeholder)
        Group {
            switch kind {
            case .plain, .search:
                TextField("", text: $text, prompt: prompt)
            case .password:
                if isRevealed {
                    TextField("", text: $text, prompt: prompt)
                } else {
                    SecureField("", text: $text, prompt: prompt)
                }
            case .caption:
                TextField("", text: $text, prompt: prompt, axis: .vertical)
                    .lineSpacing(Self.captionTypography.lineSpacing)
            }
        }
        .font(Self.valueFont)
        .foregroundStyle(DSColor.Brand.primary)
        .tint(DSColor.Camera.leather)
        .focused($isFocused)
        .textInputAutocapitalization(kind == .password ? .never : nil)
        .autocorrectionDisabled(kind == .password)
        .accessibilityLabel(label.map { Text($0) } ?? Text(placeholder))
        .accessibilityHint(errorMessage.map { Text($0) } ?? Text(""))
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        switch kind {
        case .password:
            // Figma has only the eye-slash icon; the revealed-state icon is [Open].
            Button {
                isRevealed.toggle()
            } label: {
                DSIcon.eyeSlash.image(size: 20)
                    .foregroundStyle(iconColor)
                    .frame(width: dsMinimumTapTarget, height: dsMinimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, -12)
            .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
        case .search where !text.isEmpty:
            Button {
                text = ""
            } label: {
                DSIcon.close.image(size: 20)
                    .foregroundStyle(DSColor.Component.textSecondary)
                    .frame(width: dsMinimumTapTarget, height: dsMinimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, -12)
            .accessibilityLabel("Clear search")
        default:
            EmptyView()
        }
    }
}

private struct DSTextFieldPreview: View {
    @State private var empty = ""
    @State private var room = "Saturday at Blok M"
    @State private var password = "secret-password"
    @State private var search = "Blok M"
    @State private var caption = "Got lost three times before we found the place, worth it."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Initial").dsTypography(DSTypography.smallBold).foregroundStyle(DSColor.Camera.leather)
                DSTextField("Room name", placeholder: "Saturday hangout", text: .constant(""))
                DSTextField("Password", placeholder: "At least 8 characters", text: .constant(""), kind: .password)
                DSTextField(placeholder: "Search scrapbooks", text: .constant(""), kind: .search)
                DSTextField("Caption", placeholder: "What happened in this photo?", text: .constant(""), kind: .caption)

                Text("Filled · focused").dsTypography(DSTypography.smallBold).foregroundStyle(DSColor.Camera.leather)
                DSTextField("Room name", placeholder: "Saturday hangout", text: $room)
                DSTextField("Password", placeholder: "At least 8 characters", text: $password, kind: .password)
                DSTextField(placeholder: "Search scrapbooks", text: $search, kind: .search)
                DSTextField("Caption", placeholder: "What happened in this photo?", text: $caption, kind: .caption)

                Text("Error").dsTypography(DSTypography.smallBold).foregroundStyle(DSColor.Camera.leather)
                DSTextField(
                    "Room name",
                    placeholder: "Saturday hangout",
                    text: $empty,
                    errorMessage: "Give your room a name so friends know what it’s for."
                )
            }
            .padding()
        }
        .background(DSColor.Paper.normal)
    }
}

#Preview("Text fields") {
    DSTextFieldPreview()
}
