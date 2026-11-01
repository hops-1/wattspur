import Foundation

/// Where the handbook lives online (B-084, DOC-06): the Markdown pages in the repository, in the
/// language of the app. Nothing is bundled, so the pages can improve between releases.
enum HelpLinks {
    enum Page: String {
        case handbook = "README.md"
        case importing = "03-importing.md"
        case views = "04-views.md"
        case faq = "06-faq.md"
    }

    static let releases = URL(string: "https://github.com/hops-1/wattspur/releases")!

    /// "de" for a German app, "en" for everything else (the handbook exists in these two).
    static var language: String {
        Bundle.main.preferredLocalizations.first?.hasPrefix("de") == true ? "de" : "en"
    }

    /// The section "Map styles" of the views page, in the language of the app (B-061).
    static func mapStyles(language: String = HelpLinks.language) -> URL {
        URL(string: url(.views, language: language).absoluteString + (language == "de" ? "#kartenstile" : "#map-styles"))!
    }

    static func url(_ page: Page, language: String = HelpLinks.language) -> URL {
        URL(string: "https://github.com/hops-1/wattspur/blob/main/docs/user-guide/\(language)/\(page.rawValue)")!
    }
}
