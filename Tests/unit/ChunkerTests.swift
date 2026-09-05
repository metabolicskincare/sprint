import Foundation

func chunkerSuite() -> Suite {
    let s = Suite("Chunking")
    func tokens(_ text: String) -> [Token] { Tokenizer.tokenize(text) }

    s.test("size one is one word per screen") {
        let chunks = Chunker.chunk(tokens("alpha beta gamma"), size: 1)
        try expectEqual(chunks.map(\.text), ["alpha", "beta", "gamma"])
        try expectEqual(chunks.map(\.firstTokenIndex), [0, 1, 2])
    }

    s.test("words group up to the chosen size") {
        let chunks = Chunker.chunk(tokens("one two three four five six"), size: 3)
        try expectEqual(chunks.map(\.text), ["one two three", "four five six"])
    }

    s.test("a group never straddles a sentence end") {
        let chunks = Chunker.chunk(tokens("stop here. now go on"), size: 3)
        try expectEqual(chunks.first?.text, "stop here.")
    }

    s.test("a group never straddles a paragraph") {
        let chunks = Chunker.chunk(tokens("one two\n\nthree four"), size: 3)
        try expectEqual(chunks.map(\.text), ["one two", "three four"])
    }

    s.test("grouped words read slightly faster than the same words apart") {
        // Mid-paragraph words, so neither carries a punctuation or paragraph pause.
        let chunks = Chunker.chunk(tokens("one two three four"), size: 2)
        try expectClose(chunks[0].multiplier, 2.0 * 0.9, tolerance: 0.0001)
    }

    s.test("the last word of a paragraph keeps its long pause inside a group") {
        let chunks = Chunker.chunk(tokens("one two"), size: 2)
        try expectEqual(chunks.count, 1)
        try expectClose(chunks[0].multiplier, (1.0 + 2.5) * 0.9, tolerance: 0.0001)
    }

    s.test("finding the chunk that holds a token") {
        let chunks = Chunker.chunk(tokens("a b c d e f g h"), size: 2)
        try expectEqual(Chunker.chunkIndex(containing: 0, in: chunks), 0)
        try expectEqual(Chunker.chunkIndex(containing: 1, in: chunks), 0)
        try expectEqual(Chunker.chunkIndex(containing: 2, in: chunks), 1)
        try expectEqual(Chunker.chunkIndex(containing: 7, in: chunks), 3)
    }

    s.test("out-of-range sizes are clamped to 1...3") {
        try expectEqual(Chunker.chunk(tokens("a b c d"), size: 99).map(\.text), ["a b c", "d"])
        try expectEqual(Chunker.chunk(tokens("a b"), size: 0).map(\.text), ["a", "b"])
    }

    return s
}
