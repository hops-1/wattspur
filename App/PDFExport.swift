import AppKit
import MapKit
import SwiftUI
import UniformTypeIdentifiers
import WattspurKit

/// Shared PDF export (CMP-07, P-20): SwiftUI views on A4 portrait in the light
/// appearance, a map snapshot with routes drawn on top, and handing the file to
/// Preview or a save panel.
@MainActor
enum PDFExport {
    enum Target { case preview, save }

    /// A route to draw on the map snapshot.
    struct MapLine {
        var coordinates: [CLLocationCoordinate2D]
        var color: NSColor
        var dash: [CGFloat] = []
        /// Green start and red finish dot, as in the ride detail.
        var showsEndpoints = false
        /// Where the parts of a merged ride meet (B-131).
        var joinTicks: [JoinTick] = []
    }

    /// A4 in points, with a margin of 15 mm.
    static let pageSize = CGSize(width: 595.28, height: 841.89)
    static let margin = 42.5
    /// The views are laid out this wide and then scaled down to the page.
    static let contentWidth = 900.0

    /// Each block starts on a new page and runs over as many pages as it needs.
    static func document(_ blocks: [AnyView]) -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return Data() }
        var box = CGRect(origin: .zero, size: pageSize)
        guard let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        for block in blocks { draw(block, into: pdf) }
        pdf.closePDF()
        return data as Data
    }

    /// Lays the view out at `contentWidth`, scales it to the page width and
    /// spreads it over pages.
    private static func draw(_ content: AnyView, into pdf: CGContext) {
        let renderer = ImageRenderer(content: content
            .frame(width: contentWidth, alignment: .leading)
            .padding(1)
            .background(.white)
            .environment(\.colorScheme, .light))
        renderer.proposedSize = ProposedViewSize(width: contentWidth + 2, height: nil)
        renderer.render { size, render in
            let usable = CGSize(width: pageSize.width - 2 * margin, height: pageSize.height - 2 * margin)
            let scale = usable.width / size.width
            let pageCount = max(1, Int((size.height * scale / usable.height).rounded(.up)))
            for page in 0..<pageCount {
                pdf.beginPDFPage(nil)
                pdf.saveGState()
                pdf.clip(to: CGRect(x: margin, y: margin, width: usable.width, height: usable.height))
                // PDF origin is bottom left: put this page's slice at the top of the usable area.
                pdf.translateBy(x: margin, y: pageSize.height - margin)
                pdf.scaleBy(x: scale, y: scale)
                pdf.translateBy(x: 0, y: -size.height + CGFloat(page) * usable.height / scale)
                render(pdf)
                pdf.restoreGState()
                pdf.endPDFPage()
            }
        }
    }

    /// A live MapKit map cannot be drawn into a PDF, so this takes a snapshot around
    /// all lines and draws them on top.
    static func mapImage(_ lines: [MapLine], mapType: RideMapType, size: CGSize) async -> NSImage? {
        let lines = lines.filter { $0.coordinates.count > 1 }
        let all = lines.flatMap(\.coordinates)
        guard let minLat = all.map(\.latitude).min(), let maxLat = all.map(\.latitude).max(),
              let minLon = all.map(\.longitude).min(), let maxLon = all.map(\.longitude).max() else { return nil }
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max(0.005, (maxLat - minLat) * 1.25),
                                   longitudeDelta: max(0.005, (maxLon - minLon) * 1.25)))
        options.size = size
        options.appearance = NSAppearance(named: .aqua)
        switch mapType {
        case .standard:
            let configuration = MKStandardMapConfiguration(emphasisStyle: .muted)
            configuration.pointOfInterestFilter = .excludingAll
            options.preferredConfiguration = configuration
        case .satellite: options.preferredConfiguration = MKImageryMapConfiguration()
        case .hybrid:
            let configuration = MKHybridMapConfiguration()
            configuration.pointOfInterestFilter = .excludingAll
            options.preferredConfiguration = configuration
        }
        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }
        let image = NSImage(size: size)
        image.lockFocusFlipped(true)
        snapshot.image.draw(in: CGRect(origin: .zero, size: size))
        // Adaptive colours resolve to their light variants, like the rest of the PDF.
        NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance {
            for line in lines {
                let path = NSBezierPath()
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                for (i, coordinate) in line.coordinates.enumerated() {
                    let point = snapshot.topDownPoint(for: coordinate, height: size.height)
                    if i == 0 { path.move(to: point) } else { path.line(to: point) }
                }
                path.lineWidth = 7
                NSColor.white.setStroke()
                path.stroke()
                if !line.dash.isEmpty { path.setLineDash(line.dash, count: line.dash.count, phase: 0) }
                path.lineWidth = 4
                line.color.setStroke()
                path.stroke()
                if line.showsEndpoints, let start = line.coordinates.first, let finish = line.coordinates.last {
                    dot(at: snapshot.topDownPoint(for: finish, height: size.height), color: .systemRed)
                    dot(at: snapshot.topDownPoint(for: start, height: size.height), color: .systemGreen)
                }
                for tick in line.joinTicks {
                    let centre = snapshot.topDownPoint(for: tick.coordinate, height: size.height)
                    let across = tick.across
                    let tickPath = NSBezierPath()
                    tickPath.move(to: CGPoint(x: centre.x - across.dx * 12, y: centre.y - across.dy * 12))
                    tickPath.line(to: CGPoint(x: centre.x + across.dx * 12, y: centre.y + across.dy * 12))
                    tickPath.lineCapStyle = .butt
                    tickPath.lineWidth = 4.5
                    NSColor.white.setStroke()
                    tickPath.stroke()
                    tickPath.lineWidth = 2.5
                    NSColor.black.setStroke()
                    tickPath.stroke()
                }
            }
        }
        image.unlockFocus()
        return image
    }

    private static func dot(at point: CGPoint, color: NSColor) {
        let circle = NSBezierPath(ovalIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14))
        color.setFill()
        circle.fill()
        circle.lineWidth = 3
        NSColor.white.setStroke()
        circle.stroke()
    }

    /// Opens the PDF in Preview, or asks where to save it.
    static func deliver(_ data: Data, fileName: String, to target: Target) {
        switch target {
        case .preview:
            // A folder of its own, so a PDF that is still open is never overwritten.
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let url = folder.appendingPathComponent(fileName)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try data.write(to: url)
            } catch {
                NSAlert(error: error).runModal()
                return
            }
            if let preview = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") {
                NSWorkspace.shared.open([url], withApplicationAt: preview, configuration: NSWorkspace.OpenConfiguration(),
                                        completionHandler: nil)
            } else {
                NSWorkspace.shared.open(url)
            }
        case .save:
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = fileName
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    /// A file name without characters that Finder does not accept.
    static func fileName(_ title: String) -> String {
        title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") + ".pdf"
    }

    /// "Created with Wattspur on 22 October 2026 at 10:15. …" at the end of every PDF.
    static var createdNote: some View {
        Text("Created with Wattspur on \(Date.now.formatted(date: .long, time: .shortened)). Calories and CO₂ are estimates.")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}

