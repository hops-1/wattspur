import Foundation

/// Texts of the PDFs that are the same on the Mac and the iPhone/iPad (S-22).
enum PDFText {
    /// "Created with Wattspur on 22 October 2026 at 10:15. Calories and CO₂ are estimates."
    /// at the end of every PDF.
    static var createdNote: String {
        String(localized: "Created with Wattspur on \(Date.now.formatted(date: .long, time: .shortened)). Calories and CO₂ are estimates.")
    }
}
