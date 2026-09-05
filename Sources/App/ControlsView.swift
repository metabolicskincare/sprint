import SwiftUI

struct ControlsView: View {
    @EnvironmentObject private var engine: ReaderEngine
    @State private var scrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        VStack(spacing: 10) {
            scrubber
            HStack(spacing: 18) {
                transport
                Divider().frame(height: 18).overlay(Theme.guideLine)
                speed
                Spacer(minLength: 12)
                chunkPicker
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(Theme.controlSurface)
    }

    // MARK: Scrubber

    private var scrubber: some View {
        HStack(spacing: 12) {
            Text(engine.documentTitle)
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim)
                .lineLimit(1)
                .frame(maxWidth: 220, alignment: .leading)

            Slider(
                value: Binding(
                    get: { scrubbing ? scrubValue : engine.progress },
                    set: { scrubValue = $0; engine.seek(toProgress: $0) }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    if editing { scrubValue = engine.progress }
                    scrubbing = editing
                }
            )
            .controlSize(.small)
            .tint(Theme.pivot)

            Text("\(engine.currentTokenIndex) / \(engine.tokenCount)  ·  \(timeLeft) left")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Theme.dim)
                .fixedSize()
        }
    }

    private var timeLeft: String {
        let seconds = Int(engine.remainingSeconds.rounded())
        return seconds >= 60 ? "\(seconds / 60)m \(seconds % 60)s" : "\(seconds)s"
    }

    // MARK: Transport

    private var transport: some View {
        HStack(spacing: 10) {
            iconButton("gobackward", help: "Back to the start") { engine.restart() }
            iconButton("arrow.uturn.backward", help: "Back a sentence (⇧←)") { engine.rewindSentence() }
            iconButton("gobackward.10", help: "Back 10 words (←)") { engine.skipWords(-10) }

            Button(action: { engine.toggle() }) {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15))
                    .frame(width: 34, height: 26)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Theme.word)
            .help(engine.isPlaying ? "Pause (space)" : "Play (space)")

            iconButton("goforward.10", help: "Forward 10 words (→)") { engine.skipWords(10) }
        }
    }

    private func iconButton(_ name: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 13))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Theme.dim)
        .help(help)
    }

    // MARK: Speed

    private var speed: some View {
        HStack(spacing: 8) {
            Slider(
                value: Binding(get: { Double(engine.wpm) }, set: { engine.wpm = Int($0.rounded()) }),
                in: 50...1200,
                step: 25
            )
            .controlSize(.small)
            .tint(Theme.word)
            .frame(width: 150)

            Text("\(engine.wpm) wpm")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Theme.word)
                .frame(width: 68, alignment: .leading)
        }
        .help("Reading speed (↑ / ↓)")
    }

    // MARK: Chunk size

    private var chunkPicker: some View {
        HStack(spacing: 10) {
            Toggle("Pause at punctuation", isOn: Binding(
                get: { engine.smartPauses }, set: { engine.smartPauses = $0 }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 11))
            .foregroundStyle(Theme.dim)

            Picker("", selection: Binding(
                get: { engine.chunkSize }, set: { engine.chunkSize = $0 }
            )) {
                Text("1").tag(1)
                Text("2").tag(2)
                Text("3").tag(3)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 96)
            .help("Words shown at a time")
        }
    }
}
