import SwiftUI

/// Roll Reveal (change 021): envelope → tear → scattered photos / Tidy Up grid → detail → Start Scrapbook.
struct RollRevealView: View {
    @State private var viewModel: RollRevealViewModel
    /// The photos have flown out of the envelope (drives the spill animation after the tear).
    @State private var hasSpilled: Bool

    init(viewModel: RollRevealViewModel) {
        _viewModel = State(initialValue: viewModel)
        _hasSpilled = State(initialValue: viewModel.isTorn)
    }

    var body: some View {
        GeometryReader { proxy in
            let matSize = proxy.size
            let envelopeCenter = CGPoint(x: matSize.width / 2, y: matSize.height / 2 + 13)

            ZStack {
                Image("RevealCuttingMat")
                    .resizable()
                    .scaledToFill()
                    .frame(width: matSize.width, height: matSize.height)
                    .clipped()
                    .accessibilityHidden(true)

                if viewModel.stage == .tidy {
                    DSColor.Kraft.lightActive.color
                        .transition(.opacity)
                }

                RevealEnvelopeView(
                    title: viewModel.rollName,
                    subtitle: viewModel.labelText,
                    isTorn: viewModel.isTorn,
                    canTear: viewModel.canTear,
                    arrivalCount: viewModel.arrivalCount,
                    onTear: viewModel.tear
                )
                .opacity(hasSpilled ? 0 : 1)
                .offset(y: hasSpilled ? 60 : 0)
                .position(envelopeCenter)

                if let text = envelopeText {
                    Text(text)
                        .dsTypography(DSTypography.Handwritten.normalRegular)
                        .foregroundStyle(DSColor.Paper.light.color)
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                        .position(x: envelopeCenter.x, y: envelopeCenter.y + RevealEnvelopeView.size.height / 2 + 34)
                        .transition(.opacity)
                        .id(text)
                }

                if viewModel.isTorn && viewModel.stage != .tidy {
                    scatteredPhotos(from: envelopeCenter)
                }

                if viewModel.stage == .tidy {
                    tidyGrid
                        .transition(.opacity)
                }
            }
            .onAppear { viewModel.setMatSize(matSize) }
            .onChange(of: matSize) { _, size in viewModel.setMatSize(size) }
        }
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            if viewModel.isTorn {
                Button(viewModel.tidyButtonTitle) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        viewModel.toggleTidy()
                    }
                }
                .buttonStyle(OffsetPillButtonStyle(shadowOffset: 4, height: 44, fontSize: 18, fontWeight: .semibold))
                .frame(width: 106)
                .padding(.trailing, 16)
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isTorn {
                Button("Start Scrapbook", action: viewModel.startScrapbook)
                    .buttonStyle(OffsetPillButtonStyle())
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
        .overlay {
            if let photo = viewModel.selectedPhoto {
                RevealPhotoDetail(
                    photo: photo,
                    isSaving: viewModel.isSaving,
                    onSave: { Task { await viewModel.saveSelected() } },
                    onClose: { withAnimation(.easeOut(duration: 0.2)) { viewModel.closeDetail() } }
                )
                .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if let message = viewModel.saveMessage {
                Text(message)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DSColor.Paper.light.color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(DSColor.Brand.primary.color.opacity(0.9), in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(1.8))
                        withAnimation { viewModel.clearSaveMessage() }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.saveMessage)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.isTorn) { _, torn in
            guard torn else { return }
            withAnimation(.easeOut(duration: 0.45).delay(0.2)) {
                hasSpilled = true
            }
        }
        .task { await viewModel.observePhotos() }
        .task { await viewModel.waitForTearUnlock() }
        .animation(.easeInOut(duration: 0.3), value: envelopeText)
        .task(id: viewModel.showsReadyText) {
            guard viewModel.showsReadyText else { return }
            try? await Task.sleep(for: RollRevealViewModel.readyTextDuration)
            viewModel.hideReadyText()
        }
    }

    /// "Printing your photos…" while photos arrive, then "Your photos are ready!" for a moment (change 024).
    private var envelopeText: String? {
        if viewModel.isDeveloping { return RollRevealViewModel.printingText }
        if viewModel.showsReadyText && !viewModel.isTorn { return RollRevealViewModel.readyText }
        return nil
    }

    /// Photos fly from the envelope to their spot on the mat, one after another.
    private func scatteredPhotos(from envelopeCenter: CGPoint) -> some View {
        ForEach(Array(viewModel.photos.enumerated()), id: \.element.id) { index, photo in
            let placement = viewModel.placements[photo.id]
            RevealScatteredPhoto(
                photo: photo,
                onDragStart: { viewModel.bringToFront(photo.id) },
                onDragEnd: { viewModel.move(photo.id, by: $0) },
                onTap: {
                    withAnimation(.easeOut(duration: 0.2)) { viewModel.select(photo.id) }
                }
            )
            .rotationEffect(.degrees(hasSpilled ? placement?.rotation ?? 0 : 0))
            .scaleEffect(hasSpilled ? 1 : 0.4)
            .position(hasSpilled ? placement?.center ?? envelopeCenter : envelopeCenter)
            .zIndex(Double(viewModel.stackIndex(of: photo.id)))
            .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.2 + Double(index) * 0.03), value: hasSpilled)
        }
    }

    private var tidyGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(viewModel.gridPhotos) { photo in
                    RevealGridPhoto(photo: photo, time: viewModel.timeText(for: photo))
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) { viewModel.select(photo.id) }
                        }
                }
            }
            .padding(.horizontal, 19)
            .safeAreaPadding(.top, 120)
            .safeAreaPadding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }
}
