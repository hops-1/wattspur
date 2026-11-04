import SwiftUI
import UniformTypeIdentifiers

/// Shown while no folder is chosen (B-209): what the folder is for and a button to choose it.
struct ChooseFolderPrompt: View {
    @Environment(PhoneSync.self) private var sync
    @Environment(\.switchSync) private var switchSync

    var body: some View {
        ContentUnavailableView {
            Label("Connect to the Mac", systemImage: "folder.badge.plus")
        } description: {
            Text("Wattspur on the iPhone shows the rides from your Mac. Choose the folder the Mac watches, e.g. “Wattspur Import” in iCloud Drive.")
        } actions: {
            ChooseFolderButton()
                .buttonStyle(.borderedProminent)
            if sync.canChoose {
                Button("Sync with iCloud Instead") { switchSync(true) }
            }
        }
    }
}

/// Shown while the folder has no state from the Mac yet.
struct MacSettingPrompt: View {
    @Environment(PhoneLibrary.self) private var library

    var body: some View {
        ContentUnavailableView {
            Label("No Rides from the Mac Yet", systemImage: "desktopcomputer")
        } description: {
            Text("On the Mac, open Wattspur › Settings › Import and switch on “Provide rides for the iPhone”. Then pull down here to refresh.")
        } actions: {
            Button("Check Again") { Task { await library.refresh() } }
                .disabled(library.isLoading)
        }
    }
}

/// Shown while the iPhone's own store has no ride yet (B-216).
struct FirstRidePrompt: View {
    @Environment(PhoneLibrary.self) private var library

    var body: some View {
        ContentUnavailableView {
            Label("No Rides Yet", systemImage: "bicycle")
        } description: {
            if library.mode == .iCloud {
                Text("Record your first ride with “Start Ride”. Rides from your Mac appear here once it syncs with iCloud too.")
            } else {
                Text("Record your first ride with “Start Ride”. It is saved on this iPhone.")
            }
        }
    }
}

/// Opens the Files dialog for the folder “Wattspur Import”.
struct ChooseFolderButton: View {
    @Environment(ImportFolder.self) private var folder
    @Environment(PhoneLibrary.self) private var library
    @State private var choosing = false
    var title: LocalizedStringKey = "Choose Folder…"

    var body: some View {
        Button(title) { choosing = true }
            .fileImporter(isPresented: $choosing, allowedContentTypes: [.folder]) { result in
                guard case .success(let url) = result else { return }
                folder.use(url)
                Task { await library.folderChanged() }
            }
    }
}
