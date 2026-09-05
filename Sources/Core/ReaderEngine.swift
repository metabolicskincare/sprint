import Foundation
import Combine

/// Playback state for one document: what's on screen, how fast, and where we are.
@MainActor
public final class ReaderEngine: ObservableObject {

    public static let shared = ReaderEngine()

    // MARK: Published state

    @Published public private(set) var chunks: [Chunk] = []
    @Published public private(set) var tokenCount: Int = 0
    @Published public private(set) var index: Int = 0
    @Published public private(set) var isPlaying = false
    @Published public private(set) var isFinished = false
    @Published public private(set) var documentTitle: String = ""
    @Published public var errorMessage: String?

    @Published public var wpm: Int = 300 {
        didSet {
            // Clamp by re-assigning only when out of range: assigning unconditionally
            // would re-enter this observer forever.
            let clamped = min(1200, max(50, wpm))
            if wpm != clamped { wpm = clamped; return }
            guard wpm != oldValue else { return }
            defaults.set(wpm, forKey: Keys.wpm)
            if isPlaying { restartLoop() }
        }
    }

    @Published public var chunkSize: Int = 1 {
        didSet {
            let clamped = min(3, max(1, chunkSize))
            if chunkSize != clamped { chunkSize = clamped; return }
            guard chunkSize != oldValue else { return }
            defaults.set(chunkSize, forKey: Keys.chunkSize)
            rechunkPreservingPosition()
        }
    }

    @Published public var smartPauses: Bool = true {
        didSet {
            guard smartPauses != oldValue else { return }
            defaults.set(smartPauses, forKey: Keys.smartPauses)
            recomputeNormalization()
            if isPlaying { restartLoop() }
        }
    }

    // MARK: Private

    private enum Keys {
        static let wpm = "sprint.wpm"
        static let chunkSize = "sprint.chunkSize"
        static let smartPauses = "sprint.smartPauses"
    }

    private let defaults: UserDefaults
    private var tokens: [Token] = []
    private var loop: Task<Void, Never>?
    /// Scales hold times so the words-per-minute on screen is the real throughput,
    /// however many punctuation pauses the text happens to contain.
    private var normalization: Double = 1

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Keys.wpm) != nil { wpm = defaults.integer(forKey: Keys.wpm) }
        if defaults.object(forKey: Keys.chunkSize) != nil { chunkSize = defaults.integer(forKey: Keys.chunkSize) }
        if defaults.object(forKey: Keys.smartPauses) != nil { smartPauses = defaults.bool(forKey: Keys.smartPauses) }
    }

    // MARK: Derived

    public var hasDocument: Bool { !chunks.isEmpty }
    public var current: Chunk? { chunks.indices.contains(index) ? chunks[index] : nil }
    public var currentTokenIndex: Int { current?.firstTokenIndex ?? 0 }

    public var progress: Double {
        guard tokenCount > 0 else { return 0 }
        return Double(currentTokenIndex) / Double(tokenCount)
    }

    /// Seconds of reading left at the current speed, ignoring pauses.
    public var remainingSeconds: Double {
        guard tokenCount > 0 else { return 0 }
        return Double(tokenCount - currentTokenIndex) * 60.0 / Double(wpm)
    }

    // MARK: Loading

    public func load(url: URL) {
        do {
            let document = try DocumentLoader.load(url: url)
            load(document: document)
        } catch {
            stop()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    public func load(text: String, title: String = "Pasted text") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "There's no text on the clipboard to read."
            return
        }
        load(document: Document(title: title, text: trimmed))
    }

    public func load(document: Document) {
        stop()
        errorMessage = nil
        tokens = Tokenizer.tokenize(document.text)
        guard !tokens.isEmpty else {
            errorMessage = "\(document.title) doesn't have any words in it."
            return
        }
        tokenCount = tokens.count
        documentTitle = document.title
        rebuildChunks()
        index = 0
        isFinished = false
    }

    public func close() {
        stop()
        tokens = []
        chunks = []
        tokenCount = 0
        index = 0
        isFinished = false
        documentTitle = ""
        errorMessage = nil
    }

    private func rebuildChunks() {
        chunks = Chunker.chunk(tokens, size: chunkSize)
        recomputeNormalization()
    }

    private func recomputeNormalization() {
        let total = chunks.reduce(0) { $0 + effectiveMultiplier($1) }
        normalization = total > 0 ? Double(tokens.count) / total : 1
    }

    private func rechunkPreservingPosition() {
        guard !tokens.isEmpty else { return }
        let token = currentTokenIndex
        rebuildChunks()
        index = Chunker.chunkIndex(containing: token, in: chunks)
    }

    private func effectiveMultiplier(_ chunk: Chunk) -> Double {
        smartPauses ? chunk.multiplier : Double(chunk.tokenCount) * (chunk.tokenCount > 1 ? 0.9 : 1.0)
    }

    public func duration(of chunk: Chunk) -> Double {
        (60.0 / Double(wpm)) * effectiveMultiplier(chunk) * normalization
    }

    // MARK: Transport

    public func play() {
        guard hasDocument, !isPlaying else { return }
        if isFinished { index = 0; isFinished = false }
        isPlaying = true
        restartLoop()
    }

    public func pause() {
        loop?.cancel()
        loop = nil
        isPlaying = false
    }

    public func stop() {
        pause()
    }

    public func toggle() {
        isPlaying ? pause() : play()
    }

    private func restartLoop() {
        loop?.cancel()
        loop = Task { @MainActor [weak self] in
            guard let self else { return }
            // Track an absolute deadline so small scheduling overruns don't accumulate.
            var deadline = Date()
            while !Task.isCancelled, self.index < self.chunks.count {
                deadline = deadline.addingTimeInterval(self.duration(of: self.chunks[self.index]))
                let delay = deadline.timeIntervalSinceNow
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                if Task.isCancelled { return }
                if self.index + 1 >= self.chunks.count {
                    self.isPlaying = false
                    self.isFinished = true
                    self.loop = nil
                    return
                }
                self.index += 1
            }
        }
    }

    // MARK: Seeking

    public func seek(toChunk newIndex: Int) {
        guard hasDocument else { return }
        index = min(max(0, newIndex), chunks.count - 1)
        isFinished = false
        if isPlaying { restartLoop() }
    }

    public func seek(toToken tokenIndex: Int) {
        guard hasDocument else { return }
        let clamped = min(max(0, tokenIndex), max(0, tokenCount - 1))
        seek(toChunk: Chunker.chunkIndex(containing: clamped, in: chunks))
    }

    public func seek(toProgress fraction: Double) {
        seek(toToken: Int((Double(tokenCount) * min(max(0, fraction), 1)).rounded()))
    }

    public func skipWords(_ delta: Int) {
        seek(toToken: currentTokenIndex + delta)
    }

    /// Back to the first word of the sentence being read, or the previous one if
    /// we're already at the start of this sentence.
    public func rewindSentence() {
        guard hasDocument else { return }
        var i = currentTokenIndex - 1
        while i > 0, !tokens[i - 1].isSentenceEnd { i -= 1 }
        if i == currentTokenIndex, i > 0 {
            i -= 1
            while i > 0, !tokens[i - 1].isSentenceEnd { i -= 1 }
        }
        seek(toToken: max(0, i))
    }

    public func restart() {
        seek(toChunk: 0)
    }
}
