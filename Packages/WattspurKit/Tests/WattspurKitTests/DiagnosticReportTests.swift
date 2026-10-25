import Foundation
import Testing
@testable import WattspurKit

@Suite("Diagnostic report")
struct DiagnosticReportTests {
    func report(log: [ImportLogEntry] = []) -> DiagnosticReport {
        DiagnosticReport(appVersion: "0.1.0", build: "1", commit: "4fd5f9b", parserVersion: 2,
                         osVersion: "Version 27.0.1", locale: "de_DE",
                         rideCount: 3, trashedRideCount: 1, ridesByParserVersion: [2: 2, 1: 1],
                         importLog: log, createdAt: Date(timeIntervalSince1970: 1_792_400_000))
    }

    @Test("Contains versions, system and counts")
    func basics() {
        let text = report().text
        #expect(text.contains("App version: 0.1.0 (build 1, commit 4fd5f9b)"))
        #expect(text.contains("Parser version: 2"))
        #expect(text.contains("macOS: Version 27.0.1"))
        #expect(text.contains("Rides: 3 (in trash: 1)"))
        #expect(text.contains("v1: 1, v2: 2"))
        #expect(text.contains("(no imports)"))
    }

    @Test("Lists the import log newest first")
    func importLog() {
        let old = ImportLogEntry(date: Date(timeIntervalSince1970: 1_792_300_000), fileName: "a.fit", outcome: "imported")
        let new = ImportLogEntry(date: Date(timeIntervalSince1970: 1_792_390_000), fileName: "b.fit", outcome: "failed: x")
        let text = report(log: [old, new]).text
        let a = text.range(of: "a.fit")!, b = text.range(of: "b.fit")!
        #expect(b.lowerBound < a.lowerBound)
    }

    @Test("Import results map to readable outcomes")
    func outcomes() {
        let failed = ImportLogEntry(result: ImportResult(fileName: "x.fit", outcome: .failed(.decoding(.notAFITFile))))
        #expect(failed.outcome.hasPrefix("failed: "))
        #expect(failed.outcome.contains("notAFITFile"))
        let dup = ImportLogEntry(result: ImportResult(fileName: "y.fit", outcome: .duplicate(existingRideID: UUID())))
        #expect(dup.outcome == "duplicate")
    }
}
