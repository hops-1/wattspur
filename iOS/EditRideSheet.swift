import SwiftUI
import WattspurCore

/// Edit a ride on the iPhone (B-240): its name and its bike, as on the Mac. Only for rides of the
/// iPhone's own store; over iCloud the change reaches the Mac.
struct EditRideSheet: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    var ride: RideExchange.Ride

    @State private var name = ""
    @State private var bikeID: UUID?

    private var bikes: [RideExchange.Bike] {
        library.state?.bikesForEditing(current: ride.bikeID) ?? []
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .submitLabel(.done)
                    if !bikes.isEmpty {
                        Picker("Bike", selection: $bikeID) {
                            ForEach(bikes) { bike in
                                Label { Text(bike.name) } icon: { BikeBadge(bike: bike) }
                                    .tag(Optional(bike.id))
                            }
                        }
                    }
                } footer: {
                    if library.mode == .iCloud {
                        Text("The change reaches your Mac over iCloud.")
                    }
                }
            }
            .navigationTitle("Edit Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        library.edit(ride, name: trimmedName, bikeID: bikeID)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
        .onAppear {
            name = ride.name
            bikeID = ride.bikeID
        }
    }
}
