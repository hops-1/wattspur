import Foundation
import ImageIO
import UniformTypeIdentifiers

/// What the profile and the bike editor accept as input (PROF-01, PROF-03).
/// Out-of-range numbers are rejected instead of being stored: a weight of 7 kg
/// would only ever come from a typo and would spoil the calorie estimate (B-067).
public enum ProfileInput {
    public static let weightKg: ClosedRange<Double> = 20...300
    public static let heightCm: ClosedRange<Double> = 80...250
    public static let bikeWeightKg: ClosedRange<Double> = 1...100
    public static let batteryWh: ClosedRange<Int> = 50...3000
    public static let startKilometers: ClosedRange<Double> = 0...200_000

    /// Birth years from 1900 up to the current year (so the age is never negative).
    public static func birthYears(now: Date = .now, calendar: Calendar = .current) -> ClosedRange<Int> {
        1900...max(1900, calendar.component(.year, from: now))
    }

    /// The value if it lies in the range, else `nil`.
    public static func accepted<T: Comparable>(_ value: T?, in range: ClosedRange<T>) -> T? {
        guard let value, range.contains(value) else { return nil }
        return value
    }
}

/// Scales a picked photo down before it is stored, so that a 40 MB camera image
/// does not end up in the library (and, later, in iCloud) for a 150 pt tile.
public enum PhotoScaler {
    /// A JPEG of the image with its longer edge at most `maxEdge` pixels (never
    /// enlarged), or `nil` if the data is no readable image.
    public static func jpegData(from data: Data, maxEdge: Int, quality: Double = 0.8) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // respects the camera's rotation
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxEdge),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// Width and height in pixels of image data, or `nil` if it is no image.
    public static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (width, height)
    }
}
