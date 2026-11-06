import AVFoundation
import CoreImage

nonisolated enum LivePhotoMovieError: Error {
    case noVideoTrack
    case writeFailed
}

/// Filters a Live Photo movie and rewrites it with the pairing metadata (content identifier +
/// still-image-time) so iOS treats photo and movie as one Live Photo. No audio. Ported from the POC.
nonisolated enum LivePhotoMovieWriter {
    private static let stillImageTimeKey = "com.apple.quicktime.still-image-time"

    static func write(from sourceURL: URL, to destinationURL: URL, look: FilmLook,
                      contentIdentifier: String, photoDisplayTime: CMTime) async throws {
        let asset = AVURLAsset(url: sourceURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw LivePhotoMovieError.noVideoTrack
        }
        let (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)
        let width = Int(naturalSize.width.rounded())
        let height = Int(naturalSize.height.rounded())

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)

        try? FileManager.default.removeItem(at: destinationURL)
        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mov)
        writer.metadata = [contentIdentifierItem(contentIdentifier)]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        // Keeps the camera orientation and mirroring through the track transform.
        videoInput.transform = transform
        videoInput.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
        ])
        writer.add(videoInput)

        let metadataAdaptor = stillImageTimeAdaptor()
        writer.add(metadataAdaptor.assetWriterInput)

        guard reader.startReading(), writer.startWriting(),
              let firstSample = output.copyNextSampleBuffer() else {
            reader.cancelReading()
            writer.cancelWriting()
            throw writer.error ?? reader.error ?? LivePhotoMovieError.writeFailed
        }
        writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(firstSample))

        // Marks which frame is the still photo.
        metadataAdaptor.append(AVTimedMetadataGroup(
            items: [stillImageTimeItem()],
            timeRange: CMTimeRange(start: photoDisplayTime, duration: CMTime(value: 1, timescale: 100))))
        metadataAdaptor.assetWriterInput.markAsFinished()

        let copier = FrameCopier(reader: reader, output: output, writer: writer, videoInput: videoInput,
                                 adaptor: adaptor, firstSample: firstSample, look: look,
                                 bounds: CGRect(x: 0, y: 0, width: width, height: height))
        try await copier.run()

        await writer.finishWriting()
        guard writer.status == .completed else {
            try? FileManager.default.removeItem(at: destinationURL)
            throw writer.error ?? LivePhotoMovieError.writeFailed
        }
    }

    /// Frame loop: read → filter → write. All state is touched only on `queue` (serial).
    private final class FrameCopier: @unchecked Sendable {
        private let reader: AVAssetReader
        private let output: AVAssetReaderTrackOutput
        private let writer: AVAssetWriter
        private let videoInput: AVAssetWriterInput
        private let adaptor: AVAssetWriterInputPixelBufferAdaptor
        private let look: FilmLook
        private let bounds: CGRect
        private let pipeline = FilmFilterPipeline()
        private let context = RenderContext.ciContext
        private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        private let queue = DispatchQueue(label: "ScrapIt.livePhoto", qos: .utility)
        private var pending: CMSampleBuffer?
        private var continuation: CheckedContinuation<Void, Error>?

        init(reader: AVAssetReader, output: AVAssetReaderTrackOutput, writer: AVAssetWriter,
             videoInput: AVAssetWriterInput, adaptor: AVAssetWriterInputPixelBufferAdaptor,
             firstSample: CMSampleBuffer, look: FilmLook, bounds: CGRect) {
            self.reader = reader
            self.output = output
            self.writer = writer
            self.videoInput = videoInput
            self.adaptor = adaptor
            self.pending = firstSample
            self.look = look
            self.bounds = bounds
        }

        func run() async throws {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    self.continuation = continuation
                    self.videoInput.requestMediaDataWhenReady(on: self.queue) { self.copyAvailableFrames() }
                }
            }
        }

        private func copyAvailableFrames() {
            while continuation != nil && videoInput.isReadyForMoreMediaData {
                guard let sample = pending ?? output.copyNextSampleBuffer() else {
                    finish(reader.status == .failed ? (reader.error ?? LivePhotoMovieError.writeFailed) : nil)
                    return
                }
                pending = nil
                var destination: CVPixelBuffer?
                if let pool = adaptor.pixelBufferPool {
                    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &destination)
                }
                guard let source = CMSampleBufferGetImageBuffer(sample), let destination else {
                    finish(LivePhotoMovieError.writeFailed)
                    return
                }
                let filtered = pipeline.apply(look, to: CIImage(cvPixelBuffer: source))
                context.render(filtered, to: destination, bounds: bounds, colorSpace: colorSpace)
                if !adaptor.append(destination, withPresentationTime: CMSampleBufferGetPresentationTimeStamp(sample)) {
                    finish(writer.error ?? LivePhotoMovieError.writeFailed)
                    return
                }
            }
        }

        private func finish(_ error: Error?) {
            guard let continuation else { return }
            self.continuation = nil
            videoInput.markAsFinished()
            if let error {
                reader.cancelReading()
                continuation.resume(throwing: error)
            } else {
                continuation.resume()
            }
        }
    }

    /// Reads the content identifier back from a movie (used by tests and the debug viewer).
    static func contentIdentifier(of url: URL) async -> String? {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.metadata) else { return nil }
        let matches = AVMetadataItem.metadataItems(
            from: items,
            filteredByIdentifier: .quickTimeMetadataContentIdentifier
        )
        return try? await matches.first?.load(.stringValue)
    }

    private static func contentIdentifierItem(_ identifier: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.keySpace = .quickTimeMetadata
        item.key = AVMetadataKey.quickTimeMetadataKeyContentIdentifier.rawValue as NSString
        item.value = identifier as NSString
        item.dataType = kCMMetadataBaseDataType_UTF8 as String
        return item
    }

    private static func stillImageTimeItem() -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.keySpace = .quickTimeMetadata
        item.key = stillImageTimeKey as NSString
        item.value = 0 as NSNumber
        item.dataType = kCMMetadataBaseDataType_SInt8 as String
        return item
    }

    private static func stillImageTimeAdaptor() -> AVAssetWriterInputMetadataAdaptor {
        let specification: [String: Any] = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String:
                "\(AVMetadataKeySpace.quickTimeMetadata.rawValue)/\(stillImageTimeKey)",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String:
                kCMMetadataBaseDataType_SInt8 as String,
        ]
        var description: CMFormatDescription?
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault, metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [specification] as CFArray, formatDescriptionOut: &description)
        let input = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: description)
        return AVAssetWriterInputMetadataAdaptor(assetWriterInput: input)
    }
}
