import SwiftUI

/// Back from the book view asks first (change 025, Figma 1533:25816): a paper card held by washi tape, with the star
/// character. The copy is still the Figma placeholder until copywriting is ready [Open].
struct BookBackConfirmation: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Image("BookConfirmStar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 86, height: 90)
                        .accessibilityHidden(true)
                    Text("Back to … ?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(DSColor.Brand.primary.color)
                    Text("Your scrapbook can be saved and continue to be edited later apalah")
                        .font(.system(size: 14))
                        .foregroundStyle(DSColor.Component.textSecondary.color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 16) {
                    Button("Cancel", action: onCancel)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DSColor.Brand.primary.color)
                        .frame(width: 108, height: 52)
                        .background(DSColor.Kraft.light.color, in: Capsule())
                        .buttonStyle(.plain)
                    Button("Yes", action: onConfirm)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DSColor.Kraft.light.color)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(DSColor.Brand.primary.color, in: Capsule())
                        .buttonStyle(.plain)
                }
            }
            .padding(22)
            .frame(width: 337)
            .background(DSColor.Paper.normal.color, in: RoundedRectangle(cornerRadius: 32))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            .overlay(alignment: .top) {
                Image("BookConfirmWashi")
                    .resizable()
                    .frame(width: 98, height: 35)
                    .offset(y: -14)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .contain)
        }
        .transition(.opacity)
    }
}
