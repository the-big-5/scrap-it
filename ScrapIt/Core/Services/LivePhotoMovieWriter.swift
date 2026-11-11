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
    /// Max longest edge for stored/uploaded Live Photo movies (change 014: 1080p standard).
    static let maxVideoDimension: CGFloat = 1440
    /// Average bitrate target: ~2.5 Mbps (change 014: ~80% size reduction over unconstrained video).
    static let targetAverageBitRate: Int = 2_500_000

    /// Calculates center crop rect to ensure video adheres to 4:3 (landscape) or 3:4 (portrait) aspect ratio.
    static func cropRect(for naturalSize: CGSize, transform: CGAffineTransform) -> (cropRect: CGRect?, targetRawSize: CGSize) {
        let transformedSize = naturalSize.applying(transform)
        let effectiveWidth = abs(transformedSize.width)
        let effectiveHeight = abs(transformedSize.height)
        guard effectiveWidth > 0, effectiveHeight > 0 else {
            return (nil, naturalSize)
        }
        let isPortraitVideo = effectiveHeight > effectiveWidth
        let isRotated = abs(transform.b) > 0.1
        let rawTargetAspect: CGFloat = isRotated
            ? (isPortraitVideo ? (4.0 / 3.0) : (3.0 / 4.0))
            : (isPortraitVideo ? (3.0 / 4.0) : (4.0 / 3.0))

        let currentAspect = naturalSize.width / naturalSize.height
        if abs(currentAspect - rawTargetAspect) < 0.005 {
            return (nil, naturalSize)
        }

        if currentAspect > rawTargetAspect {
            let newWidth = naturalSize.height * rawTargetAspect
            let originX = (naturalSize.width - newWidth) / 2.0
            let rect = CGRect(x: originX, y: 0, width: newWidth, height: naturalSize.height)
            return (rect, CGSize(width: newWidth, height: naturalSize.height))
        } else {
            let newHeight = naturalSize.width / rawTargetAspect
            let originY = (naturalSize.height - newHeight) / 2.0
            let rect = CGRect(x: 0, y: originY, width: naturalSize.width, height: newHeight)
            return (rect, CGSize(width: naturalSize.width, height: newHeight))
        }
    }

    static func constrainedDimensions(from naturalSize: CGSize, maxDimension: CGFloat = maxVideoDimension) -> (width: Int, height: Int, scaleX: CGFloat, scaleY: CGFloat) {
        let rawWidth = naturalSize.width
        let rawHeight = naturalSize.height
        let maxSide = max(rawWidth, rawHeight)
        guard maxSide > maxDimension, maxSide > 0 else {
            var w = Int(rawWidth.rounded())
            var h = Int(rawHeight.rounded())
            if w % 2 != 0 { w -= 1 }
            if h % 2 != 0 { h -= 1 }
            let scaleX = rawWidth > 0 ? CGFloat(w) / rawWidth : 1.0
            let scaleY = rawHeight > 0 ? CGFloat(h) / rawHeight : 1.0
            return (w, h, scaleX, scaleY)
        }
        let scale = maxDimension / maxSide
        var w = Int((rawWidth * scale).rounded())
        var h = Int((rawHeight * scale).rounded())
        if w % 2 != 0 { w -= 1 }
        if h % 2 != 0 { h -= 1 }
        let scaleX = CGFloat(w) / rawWidth
        let scaleY = CGFloat(h) / rawHeight
        return (w, h, scaleX, scaleY)
    }

    static func write(from sourceURL: URL, to destinationURL: URL, look: FilmLook,
                      contentIdentifier: String, photoDisplayTime: CMTime) async throws {
        let asset = AVURLAsset(url: sourceURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw LivePhotoMovieError.noVideoTrack
        }
        let (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)
        let (crop, targetRawSize) = cropRect(for: naturalSize, transform: transform)
        let (width, height, scaleX, scaleY) = constrainedDimensions(from: targetRawSize)

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
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: targetAverageBitRate,
            ],
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
                                 bounds: CGRect(x: 0, y: 0, width: width, height: height),
                                 scaleX: scaleX, scaleY: scaleY, cropRect: crop)
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
        private let scaleX: CGFloat
        private let scaleY: CGFloat
        private let cropRect: CGRect?
        private let pipeline = FilmFilterPipeline()
        private let context = RenderContext.ciContext
        private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        private let queue = DispatchQueue(label: "ScrapIt.livePhoto", qos: .utility)
        private var pending: CMSampleBuffer?
        private var continuation: CheckedContinuation<Void, Error>?

        init(reader: AVAssetReader, output: AVAssetReaderTrackOutput, writer: AVAssetWriter,
             videoInput: AVAssetWriterInput, adaptor: AVAssetWriterInputPixelBufferAdaptor,
             firstSample: CMSampleBuffer, look: FilmLook, bounds: CGRect,
             scaleX: CGFloat, scaleY: CGFloat, cropRect: CGRect? = nil) {
            self.reader = reader
            self.output = output
            self.writer = writer
            self.videoInput = videoInput
            self.adaptor = adaptor
            self.pending = firstSample
            self.look = look
            self.bounds = bounds
            self.scaleX = scaleX
            self.scaleY = scaleY
            self.cropRect = cropRect
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
                let sourceCI = CIImage(cvPixelBuffer: source)
                let cropped = cropRect.map {
                    sourceCI.cropped(to: $0)
                        .transformed(by: CGAffineTransform(translationX: -$0.origin.x, y: -$0.origin.y))
                } ?? sourceCI
                let filtered = pipeline.apply(look, to: cropped)
                let target = (scaleX == 1.0 && scaleY == 1.0)
                    ? filtered
                    : filtered.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                context.render(target, to: destination, bounds: bounds, colorSpace: colorSpace)
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
