import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WattspurCore

/// “Share to Wattspur” (B-301): Wattspur in the app row of the share sheet, for apps that share a FIT
/// or GPX file, the same as data, or only a link. Files go to the App Group (`SharedImports`) and the
/// app opens to import them as any other file (`ImportFlow`, B-188); several at once give the summary
/// of B-300. A link is not loaded: the sheet says how to export the file in that app.
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareView(model: model) { [weak self] in self?.finish() })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        Task { @MainActor in
            await model.take(providers)
            if case .sent = model.state {
                if openApp() {
                    finish()
                } else {
                    model.state = .sent(count: model.sentCount, opened: false)
                }
            }
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// Opens the app with `wattspur://import`. A share extension has no `UIApplication.shared`; the
    /// application is found along the responder chain instead. When that fails, the sheet asks to
    /// open Wattspur, which then finds the files by itself.
    private func openApp() -> Bool {
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(SharedImports.openURL, options: [:], completionHandler: nil)
                return true
            }
            responder = current.next
        }
        return false
    }
}

@MainActor @Observable
final class ShareModel {
    enum State: Equatable {
        case working
        /// The files are in the App Group; `opened`: the app was opened to import them.
        case sent(count: Int, opened: Bool)
        /// Only a link came, from this service.
        case link(SharedItem.LinkSource)
        case nothing
        case failed(String)
    }

    var state: State = .working
    private(set) var sentCount = 0

    private static let fileTypes: [UTType] = [
        UTType("com.garmin.fit") ?? .data, UTType("com.topografix.gpx") ?? .xml, .xml,
    ]

    /// Reads every shared item: files and data first; a link only counts when nothing else came.
    /// Files are copied, never read into memory (B-361): several large GPX files at once were too
    /// much for the extension (S-45).
    func take(_ providers: [NSItemProvider]) async {
        // The system deletes the files it hands over after each handler: they are copied here first.
        let staging = FileManager.default.temporaryDirectory.appending(path: "Share-\(UUID().uuidString)",
                                                                       directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: staging) }
        var items: [SharedDrop.Item] = []
        var link: URL?
        for provider in providers {
            if let type = provider.registeredContentTypes.first(where: { type in Self.fileTypes.contains { type.conforms(to: $0) } }),
               let item = await Self.loadFile(provider, type: type, staging: staging) {
                items.append(item)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                      let url = await Self.loadURL(provider) {
                if url.isFileURL {
                    items.append(.file(url, suggestedName: url.lastPathComponent))
                } else if link == nil, SharedItem.linkSource(of: url) != nil {
                    link = url
                }
            } else if link == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                      let text = await Self.loadText(provider) {
                link = SharedItem.link(in: text)
            }
        }
        if items.contains(where: { SharedDrop.fileExtension(of: $0) != nil }) {
            do {
                guard let base = SharedImports.folder else { throw CocoaError(.fileNoSuchFile) }
                sentCount = try SharedDrop.write(items, into: base)
                state = .sent(count: sentCount, opened: true)
            } catch {
                state = .failed(error.localizedDescription)
            }
        } else if let link, let source = SharedItem.linkSource(of: link) {
            state = .link(source)
        } else {
            state = .nothing
        }
    }

    // MARK: Loading

    /// A file, copied into `staging` while the system keeps it (it goes after the handler), or plain
    /// data where the app offers only that; with its name where the app gave one.
    private static func loadFile(_ provider: NSItemProvider, type: UTType, staging: URL) async -> SharedDrop.Item? {
        let suggested = provider.suggestedName
        let copy: URL? = await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(for: type, openInPlace: false) { url, _, _ in
                continuation.resume(returning: url.flatMap { Self.copy($0, into: staging) })
            }
        }
        if let copy { return .file(copy, suggestedName: suggested ?? copy.lastPathComponent) }
        // Some apps offer the type only as data, not as a file.
        let plain: Data? = await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(for: type) { data, _ in continuation.resume(returning: data) }
        }
        return plain.map { .data($0, suggestedName: suggested) }
    }

    /// Copies a file into a folder of its own in `staging`, so equal names do not collide.
    nonisolated private static func copy(_ url: URL, into staging: URL) -> URL? {
        let folder = staging.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let target = folder.appending(path: url.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: target)
            return target
        } catch {
            return nil
        }
    }

    private static func loadURL(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
        }
    }

    private static func loadText(_ provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { text, _ in continuation.resume(returning: text) }
        }
    }
}

/// The small sheet of the extension: a moment of “Sending”, then a hint when there is something to say.
struct ShareView: View {
    let model: ShareModel
    let done: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                Text(title).font(.headline).multilineTextAlignment(.center)
                if let message {
                    Text(message).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                if model.state == .working { ProgressView() }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(Text(verbatim: "Wattspur"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done).disabled(model.state == .working)
                }
            }
        }
    }

    private var symbol: String {
        switch model.state {
        case .working, .sent: "square.and.arrow.down"
        case .link: "link"
        case .nothing, .failed: "exclamationmark.triangle"
        }
    }

    private var title: String {
        switch model.state {
        case .working: String(localized: "Sending to Wattspur …")
        case .sent(let count, _): String(localized: "Sent to Wattspur: \(count)")
        case .link: String(localized: "Wattspur needs the file, not the link")
        case .nothing: String(localized: "No FIT or GPX file was shared")
        case .failed: String(localized: "The files could not be passed on")
        }
    }

    private var message: String? {
        switch model.state {
        case .working: nil
        case .sent(_, true): String(localized: "Wattspur opens and imports them.")
        case .sent(_, false): String(localized: "Open Wattspur to import them.")
        case .link(.komoot):
            String(localized: "In komoot, open the tour you have ridden, export it as a GPX file and share that file to Wattspur. A planned tour has no times and is not a ride.")
        case .link(.strava):
            String(localized: "In Strava on the web, open the activity and export it as GPX, then share the file to Wattspur.")
        case .link(.garmin):
            String(localized: "In Garmin Connect, open the activity and export it as GPX or as the original FIT file, then share the file to Wattspur.")
        case .link(.other):
            String(localized: "Wattspur does not load links. Export the ride as a FIT or GPX file in that app and share the file to Wattspur.")
        case .nothing:
            String(localized: "Wattspur reads rides as FIT or GPX files. Share the file of a ride, not a picture or a text.")
        case .failed(let detail): detail
        }
    }
}
