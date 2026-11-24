import Foundation
import os
import SwiftData
import Synchronization

/// Reading the library in one place (B-354, S-36). Before, `try? context.fetch` turned a failed read
/// into "nothing found" without a word: an import then added a ride a second time, and the iPhone
/// showed an empty list. Now a failed read is logged (once per model type) and counted for the
/// diagnostic report. Callers that must not go on with "nothing" use the throwing `fetch`.
public enum LibraryFetch {
    private static let failed = Mutex<[String: Int]>([:])
    private static let failing = Mutex<Set<String>>([])
    private static let log = Logger(subsystem: "io.github.hops-1.wattspur", category: "library")

    /// Reads `descriptor`; a failure is noted and thrown.
    static func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, in context: ModelContext) throws -> [T] {
        do {
            try injectedFailure(for: T.self, in: context)
            return try context.fetch(descriptor)
        } catch {
            note(T.self, error: error)
            throw error
        }
    }

    /// Reads `descriptor`; a failure is noted and gives an empty list.
    static func fetchOrEmpty<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, in context: ModelContext) -> [T] {
        (try? fetch(descriptor, in: context)) ?? []
    }

    /// Counts `descriptor`; a failure is noted and gives 0.
    static func count<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, in context: ModelContext) -> Int {
        do {
            try injectedFailure(for: T.self, in: context)
            return try context.fetchCount(descriptor)
        } catch {
            note(T.self, error: error)
            return 0
        }
    }

    /// Failed reads since the app started, by model type ("Ride" → 2), for the diagnostic report.
    public static var failures: [String: Int] { failed.withLock { $0 } }

    private static func note<T>(_ type: T.Type, error: any Error) {
        let name = String(describing: type)
        let isFirst = failed.withLock { counts in
            counts[name, default: 0] += 1
            return counts[name] == 1
        }
        if isFirst { log.error("Reading \(name, privacy: .public) from the library failed: \(String(describing: error), privacy: .public)") }
    }

    // MARK: Tests

    struct InjectedFailure: Error {}

    private static func key(_ type: Any.Type, _ context: ModelContext) -> String {
        "\(ObjectIdentifier(context).hashValue) \(String(describing: type))"
    }

    private static func injectedFailure<T>(for type: T.Type, in context: ModelContext) throws {
        if failing.withLock({ $0.contains(key(type, context)) }) { throw InjectedFailure() }
    }

    /// Only for tests: reads of these model types in `context` fail until `reset()`.
    static func failReads(of types: any PersistentModel.Type..., in context: ModelContext) {
        failing.withLock { $0.formUnion(types.map { key($0, context) }) }
    }

    /// Only for tests.
    static func reset() {
        failed.withLock { $0.removeAll() }
        failing.withLock { $0.removeAll() }
    }
}

extension LibraryService {
    /// Reads `descriptor`; a failure is logged, counted for the diagnostic report and gives `[]`.
    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T> = FetchDescriptor<T>()) -> [T] {
        LibraryFetch.fetchOrEmpty(descriptor, in: context)
    }

    /// Like `fetch(_:)`, but throws, for callers that must not take a failure for "nothing found".
    func fetchOrThrow<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        try LibraryFetch.fetch(descriptor, in: context)
    }
}
