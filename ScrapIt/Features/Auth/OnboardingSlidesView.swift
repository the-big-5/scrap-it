import SwiftUI

struct OnboardingSlidesView: View {
    var onComplete: () -> Void

    @State private var currentSlide: Int = 0

    static let slideThreeButtonTitle = "Let's Try It"

    private struct SlideContent {
        let imageName: String
        let imageWidth: CGFloat
        let imageHeight: CGFloat
        let title: String
        let description: String
        let buttonTitle: String
    }

    private let slides: [SlideContent] = [
        SlideContent(
            imageName: "OnboardingSlideOneIllustration",
            imageWidth: 332,
            imageHeight: 281,
            title: "A film camera experience.\nShared with friends.",
            description: "Start a shared roll, take turns capturing your moment, and make every shot count.",
            buttonTitle: "Continue"
        ),
        SlideContent(
            imageName: "OnboardingSlideTwoIllustration",
            imageWidth: 247,
            imageHeight: 269,
            title: "Turn your memories into scrapbook.",
            description: "Reveal your photos when the roll is complete, then create and decorate a scrapbook together.",
            buttonTitle: "Continue"
        ),
        SlideContent(
            imageName: "OnboardingSlideThreeIllustration",
            imageWidth: 248,
            imageHeight: 298,
            title: "Make memories you can revisit.",
            description: "Keep your completed scrapbooks on your bookshelf and revisit the moments you made together.",
            buttonTitle: slideThreeButtonTitle
        )
    ]

    var body: some View {
        ZStack {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentSlide) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        slideView(for: slides[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 24) {
                    pageIndicatorView

                    Button {
                        if currentSlide < slides.count - 1 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentSlide += 1
                            }
                        } else {
                            onComplete()
                        }
                    } label: {
                        Text(slides[currentSlide].buttonTitle)
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
    }

    @ViewBuilder
    private func slideView(for slide: SlideContent) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            Image(slide.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: slide.imageWidth, height: slide.imageHeight)
                .accessibilityHidden(true)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                Text(slide.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DSColor.Brand.primary.color)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text(slide.description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(DSColor.Brand.primary.color)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 333)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 20)
        }
    }

    private var pageIndicatorView: some View {
        HStack(spacing: 8) {
            ForEach(0..<slides.count, id: \.self) { index in
                Circle()
                    .fill(index == currentSlide ? DSColor.Brand.primary.color : DSColor.Camera.camera.color)
                    .frame(width: 8, height: 8)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentSlide = index
                        }
                    }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentSlide + 1) of \(slides.count)")
    }
}

#Preview {
    OnboardingSlidesView(onComplete: {})
}
