import SwiftUI

/// Join Roll (change 019, Figma 1187:9697): AirDrop hint with the invite illustration, then the 6-character code.
/// One hidden text field holds the whole code; the boxes only show it, so backspace, editing and paste work.
struct JoinRollView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isCodeFocused: Bool

    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    var body: some View {
        ZStack(alignment: .top) {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("Join Roll")
                        .font(.headline)
                        .foregroundStyle(DSColor.Brand.primary.color)
                    HStack {
                        BackCircleButton {
                            dismiss()
                        }
                        .accessibilityLabel("Back")
                        Spacer()
                    }
                }
                .padding(.top, 4)

                Image("InviteHandshake")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 376)
                    .padding(.top, 4)
                    .accessibilityHidden(true)

                Text("Turn on AirDrop to accept the invite")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color.black)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                Divider()
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 14)

                Spacer()

                Button("Join") {
                    isCodeFocused = false
                    Task {
                        await flowViewModel.submitJoinCode(
                            currentUser: currentUser
                        )
                    }
                }
                .buttonStyle(OffsetPillButtonStyle())
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 22)
        }
        .navigationBarBackButtonHidden(true)
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

            HStack(spacing: 5) {
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
        .frame(height: 58)
    }
}
