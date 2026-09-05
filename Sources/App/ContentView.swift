import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var engine: ReaderEngine
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            if engine.hasDocument {
                ReaderView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                ControlsView()
            } else {
                DropView(isTargeted: isTargeted)
            }
        }
        .background(Theme.background)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        .onExitCommand { engine.close() }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) })
        else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            switch item {
            case let data as Data: url = URL(dataRepresentation: data, relativeTo: nil)
            case let value as URL: url = value
            case let string as String: url = URL(string: string)
            default: url = nil
            }
            Task { @MainActor in
                guard let url else {
                    engine.errorMessage = "That didn't come through as a file Sprint could open."
                    return
                }
                engine.load(url: url)
            }
        }
        return true
    }
}
