import Foundation

/// The file names of the PDFs, one rule for Mac and iPhone (S-22).
public enum PDFFile {
    /// Characters that Finder or the Files app do not accept in a file name.
    static let unsafe = CharacterSet(charactersIn: "/:\\?%*|\"<>")

    /// "Highlights 2026.pdf": the title with a dash for each character a file name cannot have.
    public static func name(_ title: String) -> String {
        title.components(separatedBy: unsafe).joined(separator: "-") + ".pdf"
    }
}
