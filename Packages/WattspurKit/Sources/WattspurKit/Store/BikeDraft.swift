import Foundation
import WattspurCore

/// The values the bike editor works on, on the Mac and on the iPhone (B-290); applied to the bike
/// only on "Save".
public struct BikeDraft: Equatable, Sendable {
    public var name = ""
    public var color: BikeColor = .blue
    public var kind: BikeKind = .bike
    public var isEbike = true
    public var photoData: Data?
    public var manufacturer = ""
    public var model = ""
    public var driveUnit = ""
    public var batteryWh: Int?
    public var weightKg: Double?
    public var purchaseDate: Date?
    public var startKilometers: Double?
    public var makeActive = false

    public init() {}

    public init(_ bike: Bike, isActive: Bool) {
        name = bike.name
        color = bike.color
        kind = bike.kind
        isEbike = bike.isEbike
        photoData = bike.photoData
        manufacturer = bike.manufacturer
        model = bike.model
        driveUnit = bike.driveUnit
        batteryWh = bike.batteryWh
        weightKg = bike.weightKg
        purchaseDate = bike.purchaseDate
        startKilometers = bike.startKilometers > 0 ? bike.startKilometers : nil
        makeActive = isActive
    }

    public func apply(to bike: Bike) {
        bike.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        bike.color = color
        bike.kind = kind
        // “E-bike” is a bicycle's switch only (B-284).
        bike.isEbike = kind.sport == .cycling && isEbike
        bike.photoData = photoData
        bike.manufacturer = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        bike.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        bike.driveUnit = driveUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        bike.batteryWh = batteryWh
        bike.weightKg = weightKg
        bike.purchaseDate = purchaseDate
        bike.startKilometers = startKilometers ?? 0
    }
}
