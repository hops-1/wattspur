import Foundation
import WattspurCore

/// What a GPX file becomes on import (B-372): the apps ask when its times look estimated
/// (`GPXContent.estimatedTimes`) and pass the answer; everything else imports `automatic`.
public enum ImportKind: Sendable, Equatable {
    /// A planned tour when the file has no times or is a komoot tour with estimated times
    /// (`GPXContent.isTourWithoutAsking`), else a ride. The watched folder on the Mac and every
    /// file without a question.
    case automatic
    /// A ride, also from estimated times; an iPhone recording always.
    case ride
    /// A planned tour, also from a file with times.
    case plannedTour

    func takesTour(_ content: @autoclosure () -> GPXContent) -> Bool {
        switch self {
        case .automatic: content().isTourWithoutAsking
        case .ride: false
        case .plannedTour: true
        }
    }
}
