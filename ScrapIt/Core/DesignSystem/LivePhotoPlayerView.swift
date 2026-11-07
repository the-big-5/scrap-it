import Photos
import PhotosUI
import SwiftUI
import UIKit

/// `PHLivePhotoView` built from the still and movie data; falls back to the still image.
/// Long press plays the Live Photo like the Photos app (local files, no Photos permission).
/// Used by the Scrapbook grid (change 012) and the DEBUG last-shot viewer.
struct LivePhotoPlayerView: UIViewRepresentable {
    let imageData: Data
    let movieData: Data?
    var contentMode: UIView.ContentMode = .scaleAspectFit

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = contentMode
        view.clipsToBounds = true
        load(into: view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIView(_ uiView: PHLivePhotoView, coordinator: Coordinator) {
        coordinator.removeFiles()
    }

    private func load(into view: PHLivePhotoView, coordinator: Coordinator) {
        let placeholder = UIImage(data: imageData)
        guard let movieData else {
            let imageView = UIImageView(image: placeholder)
            imageView.contentMode = contentMode
            imageView.frame = view.bounds
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(imageView)
            return
        }
        let folder = FileManager.default.temporaryDirectory.appending(path: "LivePhoto-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let imageURL = folder.appending(path: "photo.jpg")
        let movieURL = folder.appending(path: "photo.mov")
        do {
            try imageData.write(to: imageURL)
            try movieData.write(to: movieURL)
        } catch {
            return
        }
        coordinator.folder = folder
        PHLivePhoto.request(
            withResourceFileURLs: [imageURL, movieURL],
            placeholderImage: placeholder,
            targetSize: .zero,
            contentMode: contentMode == .scaleAspectFill ? .aspectFill : .aspectFit
        ) { livePhoto, _ in
            if let livePhoto {
                view.livePhoto = livePhoto
            }
        }
    }

    final class Coordinator {
        var folder: URL?

        func removeFiles() {
            if let folder {
                try? FileManager.default.removeItem(at: folder)
            }
        }
    }
}
