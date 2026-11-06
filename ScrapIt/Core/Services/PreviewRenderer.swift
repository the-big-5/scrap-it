import CoreImage
import Metal
import QuartzCore

/// Renders filtered camera frames straight into a `CAMetalLayer` (from the POC).
/// `display(_:)` runs on the video queue, so the main thread never waits for the GPU.
nonisolated final class PreviewRenderer: @unchecked Sendable {
    let device: MTLDevice
    let metalLayer = CAMetalLayer()
    private let commandQueue: MTLCommandQueue
    private let context = RenderContext.ciContext
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let lock = NSLock()
    private var targetSize: CGSize = .zero

    init?(device: MTLDevice? = RenderContext.device) {
        guard let device, let commandQueue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.commandQueue = commandQueue
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.isOpaque = true
        metalLayer.backgroundColor = CGColor(gray: 0, alpha: 1)
    }

    /// Called on the main thread when the view size changes (in pixels).
    func updateDrawableSize(_ size: CGSize) {
        lock.withLock { targetSize = size }
    }

    /// Called on the video queue for every frame. Aspect fill, centered.
    func display(_ image: CIImage) {
        let size = lock.withLock { targetSize }
        guard size.width > 0, size.height > 0 else { return }
        if metalLayer.drawableSize != size {
            metalLayer.drawableSize = size
        }
        guard let drawable = metalLayer.nextDrawable(),
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let bounds = CGRect(origin: .zero, size: size)
        let scale = max(size.width / image.extent.width, size.height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let centered = scaled.transformed(by: CGAffineTransform(
            translationX: (size.width - scaled.extent.width) / 2 - scaled.extent.minX,
            y: (size.height - scaled.extent.height) / 2 - scaled.extent.minY))
        let output = centered.composited(over: CIImage.black.cropped(to: bounds))

        context.render(output, to: drawable.texture, commandBuffer: commandBuffer,
                       bounds: bounds, colorSpace: colorSpace)
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
