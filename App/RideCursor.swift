import AppKit
import Observation
import SwiftUI
import WattspurKit

/// The spot on the ride that the four charts and the map show together (B-062, TOUR-06):
/// hovering a chart or the route sets it, a click holds it, another click or Esc lets go.
@MainActor
@Observable
final class RideCursor {
    typealias Fix = RideTrack.Fix

    private(set) var track = RideTrack(samples: [])
    private(set) var hover: Fix?
    private(set) var held: Fix?

    /// What charts and map show: the held spot, else the one under the mouse.
    var current: Fix? { held ?? hover }
    var isHeld: Bool { held != nil }

    /// A new ride: forget the old spot.
    func reset(track: RideTrack) {
        self.track = track
        hover = nil
        held = nil
    }

    /// The mouse is over a chart at `x` (kilometres or minutes since the start).
    func hover(atX x: Double, axis: ChartAxis) {
        let fix = axis == .distance ? track.fix(atDistanceKm: x) : track.fix(atTime: x * 60)
        if fix != hover { hover = fix }
    }

    /// The mouse is over the map at a position, `metres` being how close it has to be to the route.
    func hover(latitude: Double, longitude: Double, within metres: Double) {
        let found = track.fix(nearestToLatitude: latitude, longitude: longitude)
        let fix = found.flatMap { $0.metres <= metres ? $0.fix : nil }
        if fix != hover { hover = fix }
    }

    func endHover() {
        if hover != nil { hover = nil }
    }

    /// A click: holds the spot under the mouse, or lets go of the held one.
    func toggleHold() {
        if held != nil {
            release()
        } else if let hover {
            held = hover
            announce(String(localized: "Position held at \(describe(hover))"))
        }
    }

    func release() {
        guard held != nil else { return }
        held = nil
        announce(String(localized: "Position released"))
    }

    /// "12.3 km, 0:35: elevation 210 m, speed 24.1 km/h, …" for VoiceOver.
    private func describe(_ fix: Fix) -> String {
        let km = fix.distanceKm.formatted(.number.precision(.fractionLength(1)))
        let minutes = Int((fix.time / 60).rounded())
        var parts: [String] = []
        if let v = fix.altitude { parts.append("\(String(localized: "Elevation")) \(Int(v.rounded())) m") }
        if let v = fix.speedKmh { parts.append("\(String(localized: "Speed")) \(v.formatted(.number.precision(.fractionLength(1)))) km/h") }
        if let v = fix.cadence { parts.append("\(String(localized: "Cadence")) \(Int(v.rounded())) \(String(localized: "rpm"))") }
        if let v = fix.power { parts.append("\(String(localized: "Power")) \(Int(v.rounded())) W") }
        return "\(km) km, \(minutes / 60):" + String(format: "%02d", minutes % 60) + ": " + parts.joined(separator: ", ")
    }

    private func announce(_ text: String) {
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }
}
