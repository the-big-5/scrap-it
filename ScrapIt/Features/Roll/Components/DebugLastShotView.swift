#if DEBUG
import Photos
import PhotosUI
import SwiftUI
import UIKit

/// DEBUG builds only: shows the last shot taken on this device so the team can check the filter
/// and the Live Photo. Long press plays the Live Photo (from local files, no Photos permission).
/// This is an exception to F3 ("nobody sees photos during the roll") for debugging.
struct DebugLastShotView: View {
    let photo: ScrapPhoto?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let photo {
                    VStack(spacing: 12) {
                        LivePhotoPlayerView(imageData: photo.imageData, movieData: photo.livePhotoMovieData)
                            .aspectRatio(4 / 3, contentMode: .fit)
                        Text(statusText(for: photo))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    Text("No shot taken yet on this device.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Debug: last shot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func statusText(for photo: ScrapPhoto) -> String {
        if let movie = photo.livePhotoMovieData {
            let size = ByteCountFormatter.string(fromByteCount: Int64(movie.count), countStyle: .file)
            return "Live Photo (\(size) movie). Long press to play."
        }
        return "Still photo only (Live off, unsupported, or the movie is still processing)."
    }
}

/// `PHLivePhotoView` built from the still and movie data; falls back to the still image.
private struct LivePhotoPlayerView: UIViewRepresentable {
    let imageData: Data
    let movieData: Data?

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
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
            imageView.contentMode = .scaleAspectFit
            imageView.frame = view.bounds
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(imageView)
            return
        }
        let folder = FileManager.default.temporaryDirectory.appending(path: "DebugLivePhoto-\(UUID().uuidString)")
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
            contentMode: .aspectFit
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
#endif
