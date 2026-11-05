import SwiftData
import SwiftUI

struct JoinRollView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var focusedBox: Int?

    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    var body: some View {
        ZStack {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header per Figma node 725:6659
                ZStack {
                    Text("Join Roll")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DSColor.Brand.primary.color)

                    HStack {
                        BackCircleButton {
                            dismiss()
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 34)

                Text("Scan QR")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(DSColor.Brand.primary.color)
                    .padding(.bottom, 10)

                // Scan QR camera box per Figma node 725:6659
                ZStack {
                    Rectangle()
                        .fill(Color(red: 0.87, green: 0.875, blue: 0.87))
                        .frame(width: 246, height: 246)

                    Image(systemName: "camera")
                        .font(.system(size: 78, weight: .regular))
                        .foregroundStyle(Color.black)
                }
                .padding(.bottom, 22)

                Text("or")
                    .font(.system(size: 17))
                    .foregroundStyle(DSColor.Brand.primary.color)
                    .padding(.bottom, 10)

                Text("Enter code")
                    .font(.system(size: 17))
                    .foregroundStyle(DSColor.Brand.primary.color)
                    .padding(.bottom, 12)

                // 6 single-character code boxes
                HStack(spacing: 6) {
                    ForEach(0..<6, id: \.self) { index in
                        TextField("", text: codeBinding(for: index))
                            .font(.system(size: 24, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DSColor.Brand.primary.color)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($focusedBox, equals: index)
                            .frame(width: 48, height: 58)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(DSColor.Paper.light.color)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(DSColor.Brand.primary.color, lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.bottom, 14)

                if let errorMessage = flowViewModel.joinErrorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DSColor.State.error.color)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer()

                Button("Join") {
                    Task {
                        await flowViewModel.submitJoinCode(
                            currentUser: currentUser,
                            modelContext: modelContext
                        )
                    }
                }
                .buttonStyle(OffsetPillButtonStyle())
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
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
