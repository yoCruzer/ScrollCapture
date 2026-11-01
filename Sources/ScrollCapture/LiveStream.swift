import AppKit
@preconcurrency import ScreenCaptureKit
import CoreImage
import CaptureCore

struct CapturedFrame: Sendable {
    let sequence: UInt64
    let raster: Raster
    let time: Double
    let contentRect: CGRect
    let scale: Double
    let contentScale: Double
}

/// Delegate callbacks run only on a private serial queue. AsyncStream holds at most one pending frame.
final class StreamReceiver: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var sequence: UInt64 = 0
    init(_ continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation) { self.continuation = continuation }
    func stream(_ stream: SCStream, didStopWithError error: Error) { continuation.finish(throwing: error) }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let info = attachments.first,
              let rawStatus = info[.status] as? Int, let status = SCFrameStatus(rawValue:rawStatus) else { return }
        if status == .idle || status == .started { return }
        guard status == .complete, let pixelBuffer = sampleBuffer.imageBuffer else {
            continuation.finish(throwing:CaptureError.geometryChanged); return
        }
        do {
            let rect: CGRect?
            if let value = info[.contentRect] as? CGRect { rect = value }
            else if let dictionary = info[.contentRect] as? NSDictionary { rect = CGRect(dictionaryRepresentation:dictionary) }
            else { rect = nil }
            guard let rect, !rect.isEmpty, rect.origin.x.isFinite, rect.origin.y.isFinite,
                  rect.width.isFinite, rect.height.isFinite,
                  let scale = info[.scaleFactor] as? Double, scale.isFinite, scale > 0,
                  let contentScale = info[.contentScale] as? Double, contentScale.isFinite, contentScale > 0 else { throw CaptureError.geometryChanged }
            let ci = CIImage(cvPixelBuffer: pixelBuffer)
            guard let image = context.createCGImage(ci, from: ci.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) else { throw CaptureError.invalidImage }
            sequence += 1
            let frame = CapturedFrame(sequence:sequence,raster: try Raster(image: image), time: sampleBuffer.presentationTimeStamp.seconds, contentRect: rect, scale: scale,contentScale:contentScale)
            continuation.yield(frame)
        } catch { continuation.finish(throwing: error) }
    }
}

@MainActor
final class LiveStream {
    let frames: AsyncThrowingStream<CapturedFrame, Error>
    private let receiver: StreamReceiver
    private let stream: SCStream
    private var startTask: Task<Void,Error>?
    private var stopping = false
    init(window: SCWindow) throws {
        let pair = AsyncThrowingStream<CapturedFrame, Error>.makeStream(bufferingPolicy: .bufferingNewest(1))
        frames = pair.stream; receiver = StreamReceiver(pair.continuation)
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = ScreenSource.configuration(filter)
        guard config.width > 0, config.height > 0, config.width <= 16_384, config.height <= 16_384,
              config.width*config.height <= 8_000_000 else { throw CaptureError.resourceLimit }
        stream = SCStream(filter: filter, configuration: config, delegate: receiver)
        try stream.addStreamOutput(receiver, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.yocruzer.ScrollCapture.frames"))
    }
    func start() async throws {
        if let startTask { return try await startTask.value }
        let task = Task { @MainActor in
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void,Error>) in
                stream.startCapture { error in
                    if let error { continuation.resume(throwing:error) } else { continuation.resume() }
                }
            }
        }
        startTask = task; try await task.value
    }
    func stop() async {
        receiver.continuation.finish()
        // A cancelled preparation cannot start a capture after its stop has already returned.
        if let startTask { _ = try? await startTask.value }
        guard !stopping else { return }; stopping = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void,Never>) in
            stream.stopCapture { _ in continuation.resume() }
        }
    }
}
