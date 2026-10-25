import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WattspurKit

/// The "Profile" section (B-134, ACC-01, PROF-01, PROF-03): the rider with body data
/// and the bikes as tiles. The star marks the active bike, the one new rides go to.
/// No password, no server – the macOS user account already protects the data.
struct ProfileView: View {
    @Query private var riders: [Rider]
    @Query private var bikes: [Bike]
    @State private var editor: BikeEditorTarget?

    @Environment(RideLibrary.self) private var library
    private var openBikes: [Bike] { Bike.sorted(bikes.filter { !$0.isArchived }) }
    private var archivedBikes: [Bike] { Bike.sorted(bikes.filter(\.isArchived)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Profile").font(.largeTitle.bold())
                    Spacer()
                    Label("No online account: profile and rides stay on this Mac.", systemImage: "lock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let rider = riders.first {
                    RiderCard(rider: rider)
                    bikesSection(rider: rider)
                    if !archivedBikes.isEmpty { archivedSection }
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 44)
            .padding(.bottom, 28)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        // A library that has never been opened by 1.5 has no bike yet.
        .onAppear {
            library.prepareBikes()
            #if DEBUG
            // Screenshots: -WattspurDemoEditor new|edit opens the bike editor.
            switch DemoMode.editor {
            case "new"?: editor = .new
            case "edit"?: editor = openBikes.dropFirst().first.map { .edit($0) } ?? openBikes.first.map { .edit($0) }
            default: break
            }
            #endif
        }
        .sheet(item: $editor) { target in
            BikeEditorView(target: target)
        }
    }

    // MARK: - Bikes

    private func bikesSection(rider: Rider) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text("Bikes").font(.title2.bold())
                Text("\(openBikes.count) active · \(archivedBikes.count) archived")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Label("New rides go to the active bike", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button { editor = .new } label: { Label("Add Bike", systemImage: "plus") }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 290, maximum: 420), spacing: 20, alignment: .top)], spacing: 20) {
                ForEach(openBikes) { bike in
                    BikeTile(bike: bike, isActive: rider.activeBikeID == bike.id,
                             onActivate: { library.setActiveBike(bike) },
                             onEdit: { editor = .edit(bike) })
                }
            }
        }
    }

    private var archivedSection: some View {
        DisclosureGroup {
            VStack(spacing: 10) {
                ForEach(archivedBikes) { bike in
                    HStack(spacing: 12) {
                        BikeChip(kind: bike.kind, color: bike.color, size: 36)
                            .opacity(0.6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: bike.name).font(.body.weight(.semibold))
                            let stats = bike.statistics
                            Text("\(bike.subtitle) · \(RideFormat.distance(stats.totalDistance)) · \(stats.rideCount) rides")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Spacer()
                        Text("The rides stay assigned; the bike is missing from the Import menu but stays in the filters.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 320, alignment: .trailing)
                            .multilineTextAlignment(.trailing)
                        Button("Restore") { library.unarchive(bike) }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAction(named: Text("Restore")) { library.unarchive(bike) }
                }
            }
            .padding(.top, 10)
        } label: {
            Text("Archived bikes (\(archivedBikes.count))").font(.callout.weight(.semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    }
}

/// What the bike editor is working on.
enum BikeEditorTarget: Identifiable {
    case new
    case edit(Bike)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let bike): bike.id.uuidString
        }
    }
}

// MARK: - Rider

extension RiderSex {
    var name: LocalizedStringKey {
        switch self {
        case .unspecified: "Not specified"
        case .female: "Female"
        case .male: "Male"
        }
    }
}

/// Avatar, name and body data (PROF-01). Every field is optional; the body data is
/// only used for the calorie estimate "with profile" (B-067).
private struct RiderCard: View {
    @Bindable var rider: Rider
    @State private var choosingPhoto = false
    @State private var photoFailed = false

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(spacing: 10) {
                RiderAvatar(rider: rider, size: 84)
                Button(rider.photoData == nil ? "Choose Photo…" : "Change Photo…") { choosingPhoto = true }
                    .controlSize(.small)
                if rider.photoData != nil {
                    Button("Remove Photo") { rider.photoData = nil }
                        .controlSize(.small)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 130)

            VStack(alignment: .leading, spacing: 16) {
                LabeledField("Name") {
                    TextField("Name", text: $rider.name, prompt: Text("Your name"))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                        .labelsHidden()
                }
                HStack(alignment: .bottom, spacing: 22) {
                    LabeledField("Weight") {
                        HStack(spacing: 6) {
                            NumberField("Weight", value: weight, range: ProfileInput.weightKg, width: 80)
                            Text("kg")
                        }
                    }
                    LabeledField("Height") {
                        HStack(spacing: 6) {
                            NumberField("Height", value: height, range: ProfileInput.heightCm, width: 80)
                            Text("cm")
                        }
                    }
                    LabeledField("Birth year") {
                        TextField("Birth year", value: birthYear, format: .number.grouping(.never), prompt: Text("Year"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                            .labelsHidden()
                            .monospacedDigit()
                    }
                    LabeledField("Sex") {
                        Picker("Sex", selection: $rider.sex) {
                            ForEach([RiderSex.unspecified, .female, .male]) { Text($0.name).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    Spacer(minLength: 0)
                }
                Text("All fields are optional and stay on this Mac. Wattspur will use them for a “with profile” calorie estimate in a later version.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("You"))
        .fileImporter(isPresented: $choosingPhoto, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result, let data = PhotoPicker.load(url, maxEdge: 512) else {
                photoFailed = true
                return
            }
            rider.photoData = data
        }
        .alert("The photo could not be read", isPresented: $photoFailed) {} message: {
            Text("Choose an image file such as JPEG, PNG or HEIC.")
        }
    }

    // Values outside the plausible range are dropped instead of stored (ProfileInput).
    private var weight: Binding<Double?> {
        Binding(get: { rider.weightKg }, set: { rider.weightKg = ProfileInput.accepted($0, in: ProfileInput.weightKg) })
    }
    private var height: Binding<Double?> {
        Binding(get: { rider.heightCm }, set: { rider.heightCm = ProfileInput.accepted($0, in: ProfileInput.heightCm) })
    }
    private var birthYear: Binding<Int?> {
        Binding(get: { rider.birthYear }, set: { rider.birthYear = ProfileInput.accepted($0, in: ProfileInput.birthYears()) })
    }
}

/// A caption above a control.
struct LabeledField<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content
        }
    }
}

/// A number field that stores `nil` for an empty or implausible entry.
struct NumberField: View {
    let title: LocalizedStringKey
    @Binding var value: Double?
    let range: ClosedRange<Double>
    var width: CGFloat = 80
    var prompt: LocalizedStringKey?

    init(_ title: LocalizedStringKey, value: Binding<Double?>, range: ClosedRange<Double>, width: CGFloat = 80, prompt: LocalizedStringKey? = nil) {
        self.title = title
        _value = value
        self.range = range
        self.width = width
        self.prompt = prompt
    }

    var body: some View {
        TextField(title, value: $value, format: .number, prompt: prompt.map { Text($0) })
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
            .labelsHidden()
            .monospacedDigit()
            .accessibilityLabel(Text(title))
    }
}

/// The rider's photo or initial in a circle.
struct RiderAvatar: View {
    let rider: Rider?
    var size: CGFloat

    var body: some View {
        Group {
            if let data = rider?.photoData, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Text(verbatim: String(rider?.name.nonEmpty?.prefix(1) ?? "?").uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

// MARK: - Bike tile

/// A bike with photo, numbers and the star for the active bike.
private struct BikeTile: View {
    let bike: Bike
    let isActive: Bool
    let onActivate: () -> Void
    let onEdit: () -> Void

    var body: some View {
        let stats = bike.statistics
        VStack(alignment: .leading, spacing: 0) {
            photoArea
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    bike.chip
                    Text(verbatim: bike.name).font(.headline).lineLimit(1)
                    Spacer(minLength: 4)
                    Button(action: onActivate) {
                        Image(systemName: isActive ? "star.fill" : "star")
                            .font(.system(size: 16))
                            .foregroundStyle(isActive ? Color.orange : Color.secondary)
                            .frame(width: 32, height: 32)
                            .background(isActive ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05), in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(isActive ? Text("Active bike") : Text("Make active bike"))
                    .accessibilityLabel(Text(isActive ? "Active bike" : "Make active bike"))
                    .accessibilityAddTraits(isActive ? .isSelected : [])
                }
                Text(verbatim: bike.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(2)
                HStack(alignment: .top, spacing: 8) {
                    figure("Distance", RideFormat.distance(stats.totalDistance))
                    figure("Rides", stats.rideCount.formatted())
                    figure("Last ride", stats.lastRide.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "–")
                }
                .padding(.top, 2)
                HStack {
                    Button("Edit…", action: onEdit).controlSize(.small)
                    Spacer()
                    if bike.startKilometers > 0 {
                        Text("incl. \(bike.startKilometers.formatted(.number.precision(.fractionLength(0...1)))) km start value")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(.background))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isActive ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.separator), lineWidth: isActive ? 2 : 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: bike.name))
        .accessibilityValue(Text("\(bike.subtitle), \(RideFormat.distance(stats.totalDistance)), \(stats.rideCount) rides"))
        .contextMenu {
            Button("Edit…", action: onEdit)
            if !isActive { Button("Make active bike", action: onActivate) }
        }
    }

    @ViewBuilder
    private var photoArea: some View {
        ZStack(alignment: .topLeading) {
            if let photo = bike.photo {
                // The photo only fills the tile; its size does not change the layout.
                Color.clear
                    .overlay { Image(nsImage: photo).resizable().scaledToFill() }
                    .clipped()
            } else {
                bike.color.color.opacity(0.14)
                    .overlay { BikeKindIcon(kind: bike.kind, size: 64).foregroundStyle(bike.color.color) }
            }
            if isActive {
                Text("Active")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.accentColor, in: Capsule())
                    .padding(12)
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func figure(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(verbatim: value).font(.system(size: 16, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Photos

enum PhotoPicker {
    /// Reads an image the user picked (security-scoped) and scales it for storage.
    static func load(_ url: URL, maxEdge: Int) -> Data? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return PhotoScaler.jpegData(from: data, maxEdge: maxEdge)
    }
}
