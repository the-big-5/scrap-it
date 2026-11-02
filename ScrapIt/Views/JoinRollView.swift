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
            ScrapTheme.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header per Figma node 725:6659
                ZStack {
                    Text("Join Roll")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ScrapTheme.charcoal)

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
                    .foregroundStyle(ScrapTheme.charcoal)
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
                    .foregroundStyle(ScrapTheme.charcoal)
                    .padding(.bottom, 10)

                Text("Enter code")
                    .font(.system(size: 17))
                    .foregroundStyle(ScrapTheme.charcoal)
                    .padding(.bottom, 12)

                // 6 single-character code boxes
                HStack(spacing: 6) {
                    ForEach(0..<6, id: \.self) { index in
                        TextField("", text: codeBinding(for: index))
                            .font(.system(size: 24, weight: .semibold, design: .monospaced))
                            .foregroundStyle(ScrapTheme.charcoal)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($focusedBox, equals: index)
                            .frame(width: 48, height: 58)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(ScrapTheme.charcoal, lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.bottom, 14)

                if let errorMessage = flowViewModel.joinErrorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ScrapTheme.indicatorRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer()

                Button("Join") {
                    Task {
                        await flowViewModel.joinRollWithCode(
                            code: flowViewModel.enteredJoinCode,
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
                guard index < flowViewModel.joinCodeCharacters.count else { return "" }
                return flowViewModel.joinCodeCharacters[index]
            },
            set: { newValue in
                let upper = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                if upper.count > 1 {
                    // Support pasting full 6-character code
                    let chars = Array(upper.prefix(6))
                    for (offset, ch) in chars.enumerated() where offset < 6 {
                        flowViewModel.joinCodeCharacters[offset] = String(ch)
                    }
                    focusedBox = min(5, chars.count - 1)
                } else {
                    let single = String(upper.suffix(1))
                    flowViewModel.joinCodeCharacters[index] = single
                    if !single.isEmpty && index < 5 {
                        focusedBox = index + 1
                    }
                }
            }
        )
    }
}
