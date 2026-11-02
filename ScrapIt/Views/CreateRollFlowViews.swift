import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

// MARK: - Step 1: Roll Name & Number of Shots (Figma node 675:5671)

struct CreateRollStep1View: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var flowViewModel: RollFlowViewModel

    var body: some View {
        ZStack {
            ScrapTheme.creamBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                ZStack {
                    Text("Create Roll")
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
                .padding(.bottom, 42)

                // Roll Name Input
                VStack(alignment: .leading, spacing: 10) {
                    Text("Give this roll a name")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(ScrapTheme.charcoal)

                    TextField("Value", text: $flowViewModel.draftRollName)
                        .font(.system(size: 16))
                        .foregroundStyle(ScrapTheme.charcoal)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(ScrapTheme.charcoal, lineWidth: 1.2)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 34)

                // Number of Shots Film Strip Selector
                Text("Select the number of shots")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(ScrapTheme.charcoal)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)

                FilmStripShotSelector(selectedCount: $flowViewModel.draftShotCount)

                Spacer()

                Button("Next") {
                    flowViewModel.proceedToFilterStep()
                }
                .buttonStyle(OffsetPillButtonStyle())
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct FilmStripShotSelector: View {
    @Binding var selectedCount: Int
    private let counts = RollFlowViewModel.availableShotCounts

    var body: some View {
        VStack(spacing: 0) {
            FilmSprocketStrip()

            HStack(spacing: 0) {
                ForEach(counts, id: \.self) { count in
                    let isSelected = (selectedCount == count)
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedCount = count
                        }
                    } label: {
                        Text("\(count)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 82)
                            .background(
                                isSelected
                                    ? ScrapTheme.filmStripDark
                                    : ScrapTheme.filmStripUnselected
                            )
                            .overlay(
                                Rectangle()
                                    .stroke(Color.black, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            FilmSprocketStrip()
        }
    }
}

struct FilmSprocketStrip: View {
    var body: some View {
        GeometryReader { geo in
            let holeCount = max(10, Int(geo.size.width / 8))
            ZStack {
                Rectangle()
                    .fill(Color.black)
                HStack(spacing: 3) {
                    ForEach(0..<holeCount, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(ScrapTheme.creamBackground)
                            .frame(width: 4, height: 3)
                    }
                }
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Step 2: Choose a Filter (Figma node 675:5759)

struct CreateRollStep2FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    var body: some View {
        ZStack {
            ScrapTheme.creamBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                ZStack {
                    Text("Create Roll")
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

                Text("Choose a filter")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(ScrapTheme.charcoal)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 18)

                VStack(spacing: 24) {
                    ForEach(RollFilter.allCases) { filter in
                        FilmCanisterFilterRow(
                            filter: filter,
                            isSelected: flowViewModel.draftFilter == filter,
                            onSelect: {
                                withAnimation(.spring(duration: 0.3)) {
                                    flowViewModel.draftFilter = filter
                                }
                            }
                        )
                    }
                }

                Spacer()

                Button("Next") {
                    flowViewModel.createLobbySession(
                        currentUser: currentUser,
                        modelContext: modelContext
                    )
                }
                .buttonStyle(OffsetPillButtonStyle())
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct FilmCanisterFilterRow: View {
    let filter: RollFilter
    let isSelected: Bool
    let onSelect: () -> Void

    private let sampleScenes: [(icon: String, label: String)] = [
        ("person.2.fill", "Friends"),
        ("cup.and.saucer.fill", "Cafe"),
        ("sun.max.fill", "Golden Hr"),
        ("sparkles", "Night Out")
    ]

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 0) {
                // Canister body on the left
                FilmCanisterBadge(filter: filter, isSelected: isSelected)
                    .padding(.leading, 30)
                    .zIndex(1)

                // Horizontal sprocketed film roll with sample carousel frames
                VStack(spacing: 0) {
                    FilmSprocketStrip()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(0..<sampleScenes.count, id: \.self) { index in
                                let sample = sampleScenes[index]
                                ZStack {
                                    Rectangle()
                                        .fill(
                                            isSelected
                                                ? AnyShapeStyle(frameBackground(for: filter, index: index))
                                                : AnyShapeStyle(ScrapTheme.filmStripDark)
                                        )
                                        .frame(width: 96, height: 84)

                                    if isSelected {
                                        VStack(spacing: 6) {
                                            Image(systemName: sample.icon)
                                                .font(.system(size: 22))
                                                .foregroundStyle(frameForeground(for: filter))
                                            Text(sample.label)
                                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(frameForeground(for: filter).opacity(0.85))
                                        }
                                        .transition(.opacity.combined(with: .scale))
                                    }
                                }
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.black, lineWidth: 1.5)
                                )
                            }
                        }
                    }
                    .frame(height: 84)
                    .background(ScrapTheme.filmStripDark)

                    FilmSprocketStrip()
                }
                .offset(x: -6)
            }
            .scaleEffect(isSelected ? 1.0 : 0.97, anchor: .leading)
        }
        .buttonStyle(.plain)
    }

    private func frameBackground(for filter: RollFilter, index: Int) -> LinearGradient {
        switch filter {
        case .cinematicBW400:
            let shade = 0.20 + Double(index % 2) * 0.08
            return LinearGradient(
                colors: [Color(white: shade + 0.12), Color(white: shade)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .colorPrint200:
            return LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.30, blue: 0.20),
                    Color(red: 0.24, green: 0.19, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func frameForeground(for filter: RollFilter) -> Color {
        switch filter {
        case .cinematicBW400:
            return Color(white: 0.92)
        case .colorPrint200:
            return Color(red: 0.99, green: 0.85, blue: 0.52)
        }
    }
}

struct FilmCanisterBadge: View {
    let filter: RollFilter
    let isSelected: Bool

    var body: some View {
        Image(filter == .cinematicBW400 ? "FilterCanisterBW" : "FilterCanisterColor")
            .resizable()
            .scaledToFit()
            .frame(width: 89, height: 142)
            .scaleEffect(isSelected ? 1.03 : 0.96)
    }
}

// MARK: - Step 3: Share Room / Lobby (Figma node 675:5798)

struct CreateRollStep3ShareRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var currentUser: UserProfile
    @Bindable var flowViewModel: RollFlowViewModel

    private var session: CaptureSession? {
        flowViewModel.activeSession
    }

    private var rollCodeCharacters: [String] {
        let code = session?.rollCode ?? "N4B13L"
        return code.map { String($0) }
    }

    var body: some View {
        ZStack {
            ScrapTheme.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("Create Roll")
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

                // Framed QR Code
                QRCodeBracketView(payload: session?.inviteURL.absoluteString ?? "scrapit://join?code=N4B13L")
                    .frame(width: 174, height: 174)
                    .padding(.bottom, 26)

                // Roll Code Boxes
                Text("Roll code:")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(ScrapTheme.charcoal)
                    .padding(.bottom, 10)

                HStack(spacing: 6) {
                    ForEach(Array(rollCodeCharacters.enumerated()), id: \.offset) { _, ch in
                        Text(ch)
                            .font(.system(size: 26, weight: .semibold, design: .monospaced))
                            .foregroundStyle(ScrapTheme.charcoal)
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
                .padding(.bottom, 18)

                Text("or")
                    .font(.system(size: 16))
                    .foregroundStyle(ScrapTheme.charcoal)
                    .padding(.bottom, 14)

                if let inviteURL = session?.inviteURL {
                    ShareLink(
                        item: inviteURL,
                        subject: Text("Join my ScrapIt Roll"),
                        message: Text("Join our shared camera roll with code \(session?.rollCode ?? "")!")
                    ) {
                        Text("Share link")
                            .font(.system(size: 18, weight: .bold))
                            .underline()
                            .foregroundStyle(ScrapTheme.charcoal)
                    }
                    .padding(.bottom, 38)
                }

                // Joined count
                HStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.system(size: 16))
                        .foregroundStyle(ScrapTheme.secondaryText)
                    Text("\(session?.participantIDs.count ?? 1) Joined")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(ScrapTheme.secondaryText)
                }

                Spacer()

                Button("Start Roll") {
                    flowViewModel.startRollCapture(modelContext: modelContext)
                }
                .buttonStyle(OffsetPillButtonStyle())
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct QRCodeBracketView: View {
    let payload: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        ZStack {
            if let cgImage = generateQRCode(from: payload) {
                Image(decorative: cgImage, scale: 1.0, orientation: .up)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(18)
            }

            // Corner bracket overlay matching Figma node 675:5798
            QRCornerBracketsShape()
                .stroke(ScrapTheme.charcoal, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }
    }

    private func generateQRCode(from string: String) -> CGImage? {
        filter.message = Data(string.utf8)
        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        return context.createCGImage(transformed, from: transformed.extent)
    }
}

struct QRCornerBracketsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let len: CGFloat = 34
        let r: CGFloat = 16

        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))

        // Top-right
        path.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + r),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))

        // Bottom-left
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - len))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + len, y: rect.maxY))

        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - r),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - len))

        return path
    }
}
