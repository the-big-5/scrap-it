import SwiftUI

struct JoinRollView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedBox: Int?

    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    var body: some View {
        ZStack(alignment: .top) {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            RollRoomHeader()

            VStack(alignment: .leading, spacing: 0) {
                // Toolbar per Figma node 725:6659
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
                .padding(.horizontal, 16)
                .padding(.top, 4)

                // "Enter code" aligned with the centered 6 code boxes (Figma x 41–360)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter code")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color.black)

                    HStack(spacing: 5) {
                        ForEach(0..<6, id: \.self) { index in
                            RollCodeBox {
                                TextField("", text: codeBinding(for: index))
                                    .multilineTextAlignment(.center)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .focused($focusedBox, equals: index)
                            }
                        }
                    }

                    if let errorMessage = flowViewModel.joinErrorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DSColor.State.error.color)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)

                Spacer()

                Button("Join") {
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

    private func codeBinding(for index: Int) -> Binding<String> {
        Binding(
            get: {
                flowViewModel.joinCodeCharacter(at: index)
            },
            set: { newValue in
                if let nextFocus = flowViewModel.updateJoinCode(at: index, with: newValue) {
                    focusedBox = nextFocus
                }
            }
        )
    }
}
