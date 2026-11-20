import Foundation

public struct Coverage: Sendable, Equatable {
    public let position: Int
    public let height: Int
    public let appended: Int
    public let seams: Int
}

/// Serialized engine + immutable strips. A failed frame never mutates the confirmed ledger.
public actor CaptureSession {
    private struct Strip { let y: Int; let height: Int; let url: URL }
    private let directory: URL
    private var strips: [Strip] = []
    private var previous: Raster?
    private var position = 0
    private var height = 0
    private var width = 0
    private var seams = 0
    private var closed = false
    private var sealed = false
    public let maxPixels: Int

    public init(root: URL = FileManager.default.temporaryDirectory, maxPixels: Int = 128_000_000) throws {
        self.maxPixels = maxPixels
        directory = root.appendingPathComponent("ScrollCapture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    }
    deinit { try? FileManager.default.removeItem(at: directory) }

    public func accept(_ frame: Raster, permit: CommitPermit = CommitPermit()) throws -> Coverage {
        try permit.check()
        guard !closed, !sealed else { throw CancellationError() }
        guard frame.width * frame.height <= 8_000_000 else { throw CaptureError.resourceLimit }
        guard let previous else {
            guard frame.width * frame.height <= maxPixels else { throw CaptureError.resourceLimit }
            return try permit.commit {
                try append(frame, at: 0)
                self.previous = frame; width = frame.width; height = frame.height
                return Coverage(position: 0, height: height, appended: height, seams: 0)
            }
        }
        let motion = try Registration.estimate(previous: previous, next: frame)
        let nextPosition = position + motion.dy
        guard nextPosition >= 0 else { throw CaptureError.noOverlap }
        let known = min(frame.height, height - nextPosition)
        guard known > 0 else { throw CaptureError.noOverlap }
        // Compare known coverage with immutable history, including after reverse movement.
        let history = try read(y: nextPosition, height: known)
        try Registration.validate(history, y: 0, frame, y: 0, rows: known)
        let added = max(0, nextPosition + frame.height - height)
        guard width * (height + added) <= maxPixels, strips.count < 4096 else { throw CaptureError.resourceLimit }
        return try permit.commit {
            if added > 0 { try append(frame.crop(y: frame.height-added, height: added), at: height) }
            position = nextPosition; height += added; self.previous = frame
            if added > 0 { seams += 1 }
            return Coverage(position: position, height: height, appended: added, seams: seams)
        }
    }
    private func append(_ raster: Raster, at y: Int) throws {
        let url = directory.appendingPathComponent("\(strips.count).rgba")
        try Data(raster.bytes).write(to: url, options: .atomic)
        strips.append(Strip(y: y, height: raster.height, url: url))
    }
    public func read(y: Int, height h: Int) throws -> Raster {
        guard !closed, width > 0, y >= 0, h > 0, y+h <= height, width*h <= 40_000_000 else { throw CaptureError.invalidImage }
        var bytes = [UInt8](); bytes.reserveCapacity(width*h*4)
        for strip in strips where strip.y < y+h && strip.y+strip.height > y {
            let start = max(y,strip.y)-strip.y, end = min(y+h,strip.y+strip.height)-strip.y
            let handle = try FileHandle(forReadingFrom: strip.url)
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(start*width*4))
            guard let data = try handle.read(upToCount: (end-start)*width*4), data.count == (end-start)*width*4 else { throw CaptureError.storage }
            bytes.append(contentsOf: data)
        }
        return try Raster(width: width, height: h, bytes: bytes)
    }
    public func dimensions() -> (width: Int, height: Int) { (width,height) }
    public func seal() { sealed = true; previous = nil }

    /// A new directory is committed with a same-volume rename only after every part is encoded.
    /// Existing files/folders are never replaced. Failure removes only our unique staging directory.
    public func exportParts(parent: URL, name: String, partial: Bool, partPixels: Int = 8_000_000, range: Range<Int>? = nil) async throws -> URL {
        guard sealed, !closed, width > 0, height > 0, partPixels >= width,
              !name.isEmpty, !name.contains("/"), name != ".", name != ".." else { throw CaptureError.storage }
        let fm = FileManager.default
        let range = range ?? 0..<height
        guard range.lowerBound >= 0, range.upperBound <= height, !range.isEmpty else { throw CaptureError.invalidImage }
        let destination = parent.appendingPathComponent(name, isDirectory: true)
        guard !fm.fileExists(atPath: destination.path) else { throw CaptureError.storage }
        let stage = parent.appendingPathComponent(".ScrollCapture-export-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: stage, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: stage) }
        let partHeight = min(16_384, partPixels / width)
        var manifest: [[String: Any]] = []
        for y in stride(from: range.lowerBound, to: range.upperBound, by: partHeight) {
            await Task.yield()
            try Task.checkCancellation()
            guard !closed else { throw CancellationError() }
            let h = min(partHeight,range.upperBound-y), filename = String(format:"part-%04d.png",manifest.count+1)
            let raster = try read(y:y,height:h)
            let encoded = try raster.png()
            try encoded.write(to:stage.appendingPathComponent(filename),options:.atomic)
            manifest.append(["file":filename,"y":y-range.lowerBound,"height":h,"width":width])
        }
        let report: [String:Any] = ["schema":1,"width":width,"height":range.count,"sourceStartY":range.lowerBound,"integrity":partial ? "partial-unconfirmed-tail" : "continuous-user-ended",
                                  "documentEndConfirmed":false,"parts":manifest]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:stage.appendingPathComponent("manifest.json"),options:.atomic)
        await Task.yield()
        try Task.checkCancellation()
        guard !closed else { throw CancellationError() }
        try fm.moveItem(at:stage,to:destination)
        return destination
    }
    public func cancel() { closed = true; previous = nil; try? FileManager.default.removeItem(at: directory); strips = [] }
}
