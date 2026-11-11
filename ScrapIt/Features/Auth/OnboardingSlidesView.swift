import SwiftUI

struct OnboardingSlidesView: View {
    var onComplete: () -> Void

    @State private var currentSlide: Int = 0
    @State private var dragOffset: CGFloat = 0

    static let slideThreeButtonTitle = "Let's Try It"

    init(initialSlide: Int = 0, onComplete: @escaping () -> Void) {
        self._currentSlide = State(initialValue: initialSlide)
        self.onComplete = onComplete
    }

    struct SlideData {
        let title: String
        let description: String
        let buttonTitle: String
    }

    let slides: [SlideData] = [
        SlideData(
            title: "A film camera experience.\nShared with friends.",
            description: "Start a shared roll, take turns capturing your moment, and make every shot count.",
            buttonTitle: "Continue"
        ),
        SlideData(
            title: "Turn your memories into scrapbook.",
            description: "Reveal your photos when the roll is complete, then create and decorate a scrapbook together.",
            buttonTitle: "Continue"
        ),
        SlideData(
            title: "Make memories you can revisit.",
            description: "Keep your completed scrapbooks on your bookshelf and revisit the moments you made together.",
            buttonTitle: slideThreeButtonTitle
        )
    ]

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = max(geometry.size.width, 1)
            let progress = effectiveProgress(screenWidth: screenWidth)

            ZStack {
                DSColor.Kraft.lightActive.color
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 16)

                    // Central animated illustration canvas
                    illustrationCanvas(progress: progress)
                        .frame(maxWidth: .infinity)
                        .frame(height: 310)

                    Spacer(minLength: 20)

                    // Text descriptions (fades & parallax in sync with progress)
                    textTransitionView(progress: progress)
                        .frame(height: 120)
                        .padding(.horizontal, 24)

                    Spacer(minLength: 24)

