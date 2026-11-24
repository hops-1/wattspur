import CoreData
import Foundation
import SwiftData
import Testing
@testable import WattspurKit

/// The Core Data model `LibrarySync.initializeCloudKitSchema` sends to CloudKit (B-219).
@Suite("CloudKit schema")
struct CloudKitSchemaTests {
    @Test("The model made from the SwiftData models has every synced type")
    func everyType() throws {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: WattspurSchema.models))
        let names = Set(model.entities.compactMap(\.name))
        #expect(names == ["Ride", "Rider", "Bike", "SourceFile", "ImportRecord", "Goal", "RouteGroup"])
    }

    /// The schema is in production (rule 2 in docs/ARCHITECTURE.md): every field of the snapshot
    /// must still be there with the same type; new fields are fine if they are optional or have a
    /// default (B-353, S-14). After adding a field, add its line to `CloudKitSchema.txt`; the
    /// failure message prints the whole current snapshot.
    @Test("No synced field was renamed, removed or retyped since the snapshot")
    func matchesSnapshot() throws {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: WattspurSchema.models))
        let current = SchemaSnapshot.lines(of: model)
        let url = try #require(Bundle.module.url(forResource: "CloudKitSchema", withExtension: "txt"))
        let snapshot = SchemaSnapshot.parse(try String(contentsOf: url, encoding: .utf8))
        let problems = SchemaSnapshot.problems(snapshot: snapshot, current: current)
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))\n\nCurrent schema:\n\(current.joined(separator: "\n"))")
    }

    @Test("A renamed, removed or retyped field breaks the check, a new optional field does not")
    func comparison() {
        let snapshot = [
            "Ride.name | string | optional",
            "Ride.distance | double | default",
            "Ride.bike | to-one Bike | optional",
        ]
        #expect(SchemaSnapshot.problems(snapshot: snapshot, current: snapshot).isEmpty)

        let renamed = ["Ride.title | string | optional", snapshot[1], snapshot[2]]
        #expect(SchemaSnapshot.problems(snapshot: snapshot, current: renamed).count == 1)

        let removed = [snapshot[0], snapshot[2]]
        #expect(SchemaSnapshot.problems(snapshot: snapshot, current: removed).count == 1)

        let retyped = [snapshot[0], "Ride.distance | integer 64 | default", snapshot[2]]
        #expect(!SchemaSnapshot.problems(snapshot: snapshot, current: retyped).isEmpty)

        let newOptional = snapshot + ["Ride.note | string | optional"]
        #expect(SchemaSnapshot.problems(snapshot: snapshot, current: newOptional).isEmpty)

        let newDefault = snapshot + ["Ride.count | integer 64 | default"]
        #expect(SchemaSnapshot.problems(snapshot: snapshot, current: newDefault).isEmpty)

        let newRequired = snapshot + ["Ride.note | string | required"]
        #expect(SchemaSnapshot.problems(snapshot: snapshot, current: newRequired).count == 1)
    }
}

/// One line per synced field: `Type.field | data type | optional, default or required`.
enum SchemaSnapshot {
    static func lines(of model: NSManagedObjectModel) -> [String] {
        model.entities.flatMap { entity -> [String] in
            let type = entity.name ?? "?"
            return entity.properties.compactMap { property in
                let kind: String
                switch property {
                case let attribute as NSAttributeDescription:
                    kind = typeName(attribute.attributeType)
                case let relationship as NSRelationshipDescription:
                    let target = relationship.destinationEntity?.name ?? "?"
                    kind = "\(relationship.isToMany ? "to-many" : "to-one") \(target)"
                default:
                    return nil
                }
                return "\(type).\(property.name) | \(kind) | \(presence(of: property))"
            }
        }
        .sorted()
    }

    static func parse(_ text: String) -> [String] {
        text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    /// What breaks the production schema: a snapshot line that is gone (renamed, removed or
    /// retyped field), or a new field CloudKit cannot take (neither optional nor with a default).
    static func problems(snapshot: [String], current: [String]) -> [String] {
        let now = Set(current)
        let before = Set(snapshot)
        let missing = snapshot.filter { !now.contains($0) }.map { "Changed or removed: \($0)" }
        let required = current.filter { !before.contains($0) && $0.hasSuffix("| required") }
            .map { "New field without default: \($0)" }
        return missing + required
    }

    private static func presence(of property: NSPropertyDescription) -> String {
        if property.isOptional { return "optional" }
        // Only that there is a default: its value may be the time or a new UUID, and changing it
        // does not break the production schema.
        if let attribute = property as? NSAttributeDescription, attribute.defaultValue != nil {
            return "default"
        }
        return "required"
    }

    private static func typeName(_ type: NSAttributeType) -> String {
        switch type {
        case .integer16AttributeType: "integer 16"
        case .integer32AttributeType: "integer 32"
        case .integer64AttributeType: "integer 64"
        case .decimalAttributeType: "decimal"
        case .doubleAttributeType: "double"
        case .floatAttributeType: "float"
        case .stringAttributeType: "string"
        case .booleanAttributeType: "boolean"
        case .dateAttributeType: "date"
        case .binaryDataAttributeType: "binary"
        case .UUIDAttributeType: "uuid"
        case .URIAttributeType: "uri"
        case .transformableAttributeType: "transformable"
        case .objectIDAttributeType: "object id"
        case .compositeAttributeType: "composite"
        default: "type \(type.rawValue)"
        }
    }
}
