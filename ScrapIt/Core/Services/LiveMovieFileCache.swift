import Foundation

/// Live Photo movies are stored as data in SwiftData; the looping player needs a file.
/// Writes each movie once to Caches (change 013).
nonisolated enum LiveMovieFileCache {
    static func url(for photoID: UUID, data: Data) -> URL? {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveMovies", isDirectory: true)
        let url = folder.appendingPathComponent("\(photoID.uuidString).mov")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func remove(photoIDs: [UUID]) {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveMovies", isDirectory: true)
        for id in photoIDs {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent("\(id.uuidString).mov"))
        }
    }
}
