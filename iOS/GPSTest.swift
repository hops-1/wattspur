import CoreLocation
import Foundation
import Observation
import UIKit
import WattspurCore

/// The GPS test of the spike V-14: records with `CLLocationUpdate.liveUpdates(.fitness)` while
/// the screen is locked and measures what the real recording (B-211) needs to know: how often a
/// point comes, how accurate it is, whether points keep coming in the background, and how much
/// battery a ride costs. Every point goes straight into a CSV file, so a crash loses nothing.
@MainActor @Observable
final class GPSTest {
    private(set) var isRunning = false
    private(set) var start: Date?
    private(set) var end: Date?
    /// All updates with a location, and those of them that arrived while the app was in the background.
    private(set) var points = 0
    private(set) var backgroundPoints = 0
    /// Updates that said the device is standing still (the system then sends fewer points).
    private(set) var stationaryUpdates = 0
    /// Breaks of more than 10 seconds between two points while not standing still.
    private(set) var gaps = 0
    private(set) var longestGap: TimeInterval = 0
    /// Distance over the points with an accuracy of 20 m or better.
    private(set) var distance: Double = 0
    private(set) var meanAccuracy: Double?
    private(set) var batteryAtStart: Float?
    private(set) var batteryNow: Float?
    /// What the system reported last, e.g. “Location access denied”.
    private(set) var status: String?
    private(set) var samples: [RideSample] = []

    private var accuracySum: Double = 0
    private var last: CLLocation?
    private var lastWasStationary = false
    private var task: Task<Void, Never>?
    private var backgroundSession: CLBackgroundActivitySession?
    private var serviceSession: CLServiceSession?
    private var log: FileHandle?

    /// The CSV of the running or last test, in the app's own documents.
    let logURL = URL.documentsDirectory.appending(path: "GPS-Test.csv")

    func startTest() {
        guard !isRunning else { return }
        reset()
        isRunning = true
        start = .now
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryAtStart = Self.battery()
        batteryNow = batteryAtStart

        FileManager.default.createFile(atPath: logURL.path,
                                       contents: Data("time,latitude,longitude,altitude,horizontalAccuracy,verticalAccuracy,speed,stationary,background\n".utf8))
        log = try? FileHandle(forWritingTo: logURL)
        log?.seekToEndOfFile()

        // Both sessions must start while the app is in front: the service session asks for
        // “While Using”, the background session keeps the updates coming when the screen is locked.
        serviceSession = CLServiceSession(authorization: .whenInUse)
        backgroundSession = CLBackgroundActivitySession()
        task = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(.fitness) {
                    guard let self, self.isRunning else { break }
                    self.handle(update)
                }
            } catch {
                self?.status = error.localizedDescription
            }
        }
    }

    func stopTest() {
        guard isRunning else { return }
        isRunning = false
        end = .now
        batteryNow = Self.battery()
        task?.cancel()
        task = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
        serviceSession?.invalidate()
        serviceSession = nil
        try? log?.close()
        log = nil
    }

    /// The test as GPX, for handing it to the Mac like a recorded ride.
    func gpx(name: String) -> Data? {
        guard let start, !samples.isEmpty else { return nil }
        return GPXWriter.document(name: name, segments: [.init(startDate: start, samples: samples)],
                                  creator: "Wattspur iOS")
    }

    var duration: TimeInterval {
        guard let start else { return 0 }
        return (end ?? .now).timeIntervalSince(start)
    }

    private func handle(_ update: CLLocationUpdate) {
        if update.authorizationDenied || update.authorizationDeniedGlobally {
            status = String(localized: "Location access denied")
        } else if update.accuracyLimited {
            status = String(localized: "Only approximate location allowed")
        } else if update.locationUnavailable {
            status = String(localized: "No location at the moment")
        } else {
            status = nil
        }
        if update.stationary { stationaryUpdates += 1 }
        guard let location = update.location, let start else { return }

        let inBackground = UIApplication.shared.applicationState == .background
        points += 1
        if inBackground { backgroundPoints += 1 }
        accuracySum += location.horizontalAccuracy
        meanAccuracy = accuracySum / Double(points)
        batteryNow = Self.battery()

        if let last {
            let gap = location.timestamp.timeIntervalSince(last.timestamp)
            if gap > 10, !lastWasStationary { gaps += 1 }
            longestGap = max(longestGap, gap)
            if location.horizontalAccuracy <= 20, last.horizontalAccuracy <= 20 {
                distance += location.distance(from: last)
            }
        }
        last = location
        lastWasStationary = update.stationary

        let time = location.timestamp.timeIntervalSince(start)
        samples.append(RideSample(time: time, latitude: location.coordinate.latitude,
                                  longitude: location.coordinate.longitude,
                                  altitude: location.verticalAccuracy > 0 ? location.altitude : nil,
                                  distance: distance,
                                  speed: location.speed >= 0 ? location.speed : nil))
        let line = [String(format: "%.1f", time),
                    String(format: "%.6f", location.coordinate.latitude),
                    String(format: "%.6f", location.coordinate.longitude),
                    String(format: "%.1f", location.altitude),
                    String(format: "%.1f", location.horizontalAccuracy),
                    String(format: "%.1f", location.verticalAccuracy),
                    String(format: "%.2f", location.speed),
                    update.stationary ? "1" : "0",
                    inBackground ? "1" : "0"].joined(separator: ",") + "\n"
        log?.write(Data(line.utf8))
    }

    private func reset() {
        start = nil
        end = nil
        points = 0
        backgroundPoints = 0
        stationaryUpdates = 0
        gaps = 0
        longestGap = 0
        distance = 0
        meanAccuracy = nil
        accuracySum = 0
        last = nil
        lastWasStationary = false
        status = nil
        samples = []
    }

    /// 0…1, or `nil` where the level is unknown (simulator).
    private static func battery() -> Float? {
        let level = UIDevice.current.batteryLevel
        return level < 0 ? nil : level
    }
}
