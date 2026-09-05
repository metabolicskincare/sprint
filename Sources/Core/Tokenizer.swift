import Foundation

/// A single word from the document, ready to be displayed.
public struct Token: Equatable, Sendable {
    /// The word exactly as it will be drawn, punctuation included.
    public let text: String
    /// Index into `text` of the character that gets pinned to the anchor and coloured red.
    public let pivotIndex: Int
    /// How long this word is held on screen, relative to a plain word.
    public let multiplier: Double
    public let isSentenceEnd: Bool
    public let isParagraphEnd: Bool

    public init(text: String, pivotIndex: Int, multiplier: Double, isSentenceEnd: Bool, isParagraphEnd: Bool) {
        self.text = text
        self.pivotIndex = pivotIndex
        self.multiplier = multiplier
        self.isSentenceEnd = isSentenceEnd
        self.isParagraphEnd = isParagraphEnd
    }
}

public enum Tokenizer {

    // MARK: - Pivot

    /// The standard speed-reading pivot position, 1-based, for a word of `length` letters.
    /// 1 -> 1, 2...5 -> 2, 6...9 -> 3, 10+ -> 4.
    public static func pivotPosition(forCoreLength length: Int) -> Int {
        switch length {
        case ..<1: return 1
        case 1: return 1
        case 2...5: return 2
        case 6...9: return 3
        default: return 4
        }
    }

    /// Index of the pivot character within `word`, accounting for leading punctuation
    /// such as an opening quote so that the letters, not the quote, drive the position.
    public static func pivotIndex(in word: String) -> Int {
        let chars = Array(word)
        guard !chars.isEmpty else { return 0 }
        let isCore: (Character) -> Bool = { $0.isLetter || $0.isNumber }

        var start = 0
        while start < chars.count, !isCore(chars[start]) { start += 1 }
        // A token with no letters or digits at all (e.g. "---"): just use its middle.
        guard start < chars.count else { return (chars.count - 1) / 2 }

        var end = chars.count - 1
        while end > start, !isCore(chars[end]) { end -= 1 }

        let coreLength = end - start + 1
        let within = pivotPosition(forCoreLength: coreLength) - 1
        return start + min(within, coreLength - 1)
    }

    /// Number of letters and digits in `word`, ignoring surrounding punctuation.
    public static func coreLength(of word: String) -> Int {
        word.reduce(0) { $1.isLetter || $1.isNumber ? $0 + 1 : $0 }
    }

    // MARK: - Pacing

    static let sentenceEnders: Set<Character> = [".", "!", "?", "\u{2026}"]
    static let clauseEnders: Set<Character> = [",", ";", ":", "\u{2014}"]

    public static func endsSentence(_ word: String) -> Bool {
        // Walk back past closing quotes and brackets: `said."` still ends a sentence.
        for ch in word.reversed() {
            if sentenceEnders.contains(ch) { return true }
            if ch.isLetter || ch.isNumber { return false }
        }
        return false
    }

    public static func endsClause(_ word: String) -> Bool {
        for ch in word.reversed() {
            if clauseEnders.contains(ch) { return true }
            if ch.isLetter || ch.isNumber { return false }
        }
        return false
    }

    /// Relative hold time. The longest applicable rule wins rather than compounding,
    /// so a long word at the end of a paragraph pauses once, not twice.
    public static func multiplier(for word: String, isParagraphEnd: Bool) -> Double {
        var value = 1.0
        if coreLength(of: word) > 8 { value = max(value, 1.3) }
        if endsClause(word) { value = max(value, 1.5) }
        if endsSentence(word) { value = max(value, 2.0) }
        if isParagraphEnd { value = max(value, 2.5) }
        return value
    }

    // MARK: - Tokenizing

    /// Splits plain text into display-ready tokens, preserving paragraph boundaries.
    public static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        let paragraphs = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .split(whereSeparator: { $0.isEmpty })
            .map { $0.joined(separator: " ") }

        for paragraph in paragraphs {
            let words = paragraph.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            for (i, word) in words.enumerated() {
                let isParagraphEnd = (i == words.count - 1)
                tokens.append(Token(
                    text: word,
                    pivotIndex: pivotIndex(in: word),
                    multiplier: multiplier(for: word, isParagraphEnd: isParagraphEnd),
                    isSentenceEnd: endsSentence(word) || isParagraphEnd,
                    isParagraphEnd: isParagraphEnd
                ))
            }
        }
        return tokens
    }
}
