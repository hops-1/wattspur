import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import WattspurCore
import TestFixtures

@Suite("Profile input")
struct ProfileInputTests {
    @Test("Values inside the range are accepted, others are not", arguments: [
        (78.0, 78.0 as Double?), (20, 20), (300, 300), (19.9, nil), (301, nil), (-5, nil), (0, nil),
    ])
    func weights(value: Double, expected: Double?) {
        #expect(ProfileInput.accepted(value, in: ProfileInput.weightKg) == expected)
    }

    @Test("Nothing stays nothing")
    func missing() {
        #expect(ProfileInput.accepted(nil as Double?, in: ProfileInput.heightCm) == nil)
    }

    @Test("Birth years run from 1900 to the current year")
    func birthYears() {
        let now = Date(timeIntervalSince1970: 1_792_000_000)   // October 2026
        let years = ProfileInput.birthYears(now: now, calendar: Calendar(identifier: .gregorian))
        #expect(years == 1900...2026)
        #expect(ProfileInput.accepted(1988, in: years) == 1988)
        #expect(ProfileInput.accepted(2027, in: years) == nil)
        #expect(ProfileInput.accepted(1899, in: years) == nil)
    }

    @Test("Start mileage may be zero but not negative")
    func startKilometers() {
        #expect(ProfileInput.accepted(0.0, in: ProfileInput.startKilometers) == 0)
        #expect(ProfileInput.accepted(-1.0, in: ProfileInput.startKilometers) == nil)
    }
}

@Suite("Photo scaler")
struct PhotoScalerTests {
    /// A PNG of the given size with some colour.
    private func png(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    @Test("A large photo shrinks to the longer edge and keeps its proportions")
    func shrinks() throws {
        let scaled = try #require(PhotoScaler.jpegData(from: try png(width: 4000, height: 3000), maxEdge: 1000))
        let size = try #require(PhotoScaler.pixelSize(of: scaled))
        #expect(size.width == 1000)
        #expect(size.height == 750)
    }

    @Test("A small photo is not enlarged")
    func notEnlarged() throws {
        let scaled = try #require(PhotoScaler.jpegData(from: try png(width: 300, height: 200), maxEdge: 1000))
        let size = try #require(PhotoScaler.pixelSize(of: scaled))
        #expect(size.width <= 300 && size.height <= 200)
    }

    @Test("The result is a JPEG")
    func isJPEG() throws {
        let scaled = try #require(PhotoScaler.jpegData(from: try png(width: 200, height: 200), maxEdge: 100))
        #expect(Array(scaled.prefix(2)) == [0xFF, 0xD8])
    }

    @Test("Data that is no image gives nothing")
    func noImage() {
        #expect(PhotoScaler.jpegData(from: Data("hello".utf8), maxEdge: 100) == nil)
        #expect(PhotoScaler.pixelSize(of: Data()) == nil)
    }
}
