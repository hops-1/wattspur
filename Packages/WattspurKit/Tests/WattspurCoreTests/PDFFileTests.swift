import Testing
@testable import WattspurCore

/// The file names of the PDFs, the same on Mac and iPhone (S-22). Invented ride names only.
@Suite("PDF file names")
struct PDFFileTests {
    @Test("A plain title keeps its name and gets the extension")
    func plain() {
        #expect(PDFFile.name("Sonntagstour 2026-11-06") == "Sonntagstour 2026-11-06.pdf")
        #expect(PDFFile.name("Comparison – A, B and C") == "Comparison – A, B and C.pdf")
    }

    @Test("Characters Finder or the Files app do not accept become a dash")
    func unsafe() {
        #expect(PDFFile.name("Tour 50%?") == "Tour 50--.pdf")
        #expect(PDFFile.name("A/B:C\\D*E|F\"G<H>I") == "A-B-C-D-E-F-G-H-I.pdf")
    }
}
