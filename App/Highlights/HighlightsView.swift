import Charts
import SwiftData
import SwiftUI
import WattspurKit

enum HighlightsTab: String, CaseIterable, Identifiable {
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

/// The "Highlights" section (v1.3): year in review, records and goals
/// (ADV-J1, ADV-R1, ADV-Z1). Each tab can be exported as PDF at the top left.
struct HighlightsView: View {
    @Binding var tab: HighlightsTab
    /// `nil` = the current year.
    @Binding var year: Int?
    /// Selects these rides in the list.
    var onOpenRides: ([UUID]) -> Void = { _ in }

    /// Rides outside the trash and merged rides instead of their parts; the sample
    /// ride is left out in `rides`.
    @Query(filter: Ride.listedPredicate, sort: \Ride.startDate)
    private var listedRides: [Ride]
    @Query private var goals: [Goal]
    /// The bike filter of the highlights: year and records follow it, goals never (B-137).
    @AppStorage("bikeFilter.highlights") private var bikeFilterChoice: BikeFilter = .all
    /// The source filter of the highlights, the same way (B-145).
    @AppStorage("sourceFilter.highlights") private var sourceFilterChoice: SourceFilter = .all
    @Query private var bikes: [Bike]
    @State private var exporting = false
    @State private var goalEditor: GoalEditor.Target?

    /// Only rides that count (Requirements 10.10), of every bike.
    private var allRides: [Ride] { listedRides.filter(\.countsInStatistics) }
    private var bikeFilter: BikeFilter { bikeFilterChoice.resolved(knownBikeIDs: Set(bikes.map(\.id))) }
    private var hasGPXRides: Bool { allRides.contains { $0.source == .gpx } }
    private var sourceFilter: SourceFilter { sourceFilterChoice.resolved(hasGPXRides: hasGPXRides) }
    /// The rides of the chosen bike and source: for the year and the records.
    private var rides: [Ride] {
        bikeFilter.isActive || sourceFilter.isActive
            ? allRides.filter { $0.isOnBike(bikeFilter) && $0.isFromSource(sourceFilter) } : allRides
    }
    /// The rides of every bike as plain values, for the goals.
    private var allRideData: HighlightsData { HighlightsData(rides: allRides, calendar: calendar) }
    private var calendar: Calendar { GoalPeriod.calendar() }
    private var currentYear: Int { calendar.component(.year, from: .now) }
    private var shownYear: Int { year ?? currentYear }

