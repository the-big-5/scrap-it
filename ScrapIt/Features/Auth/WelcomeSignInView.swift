import AuthenticationServices
import SwiftUI

struct WelcomeSignInView: View {
    var authViewModel: AuthViewModel
    var onSignedIn: (() -> Void)? = nil

    var body: some View {
        ZStack {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                collage

                Spacer()

                VStack(spacing: 16) {
                    if let message = authViewModel.welcomeMessage {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundStyle(DSColor.Component.inputError.color)
                            .multilineTextAlignment(.center)
                    }

                    SignInWithAppleButton(.signIn) { request in
                        authViewModel.beginSignIn()
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        authViewModel.handleSignInWithAppleCompletion(
                            result: result
                        )
                        if authViewModel.isSignedIn {
                            onSignedIn?()
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(Capsule())
                    .disabled(authViewModel.isOffline)
                    .opacity(authViewModel.isOffline ? 0.5 : 1)

                    Text(termsAttributedString)
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
            }
        }
    }

    private var collage: some View {
        ZStack {
            ForEach(Self.collageSprites) { sprite in
                let baseImage = Image(sprite.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: sprite.width, height: sprite.height)
                    .rotationEffect(.degrees(sprite.rotationDegrees))

                if sprite.hasShadow {
                    baseImage
                        .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 4)
                        .position(x: sprite.centerX, y: sprite.centerY)
                } else {
                    baseImage
                        .position(x: sprite.centerX, y: sprite.centerY)
                }
            }
        }
        .frame(width: 315, height: 301)
    }

    private var termsAttributedString: AttributedString {
        var result = AttributedString("By continuing, you agree to our ")
        result.foregroundColor = DSColor.Component.textSecondary.color

        var terms = AttributedString("Terms of Use")
        terms.foregroundColor = DSColor.Brand.primary.color
        terms.font = .system(size: 13, weight: .semibold)
        result.append(terms)

        var andText = AttributedString(" and ")
        andText.foregroundColor = DSColor.Component.textSecondary.color
        result.append(andText)

        var privacy = AttributedString("Privacy Policy.")
        privacy.foregroundColor = DSColor.Brand.primary.color
        privacy.font = .system(size: 13, weight: .semibold)
        result.append(privacy)

        return result
    }
}

private extension WelcomeSignInView {
    struct CollageSprite: Identifiable {
        let id: String
        let imageName: String
        let width: CGFloat
        let height: CGFloat
        let rotationDegrees: Double
        let centerX: CGFloat
        let centerY: CGFloat
        let hasShadow: Bool

        init(
            imageName: String,
            width: CGFloat,
            height: CGFloat,
            rotationDegrees: Double = 0,
            centerX: CGFloat,
            centerY: CGFloat,
            hasShadow: Bool = false
        ) {
            self.id = imageName
            self.imageName = imageName
            self.width = width
            self.height = height
            self.rotationDegrees = rotationDegrees
            self.centerX = centerX
            self.centerY = centerY
            self.hasShadow = hasShadow
        }
    }

    // Coordinates match Figma node 1545:40827 (315x301 collage frame anchored at 43, 255).
    static let collageSprites: [CollageSprite] = [
        CollageSprite(
            imageName: "ToolboxEmptyStarburst",
            width: 79.40,
            height: 126.83,
            rotationDegrees: 19.3,
            centerX: 240.32,
            centerY: 72.99
        ),
        CollageSprite(
            imageName: "SignInPhotoBack",
            width: 54.42,
            height: 64.37,
            centerX: 138.34,
            centerY: 223.46
        ),
        CollageSprite(
            imageName: "SignInPhotoFront",
            width: 48.47,
            height: 58.17,
            centerX: 135.76,
            centerY: 225.86
        ),
        CollageSprite(
            imageName: "RollEmptyStarTop",
            width: 65,
            height: 83,
            centerX: 153.50,
            centerY: 58.50
        ),
        CollageSprite(
            imageName: "DeskDisposableCamera",
            width: 199.28,
            height: 149.35,
            rotationDegrees: -5.7,
            centerX: 138.74,
            centerY: 120.59,
            hasShadow: true
        ),
        CollageSprite(
            imageName: "RollEmptyStarLeft",
            width: 66,
            height: 70,
            centerX: 33.00,
            centerY: 178.00
        ),
        CollageSprite(
            imageName: "RollEmptyStarRight",
            width: 59,
            height: 125,
            centerX: 285.50,
            centerY: 226.50
        ),
        CollageSprite(
            imageName: "ToolboxEmptyNotebook",
            width: 104.46,
            height: 154.31,
            rotationDegrees: 24.9,
            centerX: 227.22,
            centerY: 185.15
        ),
        CollageSprite(
            imageName: "DeskFilmRollYellow",
            width: 101,
            height: 75,
            centerX: 89.50,
            centerY: 176.50,
            hasShadow: true
        ),
        CollageSprite(
            imageName: "ToolboxEmptyRuler",
            width: 40.20,
            height: 152.50,
            rotationDegrees: -73.8,
            centerX: 105.87,
            centerY: 260.43
        ),
    ]
}