                    // Bottom controls (Page dots + Primary button)
                    VStack(spacing: 24) {
                        pageIndicatorView(progress: progress)

                        Button {
                            if currentSlide < slides.count - 1 {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                                    currentSlide += 1
                                }
                            } else {
                                onComplete()
                            }
                        } label: {
                            Text(Self.buttonTitle(for: progress))
                                .animation(.easeInOut(duration: 0.2), value: Self.buttonTitle(for: progress))
                        }
                        .buttonStyle(
                            OffsetPillButtonStyle(
                                backgroundColor: DSColor.Paper.light.color,
                                foregroundColor: DSColor.Brand.primary.color,
                                shadowOffset: 7,
                                height: 52,
                                fontSize: 18,
                                fontWeight: .bold
                            )
                        )
                        .padding(.horizontal, 22)
                    }
                    .padding(.bottom, 20)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { gesture in
                        dragOffset = gesture.translation.width
                    }
                    .onEnded { gesture in
                        let targetIndex = Self.calculateTargetSlide(
                            currentSlide: currentSlide,
                            translation: gesture.translation.width,
                            velocity: gesture.velocity.width,
                            slideCount: slides.count
                        )

                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            currentSlide = targetIndex
                            dragOffset = 0
                        }
                    }
            )
        }
    }

    // MARK: - Progress & Navigation Logic

    private func effectiveProgress(screenWidth: CGFloat) -> CGFloat {
        Self.calculateEffectiveProgress(
            currentSlide: currentSlide,
            dragOffset: dragOffset,
            screenWidth: screenWidth,
            slideCount: slides.count
        )
    }

    static func buttonTitle(for progress: CGFloat) -> String {
        progress >= 1.5 ? slideThreeButtonTitle : "Continue"
    }

    static func calculateEffectiveProgress(
        currentSlide: Int,
        dragOffset: CGFloat,
        screenWidth: CGFloat,
        slideCount: Int = 3
    ) -> CGFloat {
        let width = max(screenWidth, 1)
        let raw = CGFloat(currentSlide) - (dragOffset / width)
        if raw < 0 {
            return -pow(-raw, 0.75) * 0.35
        } else if raw > CGFloat(slideCount - 1) {
            let overflow = raw - CGFloat(slideCount - 1)
            return CGFloat(slideCount - 1) + pow(overflow, 0.75) * 0.35
        }
        return raw
    }

    static func calculateTargetSlide(
        currentSlide: Int,
        translation: CGFloat,
        velocity: CGFloat,
        slideCount: Int = 3,
        threshold: CGFloat = 45
    ) -> Int {
        if translation < -threshold || velocity < -300 {
            return min(slideCount - 1, currentSlide + 1)
        } else if translation > threshold || velocity > 300 {
            return max(0, currentSlide - 1)
        } else {
            return currentSlide
        }
    }

    // MARK: - Illustration Canvas

    @ViewBuilder
    private func illustrationCanvas(progress: CGFloat) -> some View {
        ZStack {
            // Slide 1 (Camera + Film + Stars)
            slideOneCollage(progress: progress)

            // Slide 2 (Scrapbook + Tools)
            slideTwoCollage(progress: progress)

            // Slide 3 (Bookshelf + Stars)
            slideThreeCollage(progress: progress)
        }
        .frame(width: 360, height: 310)
    }

    // MARK: - Slide 1 Collage (OB1)

    @ViewBuilder
    private func slideOneCollage(progress: CGFloat) -> some View {
        let diff = progress - 0
        let absDiff = abs(diff)

        if absDiff < 1.3 {
            ZStack {
                // Background ribbons
                Image("OnboardingFilmStripTop")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 175, height: 210)
                    .offset(x: 82 + (diff * 20), y: -38 - (diff * 15))
                    .opacity(max(0, 1.0 - absDiff * 1.5))

                Image("OnboardingFilmStripBottom")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 126, height: 198)
                    .offset(x: 108 + (diff * 25), y: -28)
                    .opacity(max(0, 1.0 - absDiff * 1.5))

                // Hero Camera (Card shuffle dynamics)
                Image("OnboardingCamera")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 276, height: 218)
                    .offset(x: diff < 0 ? 0 : -55 * diff, y: 12 + (diff < 0 ? 0 : 35 * diff))
                    .scaleEffect(heroScale(diff: diff))
                    .rotationEffect(.degrees(heroRotation(diff: diff, exitingAngle: -15, enteringAngle: 12)))
                    .opacity(heroOpacity(diff: diff))
                    .zIndex(heroZIndex(diff: diff))

                // Yellow Canister (Top Left) - flips 3D away
                peripheralItem(imageName: "OnboardingFilmCanisterYellow", width: 105, height: 78, baseOffset: CGSize(width: -92, height: -72), diff: diff, angleMultiplier: -1)

                // Red Canister (Bottom Right)
                peripheralItem(imageName: "OnboardingFilmCanisterRed", width: 118, height: 113, baseOffset: CGSize(width: 122, height: 68), diff: diff, angleMultiplier: 1)

                // Dancing Star (Top)
                peripheralItem(imageName: "OnboardingStarHappy", width: 68, height: 86, baseOffset: CGSize(width: 4, height: -105), diff: diff, angleMultiplier: 1)

                // Walking Star (Left)
                peripheralItem(imageName: "OnboardingStarStanding", width: 68, height: 72, baseOffset: CGSize(width: -110, height: -18), diff: diff, angleMultiplier: -1)

                // Singing Star (Right)
                peripheralItem(imageName: "OnboardingStarTall", width: 60, height: 128, baseOffset: CGSize(width: 116, height: 14), diff: diff, angleMultiplier: 1)
            }
        }
    }

    // MARK: - Slide 2 Collage (OB2)

    @ViewBuilder
    private func slideTwoCollage(progress: CGFloat) -> some View {
        let diff = progress - 1
        let absDiff = abs(diff)

        if absDiff < 1.3 {
            ZStack {
                // Hero Notebook (Card shuffle dynamics)
                Image("OnboardingNotebook")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 175, height: 206)
                    .offset(x: -22 + (diff > 0 ? -55 * diff : 50 * -diff), y: 4 + (diff > 0 ? 35 * diff : -25 * -diff))
                    .scaleEffect(heroScale(diff: diff))
                    .rotationEffect(.degrees(heroRotation(diff: diff, exitingAngle: -15, enteringAngle: 14)))
                    .opacity(heroOpacity(diff: diff))
                    .zIndex(heroZIndex(diff: diff))

                // Photos attached over bottom of notebook
                Image("OnboardingPhotoPrints")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .offset(x: 18 + (diff > 0 ? -55 * diff : 50 * -diff), y: 42 + (diff > 0 ? 35 * diff : -25 * -diff))
                    .scaleEffect(heroScale(diff: diff))
                    .rotationEffect(.degrees(heroRotation(diff: diff, exitingAngle: -15, enteringAngle: 14)))
                    .opacity(heroOpacity(diff: diff))
                    .zIndex(heroZIndex(diff: diff) + 1)

                // Starburst Sticker (Top Right)
                peripheralItem(imageName: "OnboardingStarburst", width: 118, height: 147, baseOffset: CGSize(width: 95, height: -88), diff: diff, angleMultiplier: 1)

                // Blue Scissors (Bottom Right)
                peripheralItem(imageName: "OnboardingScissors", width: 124, height: 72, baseOffset: CGSize(width: 52, height: 55), diff: diff, angleMultiplier: -1)

                // Green Pencil (Right)
                peripheralItem(imageName: "OnboardingPencil", width: 120, height: 142, baseOffset: CGSize(width: 148, height: 22), diff: diff, angleMultiplier: 1)

                // Orange Ruler (Bottom Left)
                peripheralItem(imageName: "OnboardingRuler", width: 80, height: 63, baseOffset: CGSize(width: -62, height: 52), diff: diff, angleMultiplier: -1)
            }
        }
    }

    // MARK: - Slide 3 Collage (OB3)

    @ViewBuilder
    private func slideThreeCollage(progress: CGFloat) -> some View {
        let diff = progress - 2
        let absDiff = abs(diff)

        if absDiff < 1.3 {
            ZStack {
                // Hero Books Stack (Card shuffle dynamics)
                Image("OnboardingBooks")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 148, height: 180)
                    .offset(x: diff > 0 ? 0 : 50 * -diff, y: 16 + (diff > 0 ? 0 : -25 * -diff))
                    .scaleEffect(heroScale(diff: diff))
                    .rotationEffect(.degrees(heroRotation(diff: diff, exitingAngle: -15, enteringAngle: 14)))
                    .opacity(heroOpacity(diff: diff))
                    .zIndex(heroZIndex(diff: diff))

                // Star standing on top of books
                peripheralItem(imageName: "OnboardingStarTall", width: 62, height: 132, baseOffset: CGSize(width: -14, height: -96), diff: diff, angleMultiplier: 1)

                // Mascot Happy (Bottom Left)
                peripheralItem(imageName: "OnboardingStarHappy", width: 70, height: 88, baseOffset: CGSize(width: -82, height: 52), diff: diff, angleMultiplier: -1)

                // Mascot Standing (Bottom Right)
                peripheralItem(imageName: "OnboardingStarStanding", width: 70, height: 74, baseOffset: CGSize(width: 78, height: 52), diff: diff, angleMultiplier: 1)

                // Sparkles (Top Right)
                peripheralItem(imageName: "OnboardingSparkles", width: 96, height: 120, baseOffset: CGSize(width: 88, height: -52), diff: diff, angleMultiplier: -1)
            }
        }
    }

    // MARK: - Motion Helper Computations

    private func heroScale(diff: CGFloat) -> CGFloat {
        let absDiff = abs(diff)
        return max(0.68, 1.0 - (absDiff * 0.30))
    }

    private func heroRotation(diff: CGFloat, exitingAngle: Double, enteringAngle: Double) -> Double {
        if diff > 0 {
            // Exiting forward: tilts backward
            return exitingAngle * min(Double(diff), 1.0)
        } else {
            // Entering from behind: tilts forward
            return enteringAngle * min(Double(-diff), 1.0)
        }
    }

    private func heroOpacity(diff: CGFloat) -> Double {
        let absDiff = abs(diff)
        if absDiff <= 0.65 {
            return 1.0
        }
        return max(0.0, Double(1.0 - (absDiff - 0.65) * 2.85))
    }

    private func heroZIndex(diff: CGFloat) -> Double {
        let absDiff = abs(diff)
        return max(1.0, 10.0 - (Double(absDiff) * 5.0))
    }

    @ViewBuilder
    private func peripheralItem(imageName: String, width: CGFloat, height: CGFloat, baseOffset: CGSize, diff: CGFloat, angleMultiplier: Double) -> some View {
        let absDiff = abs(diff)
        let flipAngle = Double(diff) * 180.0 * angleMultiplier
        let scale = max(0.3, 1.0 - absDiff * 0.65)
        let opacity = absDiff >= 0.5 ? 0.0 : max(0.0, 1.0 - absDiff * 2.0)
        let explosionPush = sin(min(absDiff, 1.0) * .pi) * 25.0
        let normX = baseOffset.width == 0 ? 0 : baseOffset.width / abs(baseOffset.width)
        let normY = baseOffset.height == 0 ? 0 : baseOffset.height / abs(baseOffset.height)

        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: width, height: height)
            .scaleEffect(scale)
            .rotation3DEffect(
                .degrees(flipAngle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.7
            )
            .offset(
                x: baseOffset.width + (normX * explosionPush),
                y: baseOffset.height + (normY * explosionPush)
            )
            .opacity(opacity)
            .accessibilityHidden(true)
    }

    // MARK: - Text Transitions

    @ViewBuilder
    private func textTransitionView(progress: CGFloat) -> some View {
        ZStack {
            ForEach(0..<slides.count, id: \.self) { index in
                let diff = progress - CGFloat(index)
                let absDiff = abs(diff)
                let opacity = max(0.0, 1.0 - (absDiff * 1.6))
                let offsetY = -diff * 18

                if absDiff < 1.0 {
                    VStack(spacing: 12) {
                        Text(slides[index].title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(DSColor.Brand.primary.color)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        Text(slides[index].description)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(DSColor.Brand.primary.color)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: 333)
                    }
                    .offset(y: offsetY)
                    .opacity(opacity)
                }
            }
        }
    }

    // MARK: - Page Indicator

    @ViewBuilder
    private func pageIndicatorView(progress: CGFloat) -> some View {
        let activeIndex = Int(round(min(max(progress, 0), CGFloat(slides.count - 1))))

        HStack(spacing: 8) {
            ForEach(0..<slides.count, id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? DSColor.Brand.primary.color : DSColor.Camera.camera.color)
                    .frame(width: 8, height: 8)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            currentSlide = index
                            dragOffset = 0
                        }
                    }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(activeIndex + 1) of \(slides.count)")
    }
}

#Preview {
    OnboardingSlidesView(onComplete: {})
}
