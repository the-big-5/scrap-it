import SwiftUI

struct CameraRollMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var flowViewModel: RollFlowViewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrapTheme.creamBackground
                .ignoresSafeArea()

            // Blurred Home shelves background per Figma node 670:5276
            ShelfView(
                scrapbooks: [],
                onTapCamera: {},
                onTapScrapbook: { _ in }
            )
            .blur(radius: 14)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                // Header
                ZStack {
                    Text("Camera Roll")
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

                Spacer()
                    .frame(height: 158)

                // Crisp foreground camera + action buttons
                VStack(alignment: .leading, spacing: 26) {
                    RetroCameraIllustration(scale: 0.68, showShadowPlate: false)
                        .padding(.leading, 10)

                    VStack(spacing: 18) {
                        Button("Create Roll") {
                            flowViewModel.startCreateRollWizard()
                        }
                        .buttonStyle(OffsetPillButtonStyle())
                        .frame(width: 218)

                        Button("Join a Roll") {
                            flowViewModel.openJoinRoll()
                        }
                        .buttonStyle(OffsetPillButtonStyle())
                        .frame(width: 218)
                    }
                }
                .padding(.leading, 44)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
