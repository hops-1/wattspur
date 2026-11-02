import SwiftUI

/// The tab “More” (design C): the folder shared with the Mac, or with the iPhone's own store the
/// trash (B-217), and the version.
struct MoreView: View {
    @Environment(ImportFolder.self) private var folder
    @Environment(PhoneLibrary.self) private var library

    var body: some View {
        Form {
            if library.usesDatabase {
                Section {
                    NavigationLink {
                        TrashView()
                    } label: {
                        LabeledContent {
                            Text(library.trash.count.formatted())
                        } label: {
                            Label("Trash", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("Library")
                } footer: {
                    if library.mode == .iCloud {
                        Text("Your rides are on this iPhone and in your own iCloud account, the same as on your Mac.")
                    } else {
                        Text("Your rides are on this iPhone. Sync with the Mac comes with iCloud.")
                    }
                }
            } else {
                folderSection
            }

            Section {
                VersionFooter()
            }
        }
        .navigationTitle("More")
    }

    private var folderSection: some View {
        Section {
            if let url = folder.url {
                LabeledContent("Folder", value: url.lastPathComponent)
            } else {
                Text("No folder chosen yet.")
                    .foregroundStyle(.secondary)
            }
            ChooseFolderButton(title: folder.url == nil ? "Choose Folder…" : "Choose Another Folder…")
            if let problem = folder.problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Wattspur Import")
        } footer: {
            Text("Choose the folder “Wattspur Import” in iCloud Drive that the Mac watches.")
        }
    }
}
