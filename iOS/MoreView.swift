import SwiftUI

/// The tab “More” (design C): the folder shared with the Mac and the version.
struct MoreView: View {
    @Environment(ImportFolder.self) private var folder

    var body: some View {
        Form {
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

            Section {
                VersionFooter()
            }
        }
        .navigationTitle("More")
    }
}
