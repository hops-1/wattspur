import Foundation
import SwiftData

/// What the services of the library share: the data, the importers, the undo manager of the window
/// that asks, and the name new bikes get.
struct LibraryEnvironment {
    let context: ModelContext
    let importers: [any RideImporter]
    /// Where renaming, trashing, restoring, merging, splitting and assigning register their
    /// opposite step for ⌘Z. SwiftData's own undo is not used: it did not reliably undo changed
    /// values and left merged parts pointing at a deleted ride.
    let undoManager: UndoManager?
    /// The name of the bike every library starts with and that bikes without a name get
    /// (REQUIREMENTS.md 10.16). The app passes the localized name.
    let defaultBikeName: String
}

/// One area of the library. A service has no state of its own: it is made from the environment
/// whenever it is needed, also when an undo step runs. Services use each other only in one
/// direction (imports → merging → bikes), never back.
@MainActor
protocol LibraryService {
    var env: LibraryEnvironment { get }
    init(_ env: LibraryEnvironment)
}

extension LibraryService {
    var context: ModelContext { env.context }

    /// Registers the opposite step. Called while undoing, it becomes the redo step.
    func registerUndo(_ step: @escaping @MainActor (Self) -> Void) {
        guard let undoManager = env.undoManager else { return }
        let importers = env.importers
        let defaultBikeName = env.defaultBikeName
        undoManager.registerUndo(withTarget: env.context) { [weak undoManager] context in
            MainActor.assumeIsolated {
                let env = LibraryEnvironment(context: context, importers: importers, undoManager: undoManager,
                                             defaultBikeName: defaultBikeName)
                step(Self(env))
            }
        }
    }

    func ride(withID id: UUID) -> Ride? {
        var descriptor = FetchDescriptor<Ride>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
