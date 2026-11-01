import Foundation

/// Input amplitude is never a position estimate. Only committed image coverage permits another step.
public struct AutoPolicy: Sendable {
    public enum Action: Equatable, Sendable { case send, wait, stop(String) }
    private let start: Double
    private var sentAt: Double?
    private var baseline = 0
    public private(set) var steps = 0
    public init(now: Double) { start = now }
    public mutating func evaluate(now: Double, height: Int, acceptedAt: Double, safeTarget: Bool) -> Action {
        guard safeTarget else { return .stop("目标、焦点或鼠标位置变化") }
        guard now-start < 120, steps < 80 else { return .stop("已达到自动模式时长或步数上限") }
        if let sentAt {
            if height > baseline && acceptedAt > sentAt && now-acceptedAt >= 0.5 {
                self.sentAt = nil
            } else if now-sentAt >= 3 {
                return .stop("未得到已验证进展：可能未响应、加载中或接近底部；未确认文档尾部")
            } else { return .wait }
        }
        baseline = height; sentAt = now; steps += 1
        return .send
    }
}
