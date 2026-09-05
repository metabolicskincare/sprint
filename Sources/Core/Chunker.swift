import Foundation

/// One screenful: a single word, or two or three words shown together.
public struct Chunk: Equatable, Sendable {
    public let text: String
    public let pivotIndex: Int
    public let multiplier: Double
    /// Index of this chunk's first token in the document, used for seeking and progress.
    public let firstTokenIndex: Int
    public let tokenCount: Int

    public init(text: String, pivotIndex: Int, multiplier: Double, firstTokenIndex: Int, tokenCount: Int) {
        self.text = text
        self.pivotIndex = pivotIndex
        self.multiplier = multiplier
        self.firstTokenIndex = firstTokenIndex
        self.tokenCount = tokenCount
    }
}

public enum Chunker {

    /// Groups tokens into chunks of at most `size`. Chunks never straddle a sentence
    /// or paragraph boundary, so a group is always a run of words that belong together.
    public static func chunk(_ tokens: [Token], size: Int) -> [Chunk] {
        let size = max(1, min(3, size))
        guard !tokens.isEmpty else { return [] }

        var chunks: [Chunk] = []
        var group: [Token] = []
        var groupStart = 0

        func flush() {
            guard !group.isEmpty else { return }
            let text = group.map(\.text).joined(separator: " ")
            // The pivot is computed on the joined string so the anchor stays honest
            // regardless of how many words share the screen.
            let raw = group.reduce(0) { $0 + $1.multiplier }
            // Two or three words read together land faster than the same words apart.
            let multiplier = group.count > 1 ? raw * 0.9 : raw
            chunks.append(Chunk(
                text: text,
                pivotIndex: Tokenizer.pivotIndex(in: text),
                multiplier: multiplier,
                firstTokenIndex: groupStart,
                tokenCount: group.count
            ))
            group = []
        }

        for (i, token) in tokens.enumerated() {
            if group.isEmpty { groupStart = i }
            group.append(token)
            if group.count == size || token.isSentenceEnd || token.isParagraphEnd {
                flush()
            }
        }
        flush()
        return chunks
    }

    /// The chunk that contains a given token, for seeking and for keeping the reader's
    /// place when the chunk size changes mid-document.
    public static func chunkIndex(containing tokenIndex: Int, in chunks: [Chunk]) -> Int {
        guard !chunks.isEmpty else { return 0 }
        var low = 0
        var high = chunks.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if chunks[mid].firstTokenIndex <= tokenIndex { low = mid } else { high = mid - 1 }
        }
        return low
    }
}
