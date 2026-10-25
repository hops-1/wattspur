import SwiftUI
import WattspurKit

/// The ride's route as a small line in the ride list (B-064, LIST-02): drawn
/// from the stored overview route, without map tiles, so the list stays fast.
struct RoutePreviewView: View {
    let ride: Ride
    var size: CGFloat = 44
    /// White line on the accent colour of a selected row.
    @Environment(\.backgroundProminence) private var prominence

    private var preview: RoutePreview? { ride.overviewRoute.flatMap { RoutePreview(route: $0) } }
    private var onAccent: Bool { prominence == .increased }

    var body: some View {
        let preview = preview
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(onAccent ? AnyShapeStyle(.white.opacity(0.18)) : AnyShapeStyle(.quaternary.opacity(0.6)))
            if let preview {
                lines(preview)
            } else if !ride.needsOverviewRoute {
                // Computed, but the ride has no GPS (e.g. an indoor trainer).
                Image(systemName: "location.slash")
                    .font(.system(size: size * 0.36))
                    .foregroundStyle(onAccent ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(label(preview))
    }

    private func lines(_ preview: RoutePreview) -> some View {
        Canvas { context, canvas in
            let inset = canvas.width * 0.16
            let side = canvas.width - 2 * inset
            func point(_ p: RoutePreview.Point) -> CGPoint {
                CGPoint(x: inset + p.x * side, y: inset + p.y * side)
            }
            let color: Color = onAccent ? .white : .accentColor
            for segment in preview.segments {
                var path = Path()
                for (i, p) in segment.enumerated() {
                    if i == 0 { path.move(to: point(p)) } else { path.addLine(to: point(p)) }
                }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
            if let start = preview.start {
                let dot = CGRect(x: point(start).x - 2.6, y: point(start).y - 2.6, width: 5.2, height: 5.2)
                context.fill(Path(ellipseIn: dot.insetBy(dx: -1.2, dy: -1.2)), with: .color(onAccent ? .accentColor : Color(nsColor: .windowBackgroundColor)))
                context.fill(Path(ellipseIn: dot), with: .color(.green))
            }
        }
    }

    private func label(_ preview: RoutePreview?) -> Text {
        guard let preview else { return ride.needsOverviewRoute ? Text(verbatim: "") : Text("No GPS data") }
        if preview.segments.count > 1 { return Text("Route in \(preview.segments.count) parts") }
        return preview.isLoop ? Text("Loop") : Text("Route from start to finish")
    }
}
