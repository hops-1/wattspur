import Foundation
import WattspurKit

/// The words for an import's summary (IMP-06). The Kit only says what happened (R-48); the texts
/// and their translations live in the app.
extension ImportReport {
    /// Imported count and problems, without duplicates. Unsupported files are summarised by type,
    /// unreadable ones listed up to `maxListedNames`.
    var message: String { summaryLines.joined(separator: "\n") }

    /// Message of the duplicate dialog: what happened so far, then the question.
    var duplicateQuestion: String {
        var names = Array(duplicateTitles.prefix(Self.maxListedNames))
        let rest = duplicateTitles.count - Self.maxListedNames
        if rest > 0 { names.append(String(localized: "\(rest) more")) }
        var lines = summaryLines
        lines.append(String(localized: "Already in your library: \(names.formatted(.list(type: .and)))"))
        lines.append(String(localized: "Update them from the new files? Your names are kept."))
        return lines.joined(separator: "\n")
    }

    private var summaryLines: [String] {
        var lines = entries.isEmpty ? [] : [String(localized: "\(importedCount) rides imported")]
        let unsupported = unsupportedFileNames
        if !unsupported.isEmpty {
            let types = unsupportedExtensions.map { $0.isEmpty ? String(localized: "no extension") : ".\($0)" }
                .formatted(.list(type: .and))
            lines.append(String(localized: "\(unsupported.count) files skipped, file type not supported yet: \(types)"))
        }
        let unreadable = unreadableFileNames
        lines += unreadable.prefix(Self.maxListedNames).map { String(localized: "\($0): file could not be read") }
        let rest = unreadable.count - Self.maxListedNames
        if rest > 0 { lines.append(String(localized: "\(rest) more files could not be read")) }
        return lines
    }
}
