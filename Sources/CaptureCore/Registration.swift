import Foundation

public struct Motion: Sendable { public let dy: Int; public let error: Double; public let runnerUp: Double }

/// Exhaustive integer vertical search. Input events are intentionally absent from this API.
/// No masks: every overlapping pixel must satisfy the independent residual check.
public enum Registration {
    public static func estimate(previous a: Raster, next b: Raster) throws -> Motion {
        guard a.width == b.width, a.height == b.height else { throw CaptureError.geometryChanged }
        guard a.width >= 32, a.height >= 64 else { throw CaptureError.invalidImage }
        // Search ALL observable overlap, including far aliases outside the allowed commit step.
        // Even a short alternative overlap is evidence against unique displacement.
        let limit = a.height - 8
        var candidates: [(dy: Int, score: Double)] = []
        candidates.reserveCapacity(limit * 2 + 1)
        for dy in -limit...limit {
            let aStart = max(0, dy), bStart = max(0, -dy), rows = a.height - abs(dy)
            var sum = 0, n = 0
            // Fixed dense horizontal samples, staggered across rows; no luminance-only aliasing.
            for row in stride(from: 0, to: rows, by: max(1, rows / 48)) {
                for x in stride(from: row % 7, to: a.width, by: max(1, a.width / 32)) {
                    let i = ((aStart+row)*a.width+x)*4, j = ((bStart+row)*b.width+x)*4
                    for c in 0..<3 { sum += abs(Int(a.bytes[i+c])-Int(b.bytes[j+c])); n += 1 }
                }
            }
            candidates.append((dy, Double(sum)/Double(max(1,n))))
        }
        candidates.sort { $0.score < $1.score }
        guard var best = candidates.first, best.score <= 1.5 else { throw CaptureError.noOverlap }
        let runner = candidates[1].score
        if runner - best.score < 1.0 {
            // White margins can tie at every sampled column even when the ink between
            // them uniquely identifies the scroll. Require an exact full overlap for
            // this fallback; the normal residual test below still excludes ALL rivals.
            guard let exact = candidates.prefix(while: { $0.score == 0 }).first(where: {
                let overlap = (a.height - abs($0.dy)) * a.width * 4
                let startA = max(0, $0.dy) * a.width * 4
                let startB = max(0, -$0.dy) * a.width * 4
                return a.bytes[startA..<startA + overlap].elementsEqual(b.bytes[startB..<startB + overlap])
            }) else { throw CaptureError.ambiguous }
            best = exact
        }
        guard abs(best.dy) <= a.height * 2 / 3 else { throw CaptureError.noOverlap }
        let aStart = max(0,best.dy), bStart = max(0,-best.dy)
        try validate(a, y: aStart, b, y: bStart, rows: a.height - abs(best.dy))
        for other in candidates where other.dy != best.dy {
            if (try? validate(a,y:max(0,other.dy),b,y:max(0,-other.dy),rows:a.height-abs(other.dy))) != nil {
                throw CaptureError.ambiguous
            }
        }
        return Motion(dy: best.dy, error: best.score, runnerUp: runner)
    }

    public static func validate(_ a: Raster, y ay: Int, _ b: Raster, y by: Int, rows: Int) throws {
        guard a.width == b.width, rows > 0, ay >= 0, by >= 0, ay <= a.height, by <= b.height, rows <= a.height-ay, rows <= b.height-by else { throw CaptureError.geometryChanged }
        var total: Int64 = 0, bad = 0
        for row in 0..<rows {
            var rowTotal = 0
            for x in 0..<a.width {
                let i = ((ay+row)*a.width+x)*4, j = ((by+row)*b.width+x)*4
                // RGB is premultiplied. Black pixels can differ visibly by alpha alone.
                guard a.bytes[i+3] == b.bytes[j+3] else { throw CaptureError.noOverlap }
                for c in 0..<3 {
                    let d = abs(Int(a.bytes[i+c])-Int(b.bytes[j+c])); rowTotal += d
                    if d > 12 { bad += 1 }
                }
            }
            // Localized occlusion/layout changes cannot disappear into a large average.
            guard Double(rowTotal)/Double(a.width*3) <= 3 else { throw CaptureError.noOverlap }
            total += Int64(rowTotal)
        }
        let count = a.width * rows * 3
        guard Double(total)/Double(count) <= 1.5, Double(bad)/Double(count) <= 0.005 else { throw CaptureError.noOverlap }
    }
}
