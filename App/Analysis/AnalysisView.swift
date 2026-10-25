import Charts
import SwiftData
import SwiftUI
import WattspurKit

/// The "Analysis" section (v0.2): period at the top, then sums, time-weighted averages,
/// a bar chart and trend charts (AGG-01 … AGG-04, TREND-01, TREND-02).
///
/// With `selection` it analyses exactly these rides instead of a period (LIST-06).
struct AnalysisView: View {
    var selection: Set<UUID>?
    var onClearSelection: () -> Void = {}
    /// "Show on Map": the map shows exactly the analysed rides (wish from Nils, v1.4).
    var onShowOnMap: (Set<UUID>) -> Void = { _ in }
    /// The analysed rides, for the list beside the analysis (B-124).
    var onAnalysedRidesChange: (Set<UUID>) -> Void = { _ in }

    @Query(filter: Ride.listedPredicate, sort: \Ride.startDate)
    private var allRides: [Ride]

    /// Rides picked by hand are analysed whatever their bike; otherwise the filter applies.
    private var rides: [Ride] {
        guard selection == nil else { return allRides }
        let filter = bikeFilterChoice.resolved(knownBikeIDs: Set(bikes.map(\.id)))
        let source = sourceFilterChoice.resolved(hasGPXRides: hasGPXRides)
        return filter.isActive || source.isActive ? allRides.filter { $0.isOnBike(filter) && $0.isFromSource(source) } : allRides
    }

    private var hasGPXRides: Bool { allRides.contains { $0.source == .gpx } }

    @AppStorage("analysisPeriod") private var kind: AnalysisPeriodKind = .year
    @AppStorage("analysisBarMetric") private var barMetric: BarMetric = .distance
    /// The bike filter of the analysis, remembered (B-137).
    @AppStorage("bikeFilter.analysis") private var bikeFilterChoice: BikeFilter = .all
    /// The source filter of the analysis, the same way (B-145).
    @AppStorage("sourceFilter.analysis") private var sourceFilterChoice: SourceFilter = .all
    @Query private var bikes: [Bike]
    /// "From pedal power" or "with profile" (SET-06, B-067).
    @AppStorage("calorieMode") private var calorieMode: CalorieMode = .fromWork
    @Query private var riders: [Rider]
    @State private var offset = 0
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var customEnd = Date.now
    /// `nil` = the grouping that fits the period.
    @State private var groupingChoice: AnalysisGrouping?

    private var calendar: Calendar { .current }

    private var period: AnalysisPeriod {
        let start = calendar.startOfDay(for: min(customStart, customEnd))
        let endDay = calendar.startOfDay(for: max(customStart, customEnd))
        let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        return AnalysisPeriod(kind: kind, offset: offset, customInterval: DateInterval(start: start, end: end))
    }

    var body: some View {
        let model = AnalysisModel(rides: rides, selection: selection, period: period,
                                  groupingChoice: groupingChoice, calendar: calendar,
                                  calories: CalorieModel(mode: calorieMode, rider: riders.first))
        VStack(spacing: 0) {
            controls
                .padding(.horizontal, 28)
                .frame(height: 52)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .lastTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: model.heading).font(.largeTitle.bold())
                            Text(verbatim: model.subheading).foregroundStyle(.secondary)
                        }
                        Spacer()
                        let ids = analysedRideIDs
                        Button("Show on Map", systemImage: "map") { onShowOnMap(ids) }
                            .buttonStyle(.link)
                            .disabled(ids.isEmpty)
                            .help(Text("Show exactly these rides on the map"))
                    }
                    if model.current.rideCount == 0 {
                        ContentUnavailableView("No Rides in This Period", systemImage: "chart.bar",
                                               description: Text("Choose another period or import rides."))
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        TotalsGrid(model: model)
                        AveragesCard(model: model)
                        BarChartCard(model: model, metric: $barMetric,
                                     grouping: Binding(get: { model.grouping }, set: { groupingChoice = $0 }))
                        trends(model)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 4)
                .padding(.bottom, 40)
                .frame(maxWidth: 1100, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onChange(of: kind) {
            offset = 0
            groupingChoice = nil
        }
        .onChange(of: analysedRideIDs, initial: true) { onAnalysedRidesChange($1) }
    }

    /// The rides the analysis shows: the selection, or the period's rides without
    /// the sample ride, as in `AnalysisModel`.
    private var analysedRideIDs: Set<UUID> {
        if let selection { return selection }
        let interval = period.interval(calendar: calendar)
        return Set(rides.filter { !$0.isSample && (interval?.contains($0.startDate) ?? true) }.map(\.id))
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 12) {
            if selection != nil {
                selectionChip
            } else {
                Picker("Period", selection: $kind) {
                    ForEach(AnalysisPeriodKind.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                BikeFilterMenu(filter: $bikeFilterChoice)
                SourceFilterMenu(filter: $sourceFilterChoice, hasGPXRides: hasGPXRides)
                if kind.isSteppable {
                    HStack(spacing: 4) {
                        Button { offset -= 1 } label: { Image(systemName: "chevron.left") }
                            .help(Text("Previous period"))
                            .accessibilityLabel(Text("Previous period"))
                            .keyboardShortcut(.leftArrow, modifiers: .command)
                        Button { offset = min(0, offset + 1) } label: { Image(systemName: "chevron.right") }
                            .disabled(offset >= 0)
                            .help(Text("Next period"))
                            .accessibilityLabel(Text("Next period"))
                            .keyboardShortcut(.rightArrow, modifiers: .command)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                }
                if kind == .custom {
                    DatePicker("From", selection: $customStart, displayedComponents: .date)
                        .fixedSize()
                    DatePicker("To", selection: $customEnd, displayedComponents: .date)
                        .fixedSize()
                }
            }
            Spacer()
        }
    }

    private var selectionChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.square")
            Text("\(selection?.count ?? 0) selected rides")
            Button(action: onClearSelection) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .help(Text("Analyze all rides instead"))
            .accessibilityLabel(Text("Analyze all rides instead"))
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.14), in: Capsule())
    }

    // MARK: Trends

    @ViewBuilder
    private func trends(_ model: AnalysisModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Trends").font(.title2.bold())
            Text("Average of each ride, with a moving average over 5 rides")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
        TrendCard(model: model, metric: .averagePower, title: "Avg power", color: .metricPower)
        TrendCard(model: model, metric: .averageCadence, title: "Avg cadence", color: .metricCadence)
        TrendCard(model: model, metric: .averageSpeed, title: "Avg speed", color: .metricSpeed)
    }
}
