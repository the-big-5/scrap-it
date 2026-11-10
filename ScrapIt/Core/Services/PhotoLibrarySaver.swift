import Foundation
import Photos

/// Saves a roll photo to the user's photo library (change 021).
protocol PhotoLibrarySaving: AnyObject {
    /// A still, or a Live Photo when `movieData` is the photo's paired movie (same content identifier, change 012).
    func save(imageData: Data, movieData: Data?) async throws
}

enum PhotoLibrarySaveError: Error {
    case notAuthorized
}

/// Add-only access (`NSPhotoLibraryAddUsageDescription`); iOS asks on the first save.
final class PhotoLibrarySaver: PhotoLibrarySaving {
    func save(imageData: Data, movieData: Data?) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoLibrarySaveError.notAuthorized
        }
        var movieURL: URL?
        if let movieData {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
            try movieData.write(to: url)
            movieURL = url
        }
        defer {
            if let movieURL { try? FileManager.default.removeItem(at: movieURL) }
        }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: imageData, options: nil)
            if let movieURL {
                request.addResource(with: .pairedVideo, fileURL: movieURL, options: nil)
            }
        }
    }
}
