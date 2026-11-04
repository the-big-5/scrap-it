import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

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
