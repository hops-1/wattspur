import Charts
import SwiftUI
import WattspurCore
import WattspurKit

// MARK: - PDF

/// The shown part of the highlights as an A4 PDF for the share menu (B-336): the year (two
/// pages: overview, then the records of the year), the records, or the goals.
struct HighlightsPDF: Transferable {
    let tab: PadHighlightsTab
    let review: YearReview
    let isCurrentYear: Bool
    let records: [RideRecord]
    let goals: [PhoneDatabase.GoalValue]
    let goalRides: [HighlightRide]
    let rides: [UUID: PhoneDatabase.StatsRide]
    let sport: Sport
    let calendar: Calendar

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { pdf in await pdf.render() }
            .suggestedFileName { PDFFile.name($0.title) }
    }

    /// "Highlights 2026", "Highlights – Records", "Highlights – Goals".
    var title: String {
        switch tab {
        case .year: String(localized: "Highlights \(String(review.year))")
        case .records: String(localized: "Highlights – Records")
        case .goals: String(localized: "Highlights – Goals")
        }
    }

    @MainActor
    func render() async -> Data {
        let none: (UUID) -> Void = { _ in }
        let pages: [AnyView] = switch tab {
        case .year:
            [AnyView(PadYearReview(review: review, isCurrentYear: isCurrentYear, calendar: calendar, rides: rides,
                                   sport: sport, compact: true, pdf: true, showsRecords: false, onOpenRide: none)),
             AnyView(VStack(alignment: .leading, spacing: 14) {
                 PadYearReview(review: review, isCurrentYear: isCurrentYear, calendar: calendar, rides: rides,
                               sport: sport, compact: true, pdf: true, showsOverview: false, onOpenRide: none)
                 ReportPDF.createdNote
             })]
        case .records:
            [AnyView(VStack(alignment: .leading, spacing: 14) {
                PadRecords(records: records, rides: rides, sport: sport, compact: true, pdf: true, onOpenRide: none)
                ReportPDF.createdNote
            })]
        case .goals:
            [AnyView(VStack(alignment: .leading, spacing: 14) {
                PadGoals(goals: goals, rides: goalRides, calendar: calendar, compact: true, pdf: true)
                ReportPDF.createdNote
            })]
        }
        return ReportPDF.document(pages)
    }
}
