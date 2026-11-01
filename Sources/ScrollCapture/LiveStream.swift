import AppKit
import ScreenCaptureKit
import CoreImage
import CaptureCore

struct CapturedFrame: Sendable {
    let raster: Raster
    let time: Double
    let contentRect: CGRect
    let scale: Double
}

/// Delegate callbacks run only on a private serial queue. AsyncStream holds at most one pending frame.
final class StreamReceiver: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation
    private let context = CIContext(options: [.cacheIntermediates: false])
    init(_ continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation) { self.continuation = continuation }
    func stream(_ stream: SCStream, didStopWithError error: Error) { continuation.finish(throwing: error) }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let info = attachments.first,
              let rawStatus = info[.status] as? Int, SCFrameStatus(rawValue: rawStatus) == .complete,
              let pixelBuffer = sampleBuffer.imageBuffer,
              let rect = info[.contentRect] as? CGRect,
              let scale = info[.scaleFactor] as? Double else { return }
        do {
            let ci = CIImage(cvPixelBuffer: pixelBuffer)
            guard let image = context.createCGImage(ci, from: ci.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) else { throw CaptureError.invalidImage }
            let frame = CapturedFrame(raster: try Raster(image: image), time: sampleBuffer.presentationTimeStamp.seconds, contentRect: rect, scale: scale)
            continuation.yield(frame)
        } catch { continuation.finish(throwing: error) }
    }
}

@MainActor
final class LiveStream {
    let frames: AsyncThrowingStream<CapturedFrame, Error>
    private let receiver: StreamReceiver
    private let stream: SCStream
    init(window: SCWindow) throws {
        let pair = AsyncThrowingStream<CapturedFrame, Error>.makeStream(bufferingPolicy: .bufferingNewest(1))
        frames = pair.stream; receiver = StreamReceiver(pair.continuation)
        let filter = SCContentFilter(desktopIndependentWindow: window)
        stream = SCStream(filter: filter, configuration: ScreenSource.configuration(filter), delegate: receiver)
        try stream.addStreamOutput(receiver, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.yocruzer.ScrollCapture.frames"))
    }
    func start() async throws { try await stream.startCapture() }
    func stop() async { receiver.continuation.finish(); try? await stream.stopCapture() }
}
