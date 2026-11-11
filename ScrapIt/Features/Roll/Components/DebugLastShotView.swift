#if DEBUG
import SwiftUI

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
                            .aspectRatio(contentMode: .fit)
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

#endif
