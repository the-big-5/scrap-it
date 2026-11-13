import SwiftUI

/// Join Roll (change 019, Figma 1187:9697): AirDrop hint with the invite illustration, then the 6-character code.
/// One hidden text field holds the whole code; the boxes only show it, so backspace, editing and paste work.
struct JoinRollView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isCodeFocused: Bool

    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    private static let codeBoxWidth: CGFloat = 49
    private static let codeBoxSpacing: CGFloat = 5
    private static let codeBlockWidth: CGFloat =
        CGFloat(RollFlowViewModel.joinCodeLength) * codeBoxWidth
        + CGFloat(max(RollFlowViewModel.joinCodeLength - 1, 0)) * codeBoxSpacing

    var body: some View {
        ZStack(alignment: .top) {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            VStack(spacing: 0) {
                InviteFriendsIllustration()
                    .frame(maxWidth: 376)
                    .padding(.top, 4)

                Text("Turn on AirDrop to accept the invite")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color.black)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                Divider()
                    .overlay(Color(red: 230 / 255, green: 230 / 255, blue: 230 / 255))
                    .padding(.top, 16)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter code")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color.black)

                    codeField

                    if let errorMessage = flowViewModel.joinErrorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DSColor.State.error.color)
                            .padding(.top, 2)
                    }
                }
                .frame(width: Self.codeBlockWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 14)

                Spacer()

                // Disabled until the code is complete, so the only message left is a roll that isn't found
                // (change 081, Figma 1663:46361).
                Button("Join Roll") {
                    isCodeFocused = false
                    Task {
                        await flowViewModel.submitJoinCode(
                            currentUser: currentUser
                        )
                    }
                }
                .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
                .disabled(!flowViewModel.canSubmitJoinCode)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 22)
        }
        .navigationTitle("Join Roll")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(DSColor.Kraft.lightActive.color, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .tint(DSColor.Brand.primary.color)
        .onAppear { flowViewModel.prepareJoin() }
    }

    /// Six boxes over one invisible text field; tapping any box opens the keyboard.
    private var codeField: some View {
        // Boxes start at the same left edge as "Enter code".
        ZStack(alignment: .leading) {
            TextField("", text: Binding(
                get: { flowViewModel.joinCode },
                set: { flowViewModel.updateJoinCode($0) }
            ))
            .keyboardType(.asciiCapable)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .textContentType(.oneTimeCode)
            .focused($isCodeFocused)
            .foregroundStyle(.clear)
            .tint(.clear)
            .opacity(0.02)
            .accessibilityLabel("Roll code")

            HStack(spacing: Self.codeBoxSpacing) {
                ForEach(0..<RollFlowViewModel.joinCodeLength, id: \.self) { index in
                    RollCodeBox {
                        Text(flowViewModel.joinCodeCharacter(at: index))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(DSColor.Brand.primary.color, lineWidth: 2)
                            .opacity(isCodeFocused && index == min(flowViewModel.joinCode.count, RollFlowViewModel.joinCodeLength - 1) ? 1 : 0)
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isCodeFocused = true }
            .accessibilityHidden(true)
        }
        .frame(width: Self.codeBlockWidth, height: 58)
    }
}
