import SwiftUI

/// A scrapbook photo opened full screen by a double tap (change 022). Tap or Close to go back.
struct ScrapbookPhotoViewer: View {
    let photo: ScrapPhoto
    let onClose: () -> Void
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: onClose)

            Button("Close", action: onClose)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(20)
        }
        .task(id: photo.id) {
            image = await ScrapbookImageLoader.shared.image(for: photo.id, data: photo.imageData, pixelSize: 1600)
        }
    }
}
