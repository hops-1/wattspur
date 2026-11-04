import CoreData
import Foundation
import SwiftData

extension LibrarySync {
    /// Creates every record type with every field in the Development environment of the container,
    /// before the schema goes to Production (V-15, B-219).
    ///
    /// CloudKit adds a record type or a field in Development only when a record with a value for it is
    /// uploaded. The first deploy list lacked `CD_Goal`: the test library had no goal. Production can
    /// never add types or fields later, so the schema has to be complete before the deploy. Core Data's
    /// `initializeCloudKitSchema()` uploads one record of each type with every field and deletes them
    /// again; SwiftData has no call of its own, so it runs on the Core Data model made from the
    /// SwiftData models, on an empty store of its own in `scratchFolder`. The user's library is not
    /// touched. Debug builds only, with the iCloud entitlement.
    public static func initializeCloudKitSchema(scratchFolder: URL) throws {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: WattspurSchema.models) else {
            throw CocoaError(.featureUnsupported)
        }
        try? FileManager.default.removeItem(at: scratchFolder)
        try FileManager.default.createDirectory(at: scratchFolder, withIntermediateDirectories: true)
        let description = NSPersistentStoreDescription(url: scratchFolder.appending(path: "schema.store"))
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
        description.shouldAddStoreAsynchronously = false
        let container = NSPersistentCloudKitContainer(name: "WattspurSchema", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        try container.initializeCloudKitSchema()
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores { try coordinator.remove(store) }
        try? FileManager.default.removeItem(at: scratchFolder)
    }
}
