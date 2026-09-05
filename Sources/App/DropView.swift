import SwiftUI
import AppKit

struct DropView: View {
    @EnvironmentObject private var engine: ReaderEngine
    let isTargeted: Bool

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "text.aligncenter")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(isTargeted ? Theme.pivot : Theme.guideLine)

            Text("Drop a document here")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Theme.word)

            Text("Markdown, plain text, or PDF")
                .font(.system(size: 13))
                .foregroundStyle(Theme.dim)

            HStack(spacing: 10) {
                Button("Choose a File…") { FileOpener.presentOpenPanel() }
                Button("Read Clipboard") {
                    engine.load(text: NSPasteboard.general.string(forType: .string) ?? "")
                }
            }
            .controlSize(.large)
            .padding(.top, 6)

            if let message = engine.errorMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.pivot)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isTargeted ? Theme.pivot : Theme.guideLine.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 6])
                )
                .padding(28)
        )
    }
}