/// "Export PDF" at the top left of a view: a click opens the PDF in Preview, the
/// menu next to it also offers saving it. ⇧⌘E.
struct PDFExportButton: View {
    let isExporting: Bool
    var isDisabled = false
    let action: (PDFExport.Target) -> Void

    var body: some View {
        Menu {
            Button("Open in Preview") { action(.preview) }
            Button("Save as PDF…") { action(.save) }
        } label: {
            Label(isExporting ? "Exporting…" : "Export PDF", systemImage: "doc.richtext")
        } primaryAction: {
            action(.preview)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .fixedSize()
        .disabled(isExporting || isDisabled)
        .keyboardShortcut("e", modifiers: [.command, .shift])
    }
}

extension MKMapSnapshotter.Snapshot {
    /// `point(for:)` counts y from the top on some systems and from the bottom on
    /// others (macOS 26: from the bottom), which drew every route on the PDF maps
    /// mirrored (B-126). This asks where a spot a little further north lies and
    /// returns points counted from the top, as the flipped drawing in the PDFs expects.
    func topDownPoint(for coordinate: CLLocationCoordinate2D, height: CGFloat) -> CGPoint {
        let point = self.point(for: coordinate)
        let north = CLLocationCoordinate2D(latitude: min(coordinate.latitude + 0.001, 89), longitude: coordinate.longitude)
        let countsFromBottom = self.point(for: north).y > point.y
        return countsFromBottom ? CGPoint(x: point.x, y: height - point.y) : point
    }
}