    var body: some View {
        let data = HighlightsData(rides: rides, calendar: calendar)
        VStack(spacing: 0) {
            controls(data)
                .padding(.horizontal, 28)
                .frame(height: 52)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PDFExportButton(isExporting: exporting, isDisabled: rides.isEmpty && tab != .goals) { target in
                        exportPDF(data, to: target)
                    }
                    content(data)
                }
                .padding(.horizontal, 28)
                .padding(.top, 4)
                .padding(.bottom, 40)
                .frame(maxWidth: 1100, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .sheet(item: $goalEditor) { target in
            GoalEditor(target: target, goals: goals)
        }
    }

    private func controls(_ data: HighlightsData) -> some View {
        HStack(spacing: 12) {
            Picker("Highlights", selection: $tab) {
                ForEach(HighlightsTab.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            if tab == .year {
                let years = data.years(including: currentYear)
                HStack(spacing: 4) {
                    Button { year = years.first { $0 < shownYear } } label: { Image(systemName: "chevron.left") }
                        .disabled(!years.contains { $0 < shownYear })
                        .help(Text("Previous year"))
                        .accessibilityLabel(Text("Previous year"))
                        .keyboardShortcut(.leftArrow, modifiers: .command)
                    Button {
                        let next = years.last { $0 > shownYear }
                        year = next == currentYear ? nil : next
                    } label: { Image(systemName: "chevron.right") }
                        .disabled(!years.contains { $0 > shownYear })
                        .help(Text("Next year"))
                        .accessibilityLabel(Text("Next year"))
                        .keyboardShortcut(.rightArrow, modifiers: .command)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
            if tab == .goals {
                // Goals count every bike and every source, so the filters have no say here.
                if bikes.count >= 2 || hasGPXRides {
                    Label { Text(goalsNote) } icon: { Image(systemName: "lock") }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                BikeFilterMenu(filter: $bikeFilterChoice)
                SourceFilterMenu(filter: $sourceFilterChoice, hasGPXRides: hasGPXRides)
            }
            Spacer()
        }
    }

    /// What the lock beside the goals says: which filters do not apply to them.
    private var goalsNote: LocalizedStringKey {
        if bikes.count < 2 { "Goals count all sources" } else if hasGPXRides { "Goals count all bikes and sources" } else { "Goals count all bikes" }
    }

    @ViewBuilder
    private func content(_ data: HighlightsData) -> some View {
        switch tab {
        case .year:
            if rides.isEmpty {
                noRides
            } else {
                YearReviewContent(review: YearReview(data.highlightRides, year: shownYear, calendar: calendar),
                                  isCurrentYear: shownYear == currentYear, calendar: calendar,
                                  rideNames: data.names, onOpenRides: onOpenRides)
            }
        case .records:
            if rides.isEmpty {
                noRides
            } else {
                RecordsContent(records: data.records, rides: data.byID, onOpenRides: onOpenRides)
            }
        case .goals:
            GoalsContent(goals: Goal.sorted(goals), rides: allRideData.highlightRides, calendar: calendar,
                         onAdd: Goal.freeCombinations(besides: goals).isEmpty ? nil : { goalEditor = .new },
                         onEdit: { goalEditor = .edit($0) })
        }
    }

    @ViewBuilder
    private var noRides: some View {
        if bikeFilter.isActive && sourceFilter.isActive && !allRides.isEmpty {
            ContentUnavailableView("No Matching Rides", systemImage: "trophy",
                                   description: Text("Change or reset the filters."))
                .frame(maxWidth: .infinity, minHeight: 300)
        } else if sourceFilter.isActive && !allRides.isEmpty {
            ContentUnavailableView("No Rides From This Source", systemImage: "trophy",
                                   description: Text("Choose another source or all sources."))
                .frame(maxWidth: .infinity, minHeight: 300)
        } else if bikeFilter.isActive && !allRides.isEmpty {
            ContentUnavailableView("No Rides on This Bike", systemImage: "trophy",
                                   description: Text("Choose another bike or all bikes."))
                .frame(maxWidth: .infinity, minHeight: 300)
        } else {
            ContentUnavailableView("No Rides Yet", systemImage: "trophy",
                                   description: Text("Import rides to see your year, your records and how your goals are going."))
                .frame(maxWidth: .infinity, minHeight: 300)
        }
    }

    private func exportPDF(_ data: HighlightsData, to target: PDFExport.Target) {
        exporting = true
        defer { exporting = false }
        let page: AnyView
        let title: String
        switch tab {
        case .year:
            let review = YearReview(data.highlightRides, year: shownYear, calendar: calendar)
            title = String(localized: "Wattspur \(String(shownYear))")
            page = AnyView(VStack(alignment: .leading, spacing: 22) {
                YearReviewContent(review: review, isCurrentYear: shownYear == currentYear, calendar: calendar,
                                  rideNames: data.names, isPrinting: true)
                PDFExport.createdNote
            })
        case .records:
            title = String(localized: "Wattspur Records")
            page = AnyView(VStack(alignment: .leading, spacing: 22) {
                RecordsContent(records: data.records, rides: data.byID, isPrinting: true)
                PDFExport.createdNote
            })
        case .goals:
            title = String(localized: "Wattspur Goals")
            page = AnyView(VStack(alignment: .leading, spacing: 22) {
                GoalsContent(goals: Goal.sorted(goals), rides: allRideData.highlightRides, calendar: calendar, isPrinting: true)
                PDFExport.createdNote
            })
        }
        PDFExport.deliver(PDFExport.document([page]), fileName: PDFExport.fileName(title), to: target)
    }
}
