import Foundation
import Testing
@testable import WattspurCore
import TestFixtures

@Suite("Calories with profile")
struct CalorieModelTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// 15 October 2026 and 15 October 2025, noon UTC.
    let in2026 = Date(timeIntervalSince1970: 1_792_065_600)
    let in2025 = Date(timeIntervalSince1970: 1_760_529_600)

    private func profile(sex: RiderSex = .male) -> BodyProfile {
        BodyProfile(weightKg: 78, heightCm: 182, birthYear: 1988, sex: sex)
    }

    private func ride(work: Double = 320, time: TimeInterval = 3_600, date: Date? = nil) -> RideFigures {
        RideFigures(startDate: date ?? in2026, distance: 20_000, timerTime: time, workKilojoules: work, averagePower: 100)
    }

    @Test("Mifflin-St Jeor: 10 × kg + 6.25 × cm − 5 × age + 5, − 161 or the mean − 78")
    func basalMetabolicRate() throws {
        // 780 + 1137.5 − 5 × 38 = 1727.5
        #expect(try #require(profile(sex: .male).basalKilocaloriesPerDay(on: in2026, calendar: calendar)) == 1_732.5)
        #expect(try #require(profile(sex: .female).basalKilocaloriesPerDay(on: in2026, calendar: calendar)) == 1_566.5)
        #expect(try #require(profile(sex: .unspecified).basalKilocaloriesPerDay(on: in2026, calendar: calendar)) == 1_649.5)
    }

    @Test("The age follows from the birth year and the year of the ride")
    func ageFollowsRide() throws {
        let p = profile()
        #expect(p.age(on: in2026, calendar: calendar) == 38)
        #expect(p.age(on: in2025, calendar: calendar) == 37)
        // A year older means 5 kcal a day less.
        let older = try #require(p.basalKilocaloriesPerDay(on: in2026, calendar: calendar))
        let younger = try #require(p.basalKilocaloriesPerDay(on: in2025, calendar: calendar))
        #expect(younger - older == 5)
    }

    @Test("Age is never negative and missing without a birth year")
    func ageEdges() {
        #expect(BodyProfile(birthYear: 2030).age(on: in2026, calendar: calendar) == 0)
        #expect(BodyProfile().age(on: in2026, calendar: calendar) == nil)
    }

    @Test("Without weight, height or birth year there is no basal metabolic rate, and the list says what is missing")
    func missing() {
        #expect(BodyProfile().missing == [.weight, .height, .birthYear])
        #expect(BodyProfile(weightKg: 78, heightCm: 182).missing == [.birthYear])
        #expect(BodyProfile(weightKg: 78, heightCm: 182).basalKilocaloriesPerDay(on: in2026, calendar: calendar) == nil)
        #expect(profile().isComplete)
        // The sex is no required field: "not specified" is a valid choice.
        #expect(BodyProfile(weightKg: 78, heightCm: 182, birthYear: 1988).isComplete)
    }

    /// 320 kJ in one hour in the mode "from work": 0.97 × 320 + 64 kcal.
    private let flowKcal = 320 * 0.97 + 64
    /// The same work in "with profile": the work part without the time share.
    private let profileWork = 320 * CalorieModel.profileFactor

    @Test("From work: like the Flow app, work × 0.97 plus 64 kcal per hour of ride time")
    func fromWork() {
        let model = CalorieModel.fromWork
        #expect(abs(model.kilocalories(for: ride(), calendar: calendar) - flowKcal) < 1e-9)
        #expect(abs(model.kilocalories(for: ride(time: 1_800), calendar: calendar) - (320 * 0.97 + 32)) < 1e-9)
        // The profile is ignored in this mode.
        let withData = CalorieModel(mode: .fromWork, profile: profile())
        #expect(withData.kilocalories(for: ride(), calendar: calendar) == model.kilocalories(for: ride(), calendar: calendar))
        #expect(!withData.usesProfile)
        #expect(withData.fallbackFields.isEmpty)
    }

    @Test("The Flow values (V-01): six rides within the rounding, the old factor 1.125 is off by up to 7 %")
    func flowValues() {
        // kJ, ride time in seconds, kcal shown in the Flow app (V-01, Nils' rides, 25 October 2026).
        let flow: [(kJ: Double, seconds: TimeInterval, kcal: Double)] = [
            (1_312.2, 17_397, 1_584), (1_015.6, 10_897, 1_181), (32.3, 426, 38),
            (391.8, 3_535, 443), (319.7, 2_916, 360), (206.4, 2_004, 239),
        ]
        for ride in flow {
            let kcal = CalorieModel.fromWork.kilocalories(workKilojoules: ride.kJ, rideTime: ride.seconds, on: in2026, calendar: calendar)
            #expect(abs(kcal - ride.kcal) <= 4, "\(ride.kJ) kJ: \(kcal) instead of \(ride.kcal) kcal")
        }
        // The old single factor misses the long ride with little power by 107 kcal.
        #expect(abs(1_312.2 * 1.125 - 1_584) > 100)
    }

    @Test("With profile: work × factor plus the basal metabolic rate over the ride time")
    func withProfile() {
        let model = CalorieModel(mode: .withProfile, profile: profile())
        // One hour: 1732.5 / 24 = 72.1875 kcal on top of the work.
        #expect(abs(model.kilocalories(for: ride(), calendar: calendar) - (profileWork + 72.1875)) < 1e-9)
        // Twice the time, twice the basal part; the work stays.
        #expect(abs(model.kilocalories(for: ride(time: 7_200), calendar: calendar) - (profileWork + 144.375)) < 1e-9)
        #expect(model.usesProfile)
        #expect(model.fallbackFields.isEmpty)
    }

    @Test("A ride without work still burns the basal part while riding")
    func noWork() {
        let model = CalorieModel(mode: .withProfile, profile: profile())
        #expect(abs(model.kilocalories(for: ride(work: 0, time: 1_800), calendar: calendar) - 36.09375) < 1e-9)
    }

    @Test("Incomplete body data fall back to \"from work\" and name what is missing")
    func fallback() {
        let incomplete = CalorieModel(mode: .withProfile, profile: BodyProfile(weightKg: 78, heightCm: nil, birthYear: 1988))
        #expect(incomplete.kilocalories(for: ride(), calendar: calendar) == CalorieModel.fromWork.kilocalories(for: ride(), calendar: calendar))
        #expect(!incomplete.usesProfile)
        #expect(incomplete.fallbackFields == [.height])
        let none = CalorieModel(mode: .withProfile, profile: nil)
        #expect(none.fallbackFields == [.weight, .height, .birthYear])
        #expect(abs(none.kilocalories(for: ride(), calendar: calendar) - flowKcal) < 1e-9)
    }

    @Test("The factor can be changed; the profile part does not depend on it")
    func factor() {
        let model = CalorieModel(mode: .withProfile, factor: 1.2, profile: profile())
        #expect(abs(model.kilocalories(for: ride(), calendar: calendar) - (320 * 1.2 + 72.1875)) < 1e-9)
    }

    @Test("Mode raw values are fixed: they live in the settings")
    func rawValues() {
        #expect(CalorieMode.fromWork.rawValue == "work")
        #expect(CalorieMode.withProfile.rawValue == "profile")
        #expect(CalorieMode(rawValue: "profile") == .withProfile)
    }

    @Test("Sums add each ride with its own age; the default is unchanged")
    func aggregate() {
        let rides = [ride(date: in2026), ride(date: in2025)]
        let plain = RideAggregate(rides)
        #expect(abs(plain.kilocalories - (640 * 0.97 + 128)) < 1e-9)
        let model = CalorieModel(mode: .withProfile, profile: profile())
        let with = RideAggregate(rides, calories: model)
        // 2026: 1732.5 / 24; 2025 one year younger: 1737.5 / 24.
        #expect(abs(with.kilocalories - (2 * profileWork + (1_732.5 + 1_737.5) / 24)) < 1e-6)
    }

    @Test("The comparison uses the model for calories and calories per kilometre")
    func comparison() throws {
        let figures = ComparisonFigures(timerTime: 3_600, elapsedTime: 3_900, distance: 20_000, averagePower: 100, workKilojoules: 320, startDate: in2026)
        let model = CalorieModel(mode: .withProfile, profile: profile())
        let kcal = try #require(ComparisonMetric.calories.value(of: figures, calories: model))
        #expect(abs(kcal - (profileWork + 72.1875)) < 1e-9)
        let perKm = try #require(ComparisonMetric.caloriesPerKilometre.value(of: figures, calories: model))
        #expect(abs(perKm - kcal / 20) < 1e-9)
        // Without a model: as before.
        #expect(abs(try #require(ComparisonMetric.calories.value(of: figures)) - flowKcal) < 1e-9)
    }
}
