import CoreData
import Foundation

extension LibraryBackup {
    /// Writes the contents of the library at `backupStore` into the library at `storeURL`, as ordinary
    /// changes (B-265): objects are matched by their `id`; what the backup lacks is deleted, what only the
    /// backup has is inserted, and where both differ the library takes the backup's values. Objects that
    /// are the same stay untouched.
    ///
    /// Why not swap the file: the file carries the state of the iCloud mirror of back then, so iCloud
    /// would play in everything that changed since the backup (R-29). Written as changes, the library
    /// keeps its own mirror state; the changes land in its persistent history, and the mirror sends them
    /// to iCloud when the library opens with sync, from where every other device gets the same state.
    /// No CloudKit record type or field is added.
    ///
    /// Call it while neither store is open elsewhere. It saves in steps; if it throws, the library may be
    /// half written, so the caller puts back the copy it made before (`applyPendingRestore` does).
    static func rewrite(storeURL: URL, from backupStore: URL, chunkSize: Int = 100) throws {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: WattspurSchema.models) else {
            throw CocoaError(.featureUnsupported)
        }
        let live = try openCoordinator(storeURL, model: model)
        defer { closeCoordinator(live) }
        let backup = try openCoordinator(backupStore, model: model)
        defer { closeCoordinator(backup) }

        let target = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        target.persistentStoreCoordinator = live
        target.undoManager = nil
        let source = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        source.persistentStoreCoordinator = backup

        let rewriter = Rewriter(source: source, target: target, model: model, chunkSize: chunkSize)
        let result: Result<Void, Error> = target.performAndWait {
            source.performAndWait { Result { try rewriter.run() } }
        }
        try result.get()
    }

    private static func openCoordinator(_ url: URL, model: NSManagedObjectModel) throws -> NSPersistentStoreCoordinator {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        // History on, as SwiftData keeps it: the iCloud mirror sends what this history records (B-265).
        let options: [String: Any] = [
            NSPersistentHistoryTrackingKey: true as NSNumber,
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
        ]
        _ = try coordinator.addPersistentStore(type: .sqlite, at: url, options: options)
        return coordinator
    }

    private static func closeCoordinator(_ coordinator: NSPersistentStoreCoordinator) {
        for store in coordinator.persistentStores { try? coordinator.remove(store) }
    }
}

/// The three passes of `LibraryBackup.rewrite`: values, relationships, deletions. Each pass works in
/// chunks and saves after each, so the larger blobs (samples, original files) do not all sit in memory.
/// Unchecked: it runs only inside `performAndWait` of both its contexts, on their queues.
private struct Rewriter: @unchecked Sendable {
    let source: NSManagedObjectContext
    let target: NSManagedObjectContext
    let model: NSManagedObjectModel
    let chunkSize: Int

    func run() throws {
        let entities = model.entities.filter { !$0.isAbstract }.sorted { ($0.name ?? "") < ($1.name ?? "") }
        // Backup object → library object, over all entities, for the relationships.
        var map: [NSManagedObjectID: NSManagedObjectID] = [:]
        var unmatched: [NSManagedObjectID] = []
        for entity in entities {
            let (matched, rest) = try writeValues(of: entity)
            map.merge(matched) { first, _ in first }
            unmatched += rest
        }
        for entity in entities {
            try writeRelationships(of: entity, map: map)
        }
        for chunk in unmatched.chunked(chunkSize) {
            for id in chunk {
                guard let object = try? target.existingObject(with: id) else { continue } // gone by a cascade
                target.delete(object)
            }
            try saveAndReset()
        }
    }

