import SwiftUI
import WattspurKit

/// The colour of a planned tour's line (B-373, B-371): blue, because the recording is magenta.
enum PlannedTourColor {
    static func line(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0x5A / 255, green: 0xA2 / 255, blue: 0xFF / 255)
            : Color(red: 0x15 / 255, green: 0x65 / 255, blue: 0xC0 / 255)
    }
}

/// “Ride or planned tour?” (B-372, sheet A of B-371): a GPX file whose times look estimated. The map
/// comes from each app (`preview`), because `Shared/` has no MapKit; the rest looks the same on the
/// Mac, iPad and iPhone. For a komoot file “Planned Tour” is preselected, otherwise “Ride”.
struct TourChoiceSheet<Preview: View>: View {
    let question: ImportFlow.TourQuestion
    let preview: Preview
    let onChoose: (_ asTour: Bool) -> Void
    let onCancel: () -> Void
    @State private var asTour: Bool

    init(question: ImportFlow.TourQuestion, @ViewBuilder preview: () -> Preview,
         onChoose: @escaping (_ asTour: Bool) -> Void, onCancel: @escaping () -> Void) {
        self.question = question
        self.preview = preview()
        self.onChoose = onChoose
        self.onCancel = onCancel
        _asTour = State(initialValue: question.suggestsTour)
    }

    private var name: String {
        let name = question.tour.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? RideLibrary.parseFileName(question.fileName).title : name
    }

    private var figures: String {
        let distance = ValueFormat.distance(question.tour.distance)
        guard let ascent = question.tour.ascent else { return distance }
        return String(localized: "\(distance) · \(ascent) m ascent")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ride or Planned Tour?")
                .font(.title3.weight(.semibold))
            preview
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)
                Text(figures).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            Picker("Import As", selection: $asTour) {
                Text("Planned Tour").tag(true)
                Text("Ride").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(asTour ? explanationTour : explanationRide)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Import") { onChoose(asTour) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }

    private var explanationTour: String {
        question.suggestsTour
            ? String(localized: "This tour was planned in komoot. Its times are komoot's estimate, so Wattspur keeps it as a planned tour, not as a ride.")
            : String(localized: "The times in this file look estimated. As a planned tour it keeps only the line, the distance and the heights.")
    }

    private var explanationRide: String {
        String(localized: "As a ride it counts with the times in the file, on the day they name.")
    }
}
