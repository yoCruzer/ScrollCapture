import Foundation

/// Cancellation invalidates a transaction before its durable ledger commit.
/// The lock makes invalidation and the short commit section mutually exclusive.
public final class CommitPermit: @unchecked Sendable {
    private let lock = NSLock()
    private var valid = true
    public init() {}
    public func invalidate() { lock.lock(); valid = false; lock.unlock() }
    public func check() throws { lock.lock(); defer { lock.unlock() }; if !valid { throw CancellationError() } }
    func commit<T>(_ body: () throws -> T) throws -> T {
        lock.lock(); defer { lock.unlock() }
        guard valid else { throw CancellationError() }
        return try body()
    }
}
