import Foundation

func pivotSuite() -> Suite {
    let s = Suite("Pivot position")

    s.test("the position table is right at every boundary") {
        try expectEqual(Tokenizer.pivotPosition(forCoreLength: 1), 1)
        try expectEqual(Tokenizer.pivotPosition(forCoreLength: 2), 2)
        try expectEqual(Tokenizer.pivotPosition(forCoreLength: 5), 2)
        try expectEqual(Tokenizer.pivotPosition(forCoreLength: 6), 3)
        try expectEqual(Tokenizer.pivotPosition(forCoreLength: 9), 3)
        try expectEqual(Tokenizer.pivotPosition(forCoreLength: 10), 4)
        try expectEqual(Tokenizer.pivotPosition(forCoreLength: 30), 4)
    }

    s.test("plain words get the expected anchor letter") {
        try expectEqual(Tokenizer.pivotIndex(in: "a"), 0)
        try expectEqual(Tokenizer.pivotIndex(in: "the"), 1)
        try expectEqual(Tokenizer.pivotIndex(in: "quick"), 1)
        try expectEqual(Tokenizer.pivotIndex(in: "reading"), 2)
        try expectEqual(Tokenizer.pivotIndex(in: "extraordinary"), 3)
        try expectEqual(Tokenizer.pivotIndex(in: String(repeating: "z", count: 30)), 3)
    }

    s.test("a leading quote does not push the anchor off the letters") {
        try expectEqual(Tokenizer.pivotIndex(in: "\"reading"), 3)
        try expectEqual(Tokenizer.pivotIndex(in: "(the)"), 2)
    }

    s.test("trailing punctuation does not change the anchor") {
        try expectEqual(Tokenizer.pivotIndex(in: "reading,"), Tokenizer.pivotIndex(in: "reading"))
        try expectEqual(Tokenizer.pivotIndex(in: "the."), Tokenizer.pivotIndex(in: "the"))
    }

    s.test("a token with no letters still has a sane anchor") {
        try expectEqual(Tokenizer.pivotIndex(in: "---"), 1)
        try expectEqual(Tokenizer.pivotIndex(in: ""), 0)
    }

    return s
}

func pacingSuite() -> Suite {
    let s = Suite("Pacing")

    s.test("sentence ends are recognised through closing quotes") {
        try expect(Tokenizer.endsSentence("end."))
        try expect(Tokenizer.endsSentence("really?"))
        try expect(Tokenizer.endsSentence("said.\""))
        try expectFalse(Tokenizer.endsSentence("middle"))
        try expectFalse(Tokenizer.endsSentence("clause,"))
    }

    s.test("clause ends are recognised") {
        try expect(Tokenizer.endsClause("clause,"))
        try expect(Tokenizer.endsClause("list:"))
        try expectFalse(Tokenizer.endsClause("plain"))
    }

    s.test("hold times follow the longest applicable rule") {
        try expectEqual(Tokenizer.multiplier(for: "plain", isParagraphEnd: false), 1.0)
        try expectEqual(Tokenizer.multiplier(for: "extraordinary", isParagraphEnd: false), 1.3)
        try expectEqual(Tokenizer.multiplier(for: "however,", isParagraphEnd: false), 1.5)
        try expectEqual(Tokenizer.multiplier(for: "stop.", isParagraphEnd: false), 2.0)
        try expectEqual(Tokenizer.multiplier(for: "stop.", isParagraphEnd: true), 2.5)
        // Rules take the maximum rather than compounding.
        try expectEqual(Tokenizer.multiplier(for: "extraordinary.", isParagraphEnd: false), 2.0)
    }

    return s
}

func tokenizeSuite() -> Suite {
    let s = Suite("Tokenizing")

    s.test("splits into words and marks paragraph ends") {
        let tokens = Tokenizer.tokenize("One two three.\n\nSecond para here.")
        try expectEqual(tokens.map(\.text), ["One", "two", "three.", "Second", "para", "here."])
        try expect(tokens[2].isParagraphEnd)
        try expectFalse(tokens[1].isParagraphEnd)
        try expect(tokens[5].isParagraphEnd)
    }

    s.test("a wrapped line is not a paragraph break") {
        let tokens = Tokenizer.tokenize("wrapped line\none\n\nnext")
        try expectEqual(tokens.count, 4)
        try expectFalse(tokens[1].isParagraphEnd)
        try expect(tokens[2].isParagraphEnd)
    }

    s.test("blank text produces no tokens") {
        try expect(Tokenizer.tokenize("   \n\n  ").isEmpty)
    }

    return s
}
