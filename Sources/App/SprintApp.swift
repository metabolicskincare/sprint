import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Lets a document opened from Finder — double-clicked, or dropped on the app
/// icon — land in the reader.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor in ReaderEngine.shared.load(url: url) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct SprintApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var engine = ReaderEngine.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .frame(minWidth: 640, minHeight: 420)
                .background(Theme.background)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 560)
        .commands { SprintCommands() }
    }
}

// MARK: - Menu bar

struct SprintCommands: Commands {
    @ObservedObject private var engine = ReaderEngine.shared

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open…") { FileOpener.presentOpenPanel() }
                .keyboardShortcut("o")
            Button("Read Clipboard Text") {
                let text = NSPasteboard.general.string(forType: .string) ?? ""
                engine.load(text: text)
            }
            .keyboardShortcut("v")
        }

        CommandMenu("Reading") {
            Button(engine.isPlaying ? "Pause" : "Play") { engine.toggle() }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(!engine.hasDocument)

            Divider()

            Button("Back 10 Words") { engine.skipWords(-10) }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button("Forward 10 Words") { engine.skipWords(10) }
                .keyboardShortcut(.rightArrow, modifiers: [])
            Button("Back a Sentence") { engine.rewindSentence() }
                .keyboardShortcut(.leftArrow, modifiers: .shift)
            Button("Back to Start") { engine.restart() }

            Divider()

            Button("Faster") { engine.wpm += 25 }
                .keyboardShortcut(.upArrow, modifiers: [])
            Button("Slower") { engine.wpm -= 25 }
                .keyboardShortcut(.downArrow, modifiers: [])

            Divider()

            Picker("Words at a Time", selection: Binding(
                get: { engine.chunkSize },
                set: { engine.chunkSize = $0 }
            )) {
                Text("One").tag(1)
                Text("Two").tag(2)
                Text("Three").tag(3)
            }
            Toggle("Pause at Punctuation", isOn: Binding(
                get: { engine.smartPauses },
                set: { engine.smartPauses = $0 }
            ))

            Divider()

            Button("Close Document") { engine.close() }
                .disabled(!engine.hasDocument)
        }

        CommandGroup(after: .windowSize) {
            Button("Toggle Full Screen") { NSApp.keyWindow?.toggleFullScreen(nil) }
                .keyboardShortcut("f")
        }
    }
}

enum FileOpener {
    @MainActor
    static func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText, .pdf, UTType(filenameExtension: "md") ?? .plainText]
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url {
            ReaderEngine.shared.load(url: url)
        }
    }
}