    /// Pass 1: every backup object gets its library object (the one with the same `id`, or a new one) and
    /// the backup's values. Returns the matches and the library objects the backup does not have.
    private func writeValues(of entity: NSEntityDescription) throws -> ([NSManagedObjectID: NSManagedObjectID], [NSManagedObjectID]) {
        guard let name = entity.name else { return ([:], []) }
        // Library objects by `id`; several per `id` are possible (rows made twice by two devices, R-35).
        var byID: [UUID: [NSManagedObjectID]] = [:]
        var withoutID: [NSManagedObjectID] = []
        for (objectID, id) in try ids(of: name, in: target) {
            if let id { byID[id, default: []].append(objectID) } else { withoutID.append(objectID) }
        }
        let attributes = entity.attributesByName.values.filter { !$0.isTransient }
        var map: [NSManagedObjectID: NSManagedObjectID] = [:]
        for chunk in try ids(of: name, in: source).chunked(chunkSize) {
            var pairs: [(NSManagedObjectID, NSManagedObject)] = []
            for (sourceID, id) in chunk {
                let original = try source.existingObject(with: sourceID)
                let copy: NSManagedObject
                if let id, var list = byID[id], !list.isEmpty {
                    copy = try target.existingObject(with: list.removeFirst())
                    byID[id] = list
                } else {
                    copy = NSManagedObject(entity: entity, insertInto: target)
                }
                for attribute in attributes {
                    let value = original.value(forKey: attribute.name)
                    if !Self.same(copy.value(forKey: attribute.name), value) {
                        copy.setValue(value, forKey: attribute.name)
                    }
                }
                pairs.append((sourceID, copy))
            }
            try target.obtainPermanentIDs(for: pairs.map(\.1).filter(\.objectID.isTemporaryID))
            for (sourceID, copy) in pairs { map[sourceID] = copy.objectID }
            try saveAndReset()
        }
        return (map, byID.values.flatMap { $0 } + withoutID)
    }

    /// Pass 2: the relationships as in the backup. To-one relationships are set; a to-many relationship
    /// follows from the to-one on the other side, unless both sides are to-many.
    private func writeRelationships(of entity: NSEntityDescription, map: [NSManagedObjectID: NSManagedObjectID]) throws {
        guard let name = entity.name else { return }
        let relationships = entity.relationshipsByName.values.filter { !$0.isToMany || $0.inverseRelationship?.isToMany != false }
        guard !relationships.isEmpty else { return }
        for chunk in try ids(of: name, in: source).chunked(chunkSize) {
            for (sourceID, _) in chunk {
                guard let copyID = map[sourceID] else { continue }
                let original = try source.existingObject(with: sourceID)
                let copy = try target.existingObject(with: copyID)
                for relationship in relationships {
                    let key = relationship.name
                    if relationship.isToMany {
                        let wanted = Set(((original.value(forKey: key) as? Set<NSManagedObject>) ?? []).compactMap { map[$0.objectID] })
                        let current = Set(((copy.value(forKey: key) as? Set<NSManagedObject>) ?? []).map(\.objectID))
                        guard wanted != current else { continue }
                        let objects = try wanted.map { try target.existingObject(with: $0) }
                        copy.setValue(Set(objects), forKey: key)
                    } else {
                        let wanted = (original.value(forKey: key) as? NSManagedObject).flatMap { map[$0.objectID] }
                        let current = (copy.value(forKey: key) as? NSManagedObject)?.objectID
                        guard wanted != current else { continue }
                        copy.setValue(try wanted.map { try target.existingObject(with: $0) }, forKey: key)
                    }
                }
            }
            try saveAndReset()
        }
    }

    /// All objects of an entity with their `id`, without loading the other values.
    private func ids(of entityName: String, in context: NSManagedObjectContext) throws -> [(NSManagedObjectID, UUID?)] {
        let request = NSFetchRequest<NSDictionary>(entityName: entityName)
        request.resultType = .dictionaryResultType
        let objectID = NSExpressionDescription()
        objectID.name = "objectID"
        objectID.expression = NSExpression.expressionForEvaluatedObject()
        objectID.expressionResultType = .objectIDAttributeType
        request.propertiesToFetch = [objectID, "id"]
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        return try context.fetch(request).compactMap { row in
            guard let objectID = row["objectID"] as? NSManagedObjectID else { return nil }
            return (objectID, row["id"] as? UUID)
        }
    }

    private func saveAndReset() throws {
        if target.hasChanges { try target.save() }
        target.reset()
        source.reset()
    }

    static func same(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case let (a as NSObject, b as NSObject): a.isEqual(b)
        default: false
        }
    }
}

private extension Array {
    func chunked(_ size: Int) -> [ArraySlice<Element>] {
        stride(from: 0, to: count, by: Swift.max(size, 1)).map { self[$0 ..< Swift.min($0 + size, count)] }
    }
}
