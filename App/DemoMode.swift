#if DEBUG
import Foundation
import SwiftData
import WattspurKit

/// Debug builds only: a library in memory that holds just the sample ride, for
/// screenshots in the user guide without real rides (B-080, NFR-12).
///
///   open -n -a Wattspur.app --args -WattspurDemo YES -setupCompleted YES \
///       -watchFolderEnabled NO -watchFolderBookmark "" [-WattspurDemoWindow settings|importLog]
///
/// The extra arguments only mask the stored settings for this launch (argument
/// domain of `UserDefaults`); nothing is written to the real library or settings.
/// `-WattspurDemoSection analysis|highlights|records|goals|map|profile` opens that section instead of the rides.
/// `-WattspurDemoRides 2` adds that many copies of the sample ride as ordinary
/// rides, one week apart, e.g. to try merging rides (B-095).
/// `-bikesHintDone YES` hides the note "Set up your bikes" after the update to 1.5 (B-138).
/// `-WattspurDemoBikes YES` adds two more bikes with the demo rides spread over them (B-134).
/// `-WattspurDemoGoals YES` adds a weekly, a monthly and a yearly goal (B-053).
/// `-WattspurDemoVariety YES` makes the copies slightly different in time, speed and power (older = slower), so a history has a trend (B-179).
/// `-WattspurDemoSize 1100x740` sets the size of the main window in points (B-179).
/// `-WattspurDemoSimilar YES` opens "Similar rides" for "Demo 1" with no ride selected, i.e. its history (B-179).
/// `-WattspurDemoRoute "Commute"` saves the route of "Demo 1" under that name and shows it (B-179).
/// `-WattspurDemoSelect "Demo 8"` selects that ride instead of the sample ride.
/// `-WattspurDemoImport "/path/a.fit,/path/b.gpx"` imports these files into the demo library, in that
/// order, like a drop in the list (B-145): to try GPX rides without touching the real library.
@MainActor
enum DemoMode {
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "WattspurDemo") }
    /// A window to open on launch: "settings" or a window id.
    static var window: String? { UserDefaults.standard.string(forKey: "WattspurDemoWindow") }
    /// "new" or "edit": opens the bike editor in the profile.
    static var editor: String? { UserDefaults.standard.string(forKey: "WattspurDemoEditor") }
    static var size: CGSize? {
        guard let text = UserDefaults.standard.string(forKey: "WattspurDemoSize") else { return nil }
        let parts = text.split(separator: "x").compactMap { Double($0) }
        return parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : nil
    }
    static var similar: Bool { UserDefaults.standard.bool(forKey: "WattspurDemoSimilar") }
    static var routeName: String? { UserDefaults.standard.string(forKey: "WattspurDemoRoute") }
    static var section: String? { UserDefaults.standard.string(forKey: "WattspurDemoSection") }

    /// The sample ride, selected in the list on launch.
    private(set) static var rideID: UUID?

    static func makeContainer() throws -> ModelContainer {
        let container = try ModelContainer(for: Schema(WattspurSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        rideID = SampleRide.load(into: RideLibrary(context: container.mainContext))?.id
        addCopies(UserDefaults.standard.integer(forKey: "WattspurDemoRides"), to: container.mainContext)
        if let paths = UserDefaults.standard.string(forKey: "WattspurDemoImport") {
            let library = RideLibrary(context: container.mainContext)
            for path in paths.split(separator: ",") {
                library.importFile(at: URL(fileURLWithPath: String(path)))
            }
        }
        if let name = UserDefaults.standard.string(forKey: "WattspurDemoSelect"),
           let ride = try? container.mainContext.fetch(FetchDescriptor<Ride>()).first(where: { $0.name == name }) {
            rideID = ride.id
        }
        if UserDefaults.standard.bool(forKey: "WattspurDemoBikes") { addBikes(to: container.mainContext) }
        if UserDefaults.standard.bool(forKey: "WattspurDemoGoals") {
            container.mainContext.insert(Goal(metric: .distance, period: .week, target: 100_000))
            container.mainContext.insert(Goal(metric: .rides, period: .month, target: 4))
            container.mainContext.insert(Goal(metric: .ascent, period: .year, target: 2_000))
        }
        return container
    }

    /// Two more bikes, one archived, and the rides spread over them in turn.
    private static func addBikes(to context: ModelContext) {
        let library = RideLibrary(context: context)
        library.prepareBikes()
        let first = library.activeBike()
        first.kind = .bike
        first.driveUnit = "Bosch Performance Line CX"
        first.batteryWh = 625
        first.startKilometers = 400
        let gravel = library.makeBike(name: "Gravel", kind: .gravel, color: .orange)
        gravel.driveUnit = "Bosch Performance Line SX"
        gravel.batteryWh = 400
        let old = library.makeBike(name: "Old trekking bike", kind: .bike, color: .purple)
        old.driveUnit = "Bosch Active Line Plus"
        old.batteryWh = 500
        let rides = ((try? context.fetch(FetchDescriptor<Ride>())) ?? []).sorted { $0.startDate < $1.startDate }
        for (index, ride) in rides.enumerated() { ride.bike = [first, gravel, old][index % 3] }
        try? library.archive(old)
        try? context.save()
    }

    private static func addCopies(_ count: Int, to context: ModelContext) {
        guard count > 0, let url = Bundle.main.url(forResource: "SampleRide", withExtension: "fit"),
              let data = try? Data(contentsOf: url) else { return }
        let library = RideLibrary(context: context)
        let varied = UserDefaults.standard.bool(forKey: "WattspurDemoVariety")
        for week in 1...count {
            guard let copy = try? FITAnonymizer(latitudeOffset: 0, longitudeOffset: 0, trimDistance: 0, weeks: -week)
                .anonymize(data) else { continue }
            library.importFile(data: copy, fileName: "Demo \(week).fit")
        }
        guard varied else { return }
        // The older, the slower, with some wobble, so that the history shows a trend.
        let wobble = [0.02, -0.03, 0.04, -0.01, 0.03, -0.04, 0.01, -0.02]
        for ride in (try? context.fetch(FetchDescriptor<Ride>())) ?? [] {
            guard let week = Int(ride.name.dropFirst(5)), ride.name.hasPrefix("Demo ") else { continue }
            let factor = 1 + 0.012 * Double(week) + wobble[week % wobble.count]
            ride.timerTime *= factor
            ride.averageSpeed = ride.distance / ride.timerTime
            ride.averagePower = ride.averagePower.map { Int(Double($0) / factor) }
            ride.averageCadence = ride.averageCadence.map { Int(Double($0) / (1 + (factor - 1) / 2)) }
        }
        try? context.save()
    }
}
#endif
