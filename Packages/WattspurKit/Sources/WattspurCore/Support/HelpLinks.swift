import Foundation

/// Where the handbook lives online (B-084, DOC-06): the Markdown pages in the repository, in the
/// language of the app. Nothing is bundled, so the pages can improve between releases. Both apps
/// use it: the Mac in its Help menu, the iPhone in “More › Help & Handbook” (B-298).
public enum HelpLinks {
    public enum Page: String, Sendable {
        case handbook = "README.md"
        case importing = "03-importing.md"
        case views = "04-views.md"
        case faq = "06-faq.md"
        case iPhone = "09-iphone-and-icloud.md"
    }

    public static let releases = URL(string: "https://github.com/hops-1/wattspur/releases")!
    /// The privacy policy, German and English on one page.
    public static let privacy = URL(string: "https://github.com/hops-1/wattspur/blob/main/docs/PRIVACY.md")!

    /// "de" for a German app, "en" for everything else (the handbook exists in these two).
    public static var language: String {
        Bundle.main.preferredLocalizations.first?.hasPrefix("de") == true ? "de" : "en"
    }

    /// The section "Map styles" of the views page, in the language of the app (B-061).
    public static func mapStyles(language: String = HelpLinks.language) -> URL {
        URL(string: url(.views, language: language).absoluteString + (language == "de" ? "#kartenstile" : "#map-styles"))!
    }

    public static func url(_ page: Page, language: String = HelpLinks.language) -> URL {
        URL(string: "https://github.com/hops-1/wattspur/blob/main/docs/user-guide/\(language)/\(page.rawValue)")!
    }
}
