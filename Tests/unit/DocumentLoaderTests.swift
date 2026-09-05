import Foundation

func markdownSuite() -> Suite {
    let s = Suite("Markdown stripping")

    s.test("headings and emphasis markers go away") {
        let out = DocumentLoader.stripMarkdown("# Title\n\nSome **bold** and *italic* text.")
        try expectNotContains(out, "#")
        try expectNotContains(out, "*")
        try expectContains(out, "Some bold and italic text.")
    }

    s.test("link text is kept and the URL dropped") {
        let out = DocumentLoader.stripMarkdown("See [the docs](https://example.com/page) now.")
        try expectContains(out, "See the docs now.")
        try expectNotContains(out, "example.com")
    }

    s.test("images are dropped entirely") {
        let out = DocumentLoader.stripMarkdown("Before ![alt text](img.png) after")
        try expectNotContains(out, "alt text")
        try expectContains(out, "Before")
        try expectContains(out, "after")
    }

    s.test("fenced code blocks are dropped") {
        let md = "Intro line.\n\n```swift\nlet x = compute(1, 2)\n```\n\nOutro line."
        let out = DocumentLoader.stripMarkdown(md)
        try expectNotContains(out, "compute")
        try expectContains(out, "Intro line.")
        try expectContains(out, "Outro line.")
    }

    s.test("list markers and quote markers are removed, text kept") {
        let out = DocumentLoader.stripMarkdown("- first item\n2. second item\n> quoted line")
        try expectContains(out, "first item")
        try expectContains(out, "second item")
        try expectContains(out, "quoted line")
        try expectNotContains(out, ">")
    }

    s.test("inline code keeps its contents") {
        try expectContains(DocumentLoader.stripMarkdown("Run `swift build` first."), "Run swift build first.")
    }

    s.test("a wiki link reads as words, not as a path") {
        let out = DocumentLoader.stripMarkdown("See [[Personal/Direction/one-page-direction]] for more.")
        try expectContains(out, "See one page direction for more.")
        try expectNotContains(out, "[[")
        try expectNotContains(out, "Personal/")
    }

    s.test("a wiki link with its own label keeps the label") {
        let out = DocumentLoader.stripMarkdown("Check [[research/q4-q6-solo-ai|the solo AI notes]] later.")
        try expectContains(out, "Check the solo AI notes later.")
    }

    s.test("a wiki link pointing at a heading drops the heading") {
        try expectContains(DocumentLoader.stripMarkdown("[[my-note#Some Heading]]"), "my note")
    }

    s.test("underscores inside a word survive") {
        try expectContains(DocumentLoader.stripMarkdown("The value_of_this stays intact."), "value_of_this")
    }

    return s
}

func reflowSuite() -> Suite {
    let s = Suite("PDF reflow")

    s.test("words hyphenated across a line break are rejoined") {
        try expectContains(DocumentLoader.reflow("extraor-\ndinary word"), "extraordinary")
    }

    s.test("single breaks fold, blank lines stay paragraphs") {
        let out = DocumentLoader.reflow("line one\nline two\n\nnew para")
        try expectContains(out, "line one line two")
        try expectContains(out, "\n\nnew para")
    }

    return s
}

func loadSuite() -> Suite {
    let s = Suite("Loading files")

    func write(_ contents: String, ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sprint-test-\(UUID().uuidString).\(ext)")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    s.test("plain text loads verbatim") {
        let url = try write("Hello there reader.", ext: "txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try expectEqual(try DocumentLoader.load(url: url).text, "Hello there reader.")
    }

    s.test("markdown loads with its syntax stripped") {
        let url = try write("# Heading\n\nBody **text** here.", ext: "md")
        defer { try? FileManager.default.removeItem(at: url) }
        let doc = try DocumentLoader.load(url: url)
        try expectContains(doc.text, "Body text here.")
        try expectNotContains(doc.text, "#")
    }

    s.test("an unsupported file type is rejected by name") {
        let url = try write("data", ext: "docx")
        defer { try? FileManager.default.removeItem(at: url) }
        var caught: LoadError?
        do { _ = try DocumentLoader.load(url: url) } catch let e as LoadError { caught = e } catch {}
        try expectEqual(caught, LoadError.unsupported("docx"))
    }

    s.test("an empty document is rejected") {
        let url = try write("   \n\n", ext: "txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try expectThrows { _ = try DocumentLoader.load(url: url) }
    }

    s.test("error messages are plain English") {
        try expectEqual(
            LoadError.unsupported("docx").errorDescription,
            "Sprint can't read .docx files yet — try a .md, .txt, or .pdf."
        )
        try expectContains(LoadError.scannedPDF("scan.pdf").errorDescription ?? "", "scanned PDF")
    }

    return s
}
