import Charts
import SwiftUI
import WattspurCore
import WattspurKit

/// "Highlights" on the iPad (B-295) and the iPhone (B-228), like the Mac's section (v1.3): the
/// year in review, records and goals. On the iPhone the same parts stack in one column and the
/// page is pushed from the tile in the overview. Year and records are of the sport in the sidebar and follow the device filter; the
/// goals count every bike (as on the Mac). The numbers come from the Kit (`HighlightsSummary`,
/// `YearReview`, `GoalProgress`); only the texts and the layout are here.
struct HighlightsView: View {
    /// Opens a ride beside the list of rides (iPad); `nil` pushes it onto this page (iPhone).
    var onOpenRide: ((UUID) -> Void)?

    @Environment(PhoneLibrary.self) private var library
    @ShownSport private var sport
    @AppStorage(PhoneSettingsKey.padHighlightsTab) private var tab: PadHighlightsTab = .year
    @AppStorage(PhoneSettingsKey.padHighlightsDevice) private var deviceFilter: BikeFilter = .all
    /// `nil` = the current year.
    @State private var year: Int?
    @State private var goalEditor: PadGoalEditor.Target?
    /// The ride pushed on the iPhone.
    @State private var openedID: UUID?
    @Environment(\.isPadLayout) private var isPadLayout

    private var calendar: Calendar { GoalPeriod.calendar() }
    private var currentYear: Int { calendar.component(.year, from: .now) }
    private var shownYear: Int { year ?? currentYear }
    private var devices: [RideExchange.Bike] { library.state?.devices(of: sport) ?? [] }

    var body: some View {
        let all = library.statsRides.filter(\.countsInStatistics)
        let filter = deviceFilter.resolved(knownBikeIDs: Set(devices.map(\.id)))
        let rides = all.filter { $0.sport == sport && filter.admits(bikeID: $0.deviceID) }
        let summary = HighlightsSummary(rides: rides.map(\.highlight), calendar: calendar)
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let open: (UUID) -> Void = onOpenRide ?? { openedID = $0 }
        let pdf = HighlightsPDF(tab: tab, review: YearReview(summary.rides, year: shownYear, calendar: calendar),
                                isCurrentYear: shownYear == currentYear, records: summary.records, goals: library.goals,
                                goalRides: all.filter { $0.sport == .cycling }.map(\.highlight),
                                rides: byID, sport: sport, calendar: calendar)
        let sharedPDF = (tab == .goals ? library.goals.isEmpty : rides.isEmpty) ? nil : pdf
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // The iPhone shares from the navigation bar, where the pill would take too much room.
                controls(summary, pdf: isPadLayout ? sharedPDF : nil)
                switch tab {
                case .year:
                    if rides.isEmpty {
                        noRides(anyForSport: all.contains { $0.sport == sport })
                    } else {
                        PadYearReview(review: YearReview(summary.rides, year: shownYear, calendar: calendar),
                                      isCurrentYear: shownYear == currentYear, calendar: calendar,
                                      rides: byID, sport: sport, compact: !isPadLayout, onOpenRide: open)
                    }
                case .records:
                    if rides.isEmpty {
                        noRides(anyForSport: all.contains { $0.sport == sport })
                    } else {
                        PadRecords(records: summary.records, rides: byID, sport: sport, compact: !isPadLayout, onOpenRide: open)
                    }
                case .goals:
                    // The goals are for cycling, whatever sport the sidebar shows (as on the Mac).
                    PadGoals(goals: library.goals,
                             rides: all.filter { $0.sport == .cycling }.map(\.highlight), calendar: calendar,
                             compact: !isPadLayout,
                             onAdd: library.freeGoalCombinations.isEmpty ? nil : { goalEditor = .new },
                             onEdit: { goalEditor = .edit($0) })
                }
            }
            .padding(.horizontal, isPadLayout ? 28 : 16)
            .padding(.vertical, isPadLayout ? 16 : 8)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The iPhone's landscape tab bar floats over the bottom left.
        .tabBarRoomInLandscape()
        .navigationTitle("Highlights")
        .navigationBarTitleDisplayMode(.inline)
        // The iPad's detail has its own title in the page; the iPhone needs the bar to go back.
        .toolbar(isPadLayout ? .hidden : .automatic, for: .navigationBar)
        .toolbar {
            if !isPadLayout, let sharedPDF {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: sharedPDF, preview: SharePreview(Text(verbatim: sharedPDF.title))) {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .navigationDestination(item: $openedID) { id in
            if let ride = library.state?.rides.first(where: { $0.id == id }) {
                TourDetailView(ride: ride)
            }
        }
        .sheet(item: $goalEditor) { target in
            NavigationStack { PadGoalEditor(target: target) }
        }
        .onChange(of: sport) {
            deviceFilter = .all
            year = nil
        }
    }

    private func controls(_ summary: HighlightsSummary, pdf: HighlightsPDF?) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                controlItems(summary)
                Spacer(minLength: 0)
                share(pdf)
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    controlItems(summary)
                }
                share(pdf)
            }
            VStack(alignment: .leading, spacing: 12) {
                controlItems(summary)
                share(pdf)
            }
        }
    }

    /// The shown part as an A4 PDF (B-336): the year, the records or the goals.
    @ViewBuilder private func share(_ pdf: HighlightsPDF?) -> some View {
        if let pdf {
            ShareLink(item: pdf, preview: SharePreview(Text(verbatim: pdf.title))) {
                Label("Share PDF", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.glass)
        }
    }

    @ViewBuilder private func controlItems(_ summary: HighlightsSummary) -> some View {
        Picker("Highlights", selection: $tab) {
            ForEach(PadHighlightsTab.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        if tab == .year {
            let years = summary.years(including: currentYear)
            HStack(spacing: 6) {
                Button { year = years.first { $0 < shownYear } } label: { Image(systemName: "chevron.left") }
                    .disabled(!years.contains { $0 < shownYear })
                    .accessibilityLabel(Text("Previous year"))
                Button {
                    let next = years.last { $0 > shownYear }
                    year = next == currentYear ? nil : next
                } label: { Image(systemName: "chevron.right") }
                    .disabled(!years.contains { $0 > shownYear })
                    .accessibilityLabel(Text("Next year"))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
        if tab == .goals {
            if devices.count >= 2 {
                Label { Text("Goals count all bikes") } icon: { Image(systemName: "lock") }
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else if devices.count >= 2 {
            Picker(selection: $deviceFilter) {
                Text(sport.allDevicesTitle).tag(BikeFilter.all)
                ForEach(devices) { Text(verbatim: $0.name).tag(BikeFilter.bike($0.id)) }
            } label: {
                Text(sport.deviceFilterTitle)
            }
            .pickerStyle(.menu)
            .fixedSize()
        }
    }

    @ViewBuilder private func noRides(anyForSport: Bool) -> some View {
        if anyForSport {
            ContentUnavailableView("No Rides with This Vehicle", systemImage: "trophy",
                                   description: Text("Choose another vehicle or all vehicles."))
                .frame(maxWidth: .infinity, minHeight: 300)
        } else {
            ContentUnavailableView("No Rides Yet", systemImage: "trophy",
                                   description: Text("Import rides to see your year, your records and how your goals are going."))
                .frame(maxWidth: .infinity, minHeight: 300)
        }
    }
}

enum PadHighlightsTab: String, CaseIterable, Identifiable {
    case year, records, goals

    var id: Self { self }

    var label: LocalizedStringKey {
        switch self {
        case .year: "Year"
        case .records: "Records"
        case .goals: "Goals"
        }
    }
}
