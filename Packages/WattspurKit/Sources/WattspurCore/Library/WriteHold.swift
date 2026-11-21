import Foundation

/// Keeps the app running while the library writes (B-366).
///
/// The iPhone's store lies in the App Group's container, so the widget can read it. iOS ends an app
/// that is suspended while it holds a lock on a file there (termination code 0xdead10cc). That
/// happened on 21.11.2026 right after a ride was saved and the app went to the background.
/// While a write is held, the app asks iOS for background time, so the store can finish first.
///
/// `begin` and `end` are UIKit's `beginBackgroundTask` and `endBackgroundTask` in the app; `begin`
/// returns `nil` when iOS gives no time. Overlapping holds share one background task.
@MainActor
public final class WriteHold {
    public typealias Begin = (_ expired: @escaping @MainActor () -> Void) -> Int?

    private let begin: Begin
    private let end: (Int) -> Void
    private var count = 0
    private var task: Int?

    public init(begin: @escaping Begin, end: @escaping (Int) -> Void) {
        self.begin = begin
        self.end = end
    }

    /// Whether a write is held now.
    public var isHeld: Bool { count > 0 }

    /// Starts holding; every `hold()` needs one `release()`.
    public func hold() {
        count += 1
        guard count == 1 else { return }
        task = begin { [weak self] in self?.expire() }
    }

    /// Ends one hold; the background task ends with the last.
    public func release() {
        guard count > 0 else { return }
        count -= 1
        if count == 0 { finish() }
    }

    /// Runs `body` while held.
    @discardableResult
    public func during<T>(_ body: () throws -> T) rethrows -> T {
        hold()
        defer { release() }
        return try body()
    }

    /// iOS's time ran out: the task must end now, whatever is still held.
    private func expire() {
        count = 0
        finish()
    }

    private func finish() {
        guard let task else { return }
        self.task = nil
        end(task)
    }
}
