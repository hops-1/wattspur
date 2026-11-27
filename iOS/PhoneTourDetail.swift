import Charts
import MapKit
import SwiftUI
import WattspurCore
import WattspurKit
import WattspurMap

/// A planned tour (B-373, detail C of B-371): the map with the elevation profile over its lower
/// edge, below it a grouped list with the figures, “Navigate” (on only with part 2), “Planned vs.
/// Ridden” (empty until part 3) and the actions: share the GPX, rename, move to the trash.
///
/// The line and the profile are loaded once in `.task`, never in the body (rule 16).
struct PlannedTourDetailView: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLandscape) private var isLandscape
    @Environment(\.isPadLayout) private var isPadLayout
    @Environment(\.colorScheme) private var scheme
    /// The tour as it was opened; `tour` follows a new name from here or another device.
    private let opened: PlannedTourSummary
    /// Beside the list (landscape, iPad): the name as a heading instead of the title.
    private let embedded: Bool
    @State private var detail: PhoneDatabase.PlannedTourDetail?
    @State private var renaming = false
    @State private var confirmingDelete = false
    /// Apple's map or an OpenStreetMap style, the same choice as for rides (B-226).
    @AppStorage(PhoneSettingsKey.mapType) private var mapType: RideMapType = .standard

    init(tour: PlannedTourSummary, embedded: Bool = false) {
        opened = tour
        self.embedded = embedded
    }

    private var tour: PlannedTourSummary {
        library.plannedTours.first { $0.id == opened.id } ?? opened
    }

    var body: some View {
        Group {
            if isLandscape && !embedded {
                landscape
            } else {
                list(mapHeight: embedded ? (isPadLayout ? 400 : 220) : 340)
            }
        }
        .modifier(TourDetailTitle(title: embedded ? nil : tour.name))
        .hidesTabBarInLandscape()
        .toolbar {
            if !embedded {
                ShareLink(item: library.sharedGPX(for: tour), preview: SharePreview(tour.name)) {
                    Label("Share GPX", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $renaming) {
            RenameTourSheet(tour: tour)
        }
        .confirmationDialog("Move this tour to the trash?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) {
                library.moveToTrash(tour)
                if !embedded { dismiss() }
            }
        } message: {
            DeviceText.text("You can restore it in More › Trash for 30 days.", pad: "You can restore it in the trash for 30 days.")
        }
        // Once per tour; a tour from another device comes with its id, so the line follows.
        .task(id: tour.id) {
            detail = library.plannedTourDetail(tour.id)
        }
    }

    // MARK: - Layouts

    /// Landscape on the iPhone, pushed from the list: the map on the left, the list on the right.
    private var landscape: some View {
        HStack(spacing: 12) {
            mapWithProfile
                .clipShape(.rect(cornerRadius: 24))
                .containerRelativeFrame(.horizontal) { width, _ in width * 0.5 }
                .padding(.top, 8)
                // The tab bar sits at the bottom left in landscape (B-243); the profile stays above it.
                .padding(.bottom, LandscapeTabBar.height + 8)
            sections(withMap: nil)
        }
        .padding(.leading)
    }

    private func list(mapHeight: CGFloat) -> some View {
        sections(withMap: mapHeight)
    }

    private func sections(withMap mapHeight: CGFloat?) -> some View {
        List {
            if embedded {
                Section {
                    Text(tour.name)
                        .font(.title3.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                        .listRowBackground(Color.clear)
                }
            }
            if let mapHeight {
                Section {
                    mapWithProfile
                        .frame(height: mapHeight)
                        .clipShape(.rect(cornerRadius: 24))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            navigateSection
            figuresSection
            plannedVersusRidden
            actionsSection
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        // Beside the list in landscape the last rows scroll above the tab bar.
        .tabBarRoomInLandscape()
        .contentMargins(.top, 8, for: .scrollContent)
    }

    // MARK: - Map and profile

    private var coordinates: [CLLocationCoordinate2D] {
        (detail?.points ?? tour.preview).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    /// The map with the line in blue and, over its lower edge, the elevation profile.
    private var mapWithProfile: some View {
        let coordinates = coordinates
        return PhoneMapView(mapType: mapType, segments: [coordinates], interactive: true,
                            area: RouteMap.rect(for: coordinates), accent: PlannedTourColor.line(scheme),
                            bottomInset: hasProfile ? PlannedTourProfile.height + 36 : 0)
            .overlay(alignment: .topTrailing) {
                MapTypeMenu(mapType: $mapType)
                    .padding(8)
            }
            .overlay(alignment: .bottom) {
                if let detail, hasProfile {
                    PlannedTourProfile(profile: detail.profile, altitudes: detail.altitudes)
                        .padding(8)
                        // Above the credit of an OpenStreetMap style.
                        .padding(.bottom, mapType.tileSource == nil ? 0 : 22)
                }
            }
    }

    private var hasProfile: Bool { (detail?.profile.count ?? 0) > 1 }

    // MARK: - Sections

    /// Visible but off in 1.7 (B-373): navigation comes with part 2.
    private var navigateSection: some View {
        Section {
            Button {
            } label: {
                Label("Navigate", systemImage: "location.north.line.fill")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(PlannedTourColor.line(scheme))
            .disabled(true)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } footer: {
            DeviceText.text("Navigation comes with a later version of Wattspur.",
                            pad: "You navigate on the iPhone, with a later version of Wattspur.")
        }
    }

    private var figuresSection: some View {
        Section("Tour") {
            LabeledContent("Distance", value: RideFormat.distance(tour.distance))
            if let ascent = tour.ascent {
                LabeledContent("Ascent", value: RideFormat.ascent(ascent))
            }
            if let descent = tour.descent {
                LabeledContent("Descent", value: RideFormat.ascent(descent))
            }
            if let altitudes = detail?.altitudes {
                LabeledContent("Altitude", value: "\(RideFormat.altitude(altitudes.lowerBound)) – \(RideFormat.altitude(altitudes.upperBound))")
            }
            LabeledContent("Type", value: PlannedTourFormat.shape(tour))
            LabeledContent("Source", value: PlannedTourFormat.source(tour.source))
            LabeledContent("Imported", value: tour.createdAt.formatted(date: .long, time: .omitted))
        }
        .monospacedDigit()
    }

    /// Empty until part 3, which lays a ride over the plan.
    private var plannedVersusRidden: some View {
        Section("Planned vs. Ridden") {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("No ride of this tour yet")
                    Text("Later Wattspur shows here how a ride went against the plan.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            ShareLink(item: library.sharedGPX(for: tour), preview: SharePreview(tour.name)) {
                Label("Share GPX", systemImage: "square.and.arrow.up")
            }
            Button("Rename …", systemImage: "pencil") { renaming = true }
            Button("Move to Trash", systemImage: "trash", role: .destructive) { confirmingDelete = true }
        }
    }
}

/// The tour's name as the inline title, except beside the list.
private struct TourDetailTitle: ViewModifier {
    var title: String?

    func body(content: Content) -> some View {
        if let title {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            content
        }
    }
}

/// The heights over the distance, small and on glass over the map.
struct PlannedTourProfile: View {
    var profile: [PlannedTour.ProfilePoint]
    var altitudes: ClosedRange<Double>?
    @Environment(\.colorScheme) private var scheme

    static let height: CGFloat = 96

    var body: some View {
        let color = PlannedTourColor.line(scheme)
        let low = altitudes?.lowerBound ?? profile.map(\.altitude).min() ?? 0
        let high = altitudes?.upperBound ?? profile.map(\.altitude).max() ?? 0
        // Some room above and below, at least 10 m, so a flat tour does not look like a mountain.
        let padding = max(10, (high - low) * 0.1)
        Chart(profile.indices, id: \.self) { index in
            let point = profile[index]
            AreaMark(x: .value("Distance", point.distance / 1000),
                     yStart: .value("Altitude", low - padding),
                     yEnd: .value("Altitude", point.altitude))
                .foregroundStyle(color.opacity(0.2))
            LineMark(x: .value("Distance", point.distance / 1000), y: .value("Altitude", point.altitude))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartYScale(domain: (low - padding)...(high + padding))
        .chartXScale(domain: 0...max((profile.last?.distance ?? 0) / 1000, 0.1))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let km = value.as(Double.self) { Text(verbatim: "\(km.formatted(.number.precision(.fractionLength(0)))) km") }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let metres = value.as(Double.self) { Text(verbatim: RideFormat.altitude(metres)) }
                }
            }
        }
        .frame(height: Self.height)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .accessibilityElement()
        .accessibilityLabel(Text("Elevation profile from \(RideFormat.altitude(low)) to \(RideFormat.altitude(high))"))
    }
}
