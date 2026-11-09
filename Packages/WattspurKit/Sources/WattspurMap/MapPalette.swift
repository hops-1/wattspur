import CoreGraphics
import WattspurCore

/// The colours the maps draw with, as sRGB hex values for the light and the dark appearance, so
/// both apps take the same ones (B-186). The apps build their legend colours from the same values;
/// the system's own colours (accent, grey) come from the app (`RouteColors`).
public enum MapPalette {
    /// A colour in the light and the dark appearance, as 0xRRGGBB.
    public struct Pair: Sendable, Equatable {
        public var light: UInt32
        public var dark: UInt32

        public init(light: UInt32, dark: UInt32) {
            self.light = light
            self.dark = dark
        }

        public func hex(dark: Bool) -> UInt32 { dark ? self.dark : light }

        public func cgColor(dark: Bool) -> CGColor { MapPalette.cgColor(hex(dark: dark)) }
    }

    /// An opaque sRGB colour from 0xRRGGBB.
    public static func cgColor(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    /// The curve kinds on the ride's map (B-181): red tight, amber gentle, grey straight.
    public static func curve(_ kind: CurvatureAnalyzer.Kind) -> Pair {
        switch kind {
        case .tight: Pair(light: 0xC81D25, dark: 0xFF5A5F)
        case .gentle: Pair(light: 0xE0A100, dark: 0xFFD43B)
        case .straight: Pair(light: 0x7A7F87, dark: 0xA8ADB5)
        }
    }

    /// The route by lean angle (B-247): from green upright through yellow and orange to red and purple.
    public static func lean(_ band: RideMotion.LeanBand) -> Pair {
        switch band {
        case .upright: Pair(light: 0x2E9E44, dark: 0x5BD075)
        case .slight: Pair(light: 0xE0A100, dark: 0xFFD43B)
        case .medium: Pair(light: 0xE8590C, dark: 0xFF922B)
        case .strong: Pair(light: 0xC81D25, dark: 0xFF5A5F)
        case .extreme: Pair(light: 0x8E3FC9, dark: 0xC08BFF)
        }
    }

    /// The route by road surface (B-248): grey smooth, yellow-orange uneven, red rough (B-276).
    public static func surface(_ band: RideMotion.SurfaceBand) -> Pair {
        switch band {
        case .smooth: Pair(light: 0x9AA0A8, dark: 0xB8BDC4)
        case .uneven: Pair(light: 0xF59F00, dark: 0xFFB238)
        case .rough: Pair(light: 0xE03131, dark: 0xFF5C5C)
        }
    }

    /// A step of the route by height (B-063): blue low to red high, the same in both appearances.
    public static func elevation(_ level: Int) -> UInt32 {
        RouteElevation.palette[min(max(level, 0), RouteElevation.palette.count - 1)]
    }

    /// Stretches no earlier ride had passed (B-115).
    public static let newPaths = Pair(light: 0xC2410C, dark: 0xFF8A4C)

    /// Orange for curvy roads (from 300), red for very curvy ones (from 1000) (B-183).
    public static func curvyRoad(veryCurvy: Bool) -> Pair {
        veryCurvy ? Pair(light: 0xD7263D, dark: 0xFF6B7A) : Pair(light: 0xE08600, dark: 0xFFB020)
    }
}

/// The system colours a route is drawn with, resolved by the app for the light or dark appearance.
public struct RouteColors: Sendable {
    /// The route in one colour: the app's accent colour.
    public var accent: CGColor
    /// Stretches of the route by height without a height.
    public var noHeight: CGColor

    public init(accent: CGColor, noHeight: CGColor) {
        self.accent = accent
        self.noHeight = noHeight
    }
}
