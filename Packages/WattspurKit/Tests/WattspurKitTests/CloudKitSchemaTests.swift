import CoreData
import Foundation
import SwiftData
import Testing
@testable import WattspurKit

/// The CloudKit rules for the model (B-189). Sync with `cloudKitDatabase: .private(…)` (B-072) only
/// opens a store whose model keeps them, and once the schema is deployed to Production it can only
/// grow. So every change to a `@Model` has to pass here first.
///
/// The check runs on the Core Data model SwiftData builds from the schema, the same model
/// `NSPersistentCloudKitContainer` validates when sync is switched on.
@Suite("CloudKit rules of the model")
struct CloudKitSchemaTests {
    @Test("Every model type is in the schema")
    func allEntities() throws {
        let model = try CloudKitRules.model(for: WattspurSchema.models)
        let names = Set(model.entities.compactMap(\.name))
        #expect(names == ["Ride", "Rider", "Bike", "SourceFile", "ImportRecord", "Goal", "RouteGroup"])
    }

    @Test("The Wattspur model keeps every CloudKit rule")
    func wattspurModel() throws {
        let model = try CloudKitRules.model(for: WattspurSchema.models)
        #expect(CloudKitRules.violations(in: model) == [])
    }

    @Test("The check finds each broken rule")
    func brokenModel() throws {
        let model = try CloudKitRules.model(for: [BrokenOwner.self, BrokenItem.self, BrokenLoner.self])
        #expect(CloudKitRules.violations(in: model) == [
            "BrokenItem.serial: not optional and no default",
            "BrokenItem.tag: no inverse",
            "BrokenItem: unique constraint",
            "BrokenOwner.items: deny rule",
            "BrokenOwner.loner: not optional",
        ])
    }
}

/// The rules of `NSPersistentCloudKitContainer` for a model.
enum CloudKitRules {
    static func model(for types: [any PersistentModel.Type]) throws -> NSManagedObjectModel {
        try #require(NSManagedObjectModel.makeManagedObjectModel(for: types))
    }

    /// One line per broken rule, sorted, e.g. "Ride.rider: no inverse".
    static func violations(in model: NSManagedObjectModel) -> [String] {
        model.entities.flatMap { entity -> [String] in
            let entityName = entity.name ?? "?"
            var lines: [String] = []
            if !entity.uniquenessConstraints.isEmpty { lines.append("\(entityName): unique constraint") }
            for attribute in entity.attributesByName.values where !attribute.isOptional && attribute.defaultValue == nil {
                lines.append("\(entityName).\(attribute.name): not optional and no default")
            }
            for relationship in entity.relationshipsByName.values {
                let name = "\(entityName).\(relationship.name)"
                if !relationship.isOptional { lines.append("\(name): not optional") }
                if relationship.isOrdered { lines.append("\(name): ordered") }
                if relationship.deleteRule == .denyDeleteRule { lines.append("\(name): deny rule") }
                if let inverse = relationship.inverseRelationship {
                    if inverse.inverseRelationship?.name != relationship.name || inverse.destinationEntity?.name != entityName {
                        lines.append("\(name): inverse does not point back")
                    }
                } else {
                    lines.append("\(name): no inverse")
                }
            }
            return lines
        }.sorted()
    }
}

// A model that breaks the rules, to show the check finds them.

@Model
final class BrokenOwner {
    var name: String = ""
    @Relationship(deleteRule: .deny) var items: [BrokenItem]? = []
    var loner: BrokenLoner
    init(loner: BrokenLoner) { self.loner = loner }
}

@Model
final class BrokenItem {
    @Attribute(.unique) var code: String = ""
    var serial: Int
    var owner: BrokenOwner?
    /// No property on the other side points back.
    var tag: BrokenLoner?
    init(serial: Int) { self.serial = serial }
}

@Model
final class BrokenLoner {
    var name: String = ""
    @Relationship(inverse: \BrokenOwner.loner) var owners: [BrokenOwner]? = []
    init() {}
}
