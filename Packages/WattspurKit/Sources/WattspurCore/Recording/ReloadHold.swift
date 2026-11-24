/// Whether the iPhone reads its library again now or later (B-380). Reading the whole library runs on
/// the main thread; while a ride is recorded the rider does not look at the list, and when the camera
/// fills the memory such a reading took more than 10 seconds and iOS ended the app (bike tour of
/// 24.11.2026). So while it holds, a reading that iCloud or the return of the app asks for waits, and
/// one reading follows when the hold ends. A reading after the rider's own action is never held.
public struct ReloadHold: Sendable, Equatable {
    /// True while a ride is recorded.
    public private(set) var isHolding = false
    /// A reading was asked for while holding.
    public private(set) var isPending = false

    public init() {}

    /// Asks for a reading; true when it may run now.
    public mutating func request() -> Bool {
        if isHolding { isPending = true }
        return !isHolding
    }

    /// Starts or ends the hold; true when a held reading must run now.
    public mutating func set(holding: Bool) -> Bool {
        isHolding = holding
        return !holding && isPending
    }

    /// A reading ran, whatever asked for it: nothing waits any more.
    public mutating func didReload() {
        isPending = false
    }
}
