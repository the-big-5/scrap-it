import AuthenticationServices
import SwiftData
import SwiftUI

struct WelcomeSignInView: View {
    @Environment(\.modelContext) private var modelContext
    var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            ScrapTheme.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 54)

                // LOGO placeholder box per Figma node 676:3703
                Text("LOGO")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(ScrapTheme.charcoal)
                    .frame(width: 210, height: 48)
                    .background(Color(red: 0.906, green: 0.910, blue: 0.914))

                Spacer()

                RetroCameraIllustration(scale: 1.05, showShadowPlate: true)
                    .padding(.bottom, 28)

                VStack(spacing: 16) {
                    Text("Shoot together.\nKeep it forever.")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(ScrapTheme.charcoal)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    Text("Sign in to start a shared roll with friends and\nkeep every scrapbook on your shelf.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(ScrapTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 28)
                }

                Spacer()

                VStack(spacing: 18) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName]
                    } onCompletion: { result in
                        authViewModel.handleSignInWithAppleCompletion(
                            result: result,
                            modelContext: modelContext
                        )
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .clipShape(Capsule())
                    .padding(.horizontal, 24)

                    Text(termsAttributedString)
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 28)
            }
        }
    }

    private var termsAttributedString: AttributedString {
        var result = AttributedString("By continuing, you agree to our ")
        result.foregroundColor = ScrapTheme.secondaryText

        var terms = AttributedString("Terms of Use")
        terms.foregroundColor = ScrapTheme.charcoal
        terms.font = .system(size: 12, weight: .semibold)
        result.append(terms)

        var andText = AttributedString(" and ")
        andText.foregroundColor = ScrapTheme.secondaryText
        result.append(andText)

        var privacy = AttributedString("Privacy\nPolicy.")
        privacy.foregroundColor = ScrapTheme.charcoal
        privacy.font = .system(size: 12, weight: .semibold)
        result.append(privacy)

        return result
    }
}
