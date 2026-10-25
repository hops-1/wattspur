import Foundation

/// How calories are estimated (SET-06, REQUIREMENTS.md 3.4, 10.16). The raw values are
/// stored in the settings, so they must not change.
public enum CalorieMode: String, CaseIterable, Identifiable, Sendable {
    /// As the Bosch Flow app does (the default): work × 0.97 plus a fixed 64 kcal per hour of
    /// ride time. Needs no body data; the Flow app has none either.
    case fromWork = "work"
    /// Our own estimate: work ÷ 25 % efficiency plus the basal metabolic rate over the ride
    /// time, from the profile. Differs from Flow by design.
    case withProfile = "profile"

    public var id: Self { self }
}

/// The body data of the rider the calorie estimate "with profile" needs (PROF-01).
public struct BodyProfile: Sendable, Equatable {
    public var weightKg: Double?
    public var heightCm: Double?
    public var birthYear: Int?
    public var sex: RiderSex

    /// What a complete profile needs; the sex is optional ("not specified" is a choice).
    public enum Field: Sendable, Equatable { case weight, height, birthYear }

    public init(weightKg: Double? = nil, heightCm: Double? = nil, birthYear: Int? = nil, sex: RiderSex = .unspecified) {
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.birthYear = birthYear
        self.sex = sex
    }

    /// The fields that are still empty.
    public var missing: [Field] {
        var fields: [Field] = []
        if weightKg == nil { fields.append(.weight) }
        if heightCm == nil { fields.append(.height) }
        if birthYear == nil { fields.append(.birthYear) }
        return fields
    }

    public var isComplete: Bool { missing.isEmpty }

    /// Age on a date in whole years of difference between the years: only the birth year
    /// is known. `nil` without a birth year; never negative.
    public func age(on date: Date, calendar: Calendar = .current) -> Int? {
        birthYear.map { max(0, calendar.component(.year, from: date) - $0) }
    }

    /// Basal metabolic rate in kcal per day after Mifflin-St Jeor:
    /// 10 × kg + 6.25 × cm − 5 × age + 5 (male) or − 161 (female). "Not specified"
    /// takes the mean of both, − 78. `nil` while weight, height or birth year is missing.
    public func basalKilocaloriesPerDay(on date: Date, calendar: Calendar = .current) -> Double? {
        guard let weightKg, let heightCm, let age = age(on: date, calendar: calendar) else { return nil }
        let offset: Double = switch sex {
        case .male: 5
        case .female: -161
        case .unspecified: (5 - 161) / 2
        }
        return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + offset
    }
}

extension Rider {
    public var bodyProfile: BodyProfile {
        BodyProfile(weightKg: weightKg, heightCm: heightCm, birthYear: birthYear, sex: sex)
    }
}

/// Calories of a ride in the chosen mode (B-067, V-01). Without enough body data the mode
/// "with profile" falls back to "from work"; `fallbackFields` says what is missing, so
/// the app can tell.
///
/// "From work" copies the Flow app: a least-squares fit to six Flow values (rides of 7 min
/// to 4:50 h, 32 to 1312 kJ) reproduces them within 3 kcal, which is the rounding. Flow counts
/// a share per hour of ride time that does not depend on the rider (Flow has no body data),
/// so a single kcal per kJ factor cannot match it (ratios from 1.126 to 1.207).
public struct CalorieModel: Sendable, Equatable {
    public var mode: CalorieMode
    /// kcal per kJ of mechanical work in the mode "with profile": 1 / (efficiency × 4.184 kJ/kcal)
    /// at 25 % efficiency. The basal metabolic rate comes on top; the old factor 1.125 (about
    /// 21 %) would count it twice.
    public var factor: Double
    public var profile: BodyProfile?

    /// "From work": kcal per kJ of work, about 24.6 % efficiency (fit to Flow values).
    public static let flowFactor = 0.97
    /// "From work": kcal per hour of ride time, independent of the rider (fit to Flow values).
    public static let flowKilocaloriesPerHour = 64.0
    /// "With profile": the assumed efficiency of pedalling.
    public static let profileEfficiency = 0.25
    public static let profileFactor = 1 / (profileEfficiency * 4.184)
    /// Which time the basal metabolic rate runs over: the ride time (without pauses; the
    /// Flow values fit the ride time, not the total time).
    public static let secondsPerDay = 86_400.0

    public static let fromWork = CalorieModel()

    public init(mode: CalorieMode = .fromWork, factor: Double = CalorieModel.profileFactor, profile: BodyProfile? = nil) {
        self.mode = mode
        self.factor = factor
        self.profile = profile
    }

    /// `true` if the numbers include the basal metabolic rate.
    public var usesProfile: Bool { mode == .withProfile && profile?.isComplete == true }

    /// What "with profile" lacks; empty in the mode "from work" and with a complete profile.
    public var fallbackFields: [BodyProfile.Field] {
        guard mode == .withProfile else { return [] }
        return profile?.missing ?? [.weight, .height, .birthYear]
    }

    /// Calories of a ride from its work, its ride time and the date it started on (for the
    /// age; today if unknown).
    public func kilocalories(workKilojoules: Double, rideTime: TimeInterval, on date: Date?, calendar: Calendar = .current) -> Double {
        guard mode == .withProfile, let perDay = profile?.basalKilocaloriesPerDay(on: date ?? .now, calendar: calendar) else {
            return workKilojoules * Self.flowFactor + Self.flowKilocaloriesPerHour * rideTime / 3_600
        }
        return workKilojoules * factor + perDay * rideTime / Self.secondsPerDay
    }

    public func kilocalories(for ride: RideFigures, calendar: Calendar = .current) -> Double {
        kilocalories(workKilojoules: ride.workKilojoules, rideTime: ride.timerTime, on: ride.startDate, calendar: calendar)
    }

    public func kilocalories(for ride: ComparisonFigures, calendar: Calendar = .current) -> Double {
        kilocalories(workKilojoules: ride.workKilojoules, rideTime: ride.timerTime, on: ride.startDate, calendar: calendar)
    }
}
