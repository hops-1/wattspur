import Foundation
import Observation
import WattspurKit

/// Keeps a copy of files that failed to import in this session, so they can be
/// attached to a diagnostic report (SUP-01). The import log itself is stored as
/// `ImportRecord`s (IMP-06).
@MainActor
@Observable
final class ImportLog {
    /// File name → contents of files that could not be imported (at most 10).
    private(set) var failedFiles: [String: Data] = [:]

    func record(_ result: ImportResult, url: URL) {
        guard case .failed = result.outcome, failedFiles.count < 10 else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        failedFiles[result.fileName] = try? Data(contentsOf: url)
    }
}
