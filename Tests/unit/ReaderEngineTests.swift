import Foundation

@MainActor
func engineSuite() -> Suite {
    let s = Suite("Reader engine")

    /// A throwaway preferences suite so tests never touch the real settings.
    func makeEngine(_ text: String, wpm: Int = 300, chunkSize: Int = 1) -> ReaderEngine {
        let defaults = UserDefaults(suiteName: "sprint.tests.\(UUID().uuidString)")!
        let engine = ReaderEngine(defaults: defaults)
        engine.smartPauses = true
        engine.chunkSize = chunkSize
        engine.wpm = wpm
        engine.load(document: Document(title: "test", text: text))
        return engine
    }

    // The punctuation pauses redistribute time, they don't add it: a document read
    // at N words per minute should still take exactly as long as N implies.
    s.test("total reading time matches the stated speed") {
        let text = "Short words here, with a pause. And extraordinary lengthy vocabulary too.\n\nA second paragraph follows on."
        let e = makeEngine(text, wpm: 300)
        let total = e.chunks.reduce(0.0) { $0 + e.duration(of: $1) }
        let expected = Double(e.tokenCount) * 60.0 / 300.0
        try expectClose(total, expected, tolerance: expected * 0.001)
    }

    s.test("total time still holds with pauses switched off") {
        let e = makeEngine("One two three. Four five six, seven.", wpm: 400)
        e.smartPauses = false
        let total = e.chunks.reduce(0.0) { $0 + e.duration(of: $1) }
        let expected = Double(e.tokenCount) * 60.0 / 400.0
        try expectClose(total, expected, tolerance: expected * 0.001)
    }

    s.test("a full stop really does hold longer") {
        let e = makeEngine("plain word stop. next", wpm: 300)
        try expect(e.duration(of: e.chunks[2]) > e.duration(of: e.chunks[0]) * 1.5)
    }

    s.test("skipping clamps at both ends") {
        let e = makeEngine("a b c d e f g h i j")
        e.skipWords(4)
        try expectEqual(e.currentTokenIndex, 4)
        e.skipWords(-100)
        try expectEqual(e.currentTokenIndex, 0)
        e.skipWords(1000)
        try expectEqual(e.currentTokenIndex, e.tokenCount - 1)
    }

    s.test("rewind lands on the start of a sentence") {
        let e = makeEngine("One two three. Four five six. Seven eight.")
        e.seek(toToken: 7)                        // "eight."
        e.rewindSentence()
        try expectEqual(e.currentTokenIndex, 6)   // "Seven"
        e.rewindSentence()
        try expectEqual(e.currentTokenIndex, 3)   // "Four"
        e.rewindSentence()
        try expectEqual(e.currentTokenIndex, 0)   // "One"
    }

    s.test("changing how many words show at once keeps your place") {
        let e = makeEngine("a b c d e f g h i j k l")
        e.seek(toToken: 6)
        e.chunkSize = 3
        try expect(e.currentTokenIndex <= 6 && e.currentTokenIndex > 3,
                   "expected to stay near token 6, landed on \(e.currentTokenIndex)")
    }

    s.test("dragging the progress bar lands where you dropped it") {
        let e = makeEngine((1...100).map(String.init).joined(separator: " "))
        e.seek(toProgress: 0.5)
        try expectClose(e.progress, 0.5, tolerance: 0.02)
    }

    s.test("closing resets everything") {
        let e = makeEngine("a b c")
        e.close()
        try expectFalse(e.hasDocument)
        try expectEqual(e.tokenCount, 0)
        try expect(e.current == nil)
    }

    s.test("loading blank text says so instead of failing silently") {
        let e = ReaderEngine(defaults: UserDefaults(suiteName: "sprint.tests.\(UUID().uuidString)")!)
        e.load(text: "   ")
        try expectFalse(e.hasDocument)
        try expect(e.errorMessage != nil)
    }

    s.test("playback advances and stops at the end") {
        let e = makeEngine("one two three", wpm: 1200)
        e.play()
        try expect(e.isPlaying)
        try await Task.sleep(nanoseconds: 900_000_000)
        try expectFalse(e.isPlaying)
        try expect(e.isFinished)
        try expectEqual(e.index, e.chunks.count - 1)
    }

    return s
}
