import Foundation
import WattspurCore

// Makes a FIT export safe to ship as the sample ride (V-05, NFR-12).
//
//   swift run anonymize-fit <input.fit> <output.fit> --lat <degrees> --lon <degrees> [--weeks <n>] [--trim <metres>]
//
// Choose the offset yourself and do not commit it: with the offset, the route
// can be moved back. The start and end stay hidden either way.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let usage = "usage: anonymize-fit <input.fit> <output.fit> --lat <degrees> --lon <degrees> [--weeks <n>] [--trim <metres>]"
var arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("--help") || arguments.count < 2 { fail(usage) }
let input = URL(fileURLWithPath: arguments.removeFirst())
let output = URL(fileURLWithPath: arguments.removeFirst())

var options: [String: Double] = [:]
while let key = arguments.first {
    guard arguments.count >= 2, let value = Double(arguments[1]) else { fail(usage) }
    options[key] = value
    arguments.removeFirst(2)
}
guard let lat = options["--lat"], let lon = options["--lon"] else { fail(usage) }

let anonymizer = FITAnonymizer(
    latitudeOffset: lat, longitudeOffset: lon,
    trimDistance: options["--trim"] ?? 500,
    weeks: Int(options["--weeks"] ?? 0)
)

do {
    let data = try Data(contentsOf: input)
    let result = try anonymizer.anonymize(data)
    try result.write(to: output)
    let ride = try FITRideImporter().parse(result)
    let positions = ride.samples.filter { $0.latitude != nil }.count
    print("Wrote \(output.lastPathComponent): \(ride.samples.count) samples, \(positions) with position, start \(ride.startDate)")
} catch {
    fail("error: \(error)")
}
