import CoreData
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
}
