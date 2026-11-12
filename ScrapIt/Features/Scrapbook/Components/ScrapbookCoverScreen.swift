import SwiftUI

/// The closed book after Done (change 026, Figma 1515:29509 host, 1563:33405 participant, 1563:33594 finished):
/// the front cover with its color and decorations on the mat, Editing Progress and "⋯" at the top right, and the
/// buttons for this person underneath. Tapping the book opens it read-only.
struct ScrapbookCoverScreen: View {
    let viewModel: ScrapbookViewModel

    var body: some View {
        ZStack {
            CoverCuttingMat()

            GeometryReader { geometry in
                let scale = ScrapbookEditorLayout.coverScale(for: geometry.size)
                coverBook(width: 340 * scale)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - (UIDevice.current.userInterfaceIdiom == .pad ? 40 : 10 * scale))
            }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Spacer()
                    SpreadEditorButton(icon: .asset("ScrapbookPeople", template: false), width: 46,
                                       accessibilityLabel: "Editing progress") {
                        viewModel.isEditingProgressPresented = true
                    }
                    Menu {
                        // Both come later: video export in its own change, Share still undecided [Open].
                        Button {} label: { Label("Save as Video", systemImage: "square.and.arrow.down") }
                        Button {} label: { Label("Share", systemImage: "square.and.arrow.up") }
                    } label: {
                        CircleIconLabel(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More")
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)

                Spacer()

                VStack(spacing: 8) {
                    switch viewModel.coverActions {
                    case .host:
                        Button("Edit Cover", action: viewModel.editCover)
                            .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
                        Button("Save Scrapbook", action: viewModel.requestSave)
                            .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
                    case .participant:
                        Button("Edit Cover", action: viewModel.editCover)
                            .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
                        Button("Done Editing", action: viewModel.doneEditing)
                            .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
                    case .finished:
                        Button("Back to Home", action: viewModel.backToHome)
                            .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
                    }
                }
                .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 358 : .infinity)
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
    }

    /// The front cover: its material, then its decorations (read only).
    private func coverBook(width: CGFloat) -> some View {
        ZStack {
            BookCoverArt(colorHex: viewModel.coverColorHex)
            if let front = viewModel.coverPage(.front) {
                ScrapbookPageView(page: front, photos: viewModel.photosByID, photoAspect: viewModel.photoAspect(for:),
                                  aspectRatio: ScrapbookPage.Role.front.aspectRatio, drawsBackground: false)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: width / ScrapbookPage.Role.front.aspectRatio)
        .contentShape(Rectangle())
        .onTapGesture(perform: viewModel.openReadOnlyBook)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(viewModel.title) cover")
        .accessibilityHint("Tap to read the pages.")
        .accessibilityAddTraits(.isButton)
    }
}
