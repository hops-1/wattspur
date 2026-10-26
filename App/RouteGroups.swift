import SwiftData
import SwiftUI
import WattspurKit

// Saved routes (B-121, ROUTE-07): the suggestion above the list and the dialog that saves one.

/// The suggestions the user sent away with "Not Now", kept on this Mac. A suggestion stays away while
/// its reference ride is one of the rides it had then, so it comes back only for new rides.
enum DismissedRouteSuggestions {
    /// More than this are forgotten, oldest first.
    private static let limit = 3_000

    static func ids(_ raw: String) -> Set<UUID> {
        Set(raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }

    static func adding(_ suggestion: RouteGrouping.Suggestion, to raw: String) -> String {
        let known = raw.split(separator: ",").map(String.init)
        let added = suggestion.members.map(\.uuidString).filter { !known.contains($0) }
        return (known + added).suffix(limit).joined(separator: ",")
    }
}

/// Above the ride list: "Probably the same route: 12 rides".
struct RouteSuggestionBanner: View {
    let rideCount: Int
    let rideName: String
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Probably the same route: \(rideCount) rides")
                        .font(.callout)
                    Text(verbatim: "“\(rideName)”")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(Color.accentColor)
            }
            HStack {
                Spacer()
                Button("Not Now", action: onDismiss)
                Button("Save as Route…", action: onSave)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
    }
}

/// What the "Save Route" dialog starts with.
struct SaveRouteRequest: Identifiable {
    let id = UUID()
    var rideID: UUID
    var name: String
    var threshold: Double
    var includeReverse: Bool
}

/// "Save Route": the name, how loosely rides must match, and how many rides that makes.
struct SaveRouteSheet: View {
    let request: SaveRouteRequest
    /// How many rides lie on the route at a similarity and direction.
    let count: (Double, Bool) async -> Int
    let onSave: (String, Double, Bool) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var threshold: Double
    @State private var includeReverse: Bool
    @State private var matches: Int?

    init(request: SaveRouteRequest, count: @escaping (Double, Bool) async -> Int,
         onSave: @escaping (String, Double, Bool) -> Void, onCancel: @escaping () -> Void) {
        self.request = request
        self.count = count
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: request.name)
        _threshold = State(initialValue: request.threshold)
        _includeReverse = State(initialValue: request.includeReverse)
    }

    private var percent: Binding<Double> {
        Binding(get: { threshold }, set: { threshold = RouteSimilarity.clampedThreshold(($0 * 100).rounded() / 100) })
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Save Route").font(.title2.bold())
            Text("A saved route has a name. Rides on it, now and in the future, belong to it.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { if canSave { save() } }

            HStack(spacing: 8) {
                Text("Similarity")
                Slider(value: percent, in: RouteSimilarity.thresholdRange, step: 0.01)
                    .accessibilityLabel(Text("Similarity"))
                    .accessibilityValue(Text(verbatim: threshold.formatted(.percent.precision(.fractionLength(0)))))
                Text(verbatim: threshold.formatted(.percent.precision(.fractionLength(0))))
                    .monospacedDigit()
                    .frame(minWidth: 38, alignment: .trailing)
                    .accessibilityHidden(true)
            }
            Toggle(isOn: $includeReverse) {
                Label("Both directions", systemImage: "arrow.left.arrow.right")
            }
            .toggleStyle(.checkbox)

            Group {
                if let matches {
                    matches == 1 ? Text("1 ride is on this route") : Text("\(matches) rides are on this route")
                } else {
                    Text(verbatim: " ")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .accessibilityLabel(matches.map { Text("\($0) rides are on this route") } ?? Text(verbatim: ""))

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 400)
        .task(id: "\(threshold)/\(includeReverse)") {
            matches = await count(threshold, includeReverse)
        }
    }

    private func save() {
        onSave(name, threshold, includeReverse)
    }
}

/// Bottom of the window after an import: "New ride on your route “Name”" with a button to show it.
struct RouteJoinNoticeHost: View {
    @Environment(RouteSimilarityStore.self) private var similarity
    @Query private var routeGroups: [RouteGroup]
    let onShow: (RouteGroup) -> Void

    var body: some View {
        Group {
            if let join = similarity.joined, let group = routeGroups.first(where: { $0.id == join.routeID }) {
                HStack(spacing: 12) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    text(join.rideIDs.count, route: group.name)
                        .font(.callout)
                    Button("Show Route") {
                        onShow(group)
                        similarity.dismissJoin()
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    Button { similarity.dismissJoin() } label: { Image(systemName: "xmark").font(.caption.weight(.bold)) }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text("Close"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.separator.opacity(0.6)))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
                .padding(.bottom, 18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityElement(children: .combine)
                .task(id: join.id) {
                    AccessibilityNotification.Announcement(String(localized: "A new ride is on your route “\(group.name)”.")).post()
                    try? await Task.sleep(for: .seconds(15))
                    if similarity.joined?.id == join.id { similarity.dismissJoin() }
                }
            }
        }
        .animation(.snappy, value: similarity.joined)
    }

    private func text(_ count: Int, route: String) -> Text {
        count == 1 ? Text("A new ride is on your route “\(route)”.") : Text("\(count) new rides are on your route “\(route)”.")
    }
}
