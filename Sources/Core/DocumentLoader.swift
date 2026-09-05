import Foundation
import PDFKit

public struct Document: Equatable, Sendable {
    public let title: String
    public let text: String
    public init(title: String, text: String) {
        self.title = title
        self.text = text
    }
}

public enum LoadError: LocalizedError, Equatable {
    case unsupported(String)
    case unreadable(String)
    case emptyDocument(String)
    case scannedPDF(String)

    public var errorDescription: String? {
        switch self {
        case .unsupported(let ext):
            return "Sprint can't read \(ext.isEmpty ? "that kind of file" : ".\(ext) files") yet — try a .md, .txt, or .pdf."
        case .unreadable(let name):
            return "Couldn't open \(name). The file may be damaged or in an unexpected encoding."
        case .emptyDocument(let name):
            return "\(name) doesn't have any words in it."
        case .scannedPDF(let name):
            return "\(name) is a scanned PDF — it's images of pages, with no text to read."
        }
    }
}

public enum DocumentLoader {

    public static let supportedExtensions = ["md", "markdown", "txt", "text", "pdf"]

    public static func load(url: URL) throws -> Document {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()

        let text: String
        switch ext {
        case "pdf":
            text = try loadPDF(url: url, name: name)
        case "md", "markdown":
            text = stripMarkdown(try loadPlainText(url: url, name: name))
        case "txt", "text", "":
            text = try loadPlainText(url: url, name: name)
        default:
            throw LoadError.unsupported(ext)
        }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw LoadError.emptyDocument(name) }
        return Document(title: name, text: cleaned)
    }

    // MARK: - Plain text

    static func loadPlainText(url: URL, name: String) throws -> String {
        guard let data = try? Data(contentsOf: url) else { throw LoadError.unreadable(name) }
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        throw LoadError.unreadable(name)
    }

    // MARK: - PDF

    static func loadPDF(url: URL, name: String) throws -> String {
        guard let doc = PDFDocument(url: url) else { throw LoadError.unreadable(name) }
        var pages: [String] = []
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let s = page.string { pages.append(s) }
        }
        let raw = pages.joined(separator: "\n\n")
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LoadError.scannedPDF(name)
        }
        return reflow(raw)
    }

    /// PDFs carry hard line breaks from the page layout. Rejoin words split across a
    /// line by a hyphen, then fold single line breaks back into flowing prose while
    /// keeping blank lines as real paragraph breaks.
    static func reflow(_ text: String) -> String {
        var s = text.replacingOccurrences(of: "\r\n", with: "\n")
        s = s.replacingOccurrences(of: "-\n", with: "")
        s = replacing(in: s, pattern: "\n{2,}", with: "\u{0}PARA\u{0}")
        s = s.replacingOccurrences(of: "\n", with: " ")
        s = s.replacingOccurrences(of: "\u{0}PARA\u{0}", with: "\n\n")
        return replacing(in: s, pattern: "[ \t]{2,}", with: " ")
    }

    // MARK: - Markdown

    /// Reduces Markdown to the prose inside it. Code blocks are dropped entirely —
    /// reading source code one word at a time is no use to anyone.
    public static func stripMarkdown(_ markdown: String) -> String {
        var s = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        s = expandWikiLinks(s)
        s = replacing(in: s, pattern: "(?ms)^[ \t]*(```|~~~).*?^[ \t]*\\1[ \t]*$", with: "")
        s = replacing(in: s, pattern: "(?m)^[ \t]{0,3}#{1,6}[ \t]+", with: "")
        s = replacing(in: s, pattern: "(?m)^[ \t]{0,3}>[ \t]?", with: "")
        s = replacing(in: s, pattern: "(?m)^[ \t]{0,3}([-*_])([ \t]*\\1){2,}[ \t]*$", with: "")
        s = replacing(in: s, pattern: "(?m)^[ \t]*[-*+][ \t]+", with: "")
        s = replacing(in: s, pattern: "(?m)^[ \t]*\\d+[.)][ \t]+", with: "")
        s = replacing(in: s, pattern: "!\\[[^\\]]*\\]\\([^)]*\\)", with: "")          // images
        s = replacing(in: s, pattern: "\\[([^\\]]*)\\]\\([^)]*\\)", with: "$1")       // links keep their text
        s = replacing(in: s, pattern: "(?m)^\\|.*\\|[ \t]*$", with: "")               // tables
        s = replacing(in: s, pattern: "`+([^`\n]*)`+", with: "$1")
        s = replacing(in: s, pattern: "(\\*\\*|__)(.+?)\\1", with: "$2")
        s = replacing(in: s, pattern: "(?<![\\w*])[*_](?=\\S)(.+?)(?<=\\S)[*_](?![\\w*])", with: "$1")
        s = replacing(in: s, pattern: "<[^>\n]+>", with: "")
        s = replacing(in: s, pattern: "\n{3,}", with: "\n\n")
        return s
    }

    /// Obsidian-style `[[wiki links]]`. The folders and hyphens in a link are
    /// addressing, not prose, so `[[Personal/Direction/one-page-direction]]` reads
    /// as "one page direction" rather than arriving as one 40-character word.
    public static func expandWikiLinks(_ s: String) -> String {
        guard let re = try? NSRegularExpression(pattern: "\\[\\[([^\\]]+)\\]\\]") else { return s }
        let ns = s as NSString
        var result = ""
        var consumed = 0

        for match in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: consumed, length: match.range.location - consumed))
            var inner = ns.substring(with: match.range(at: 1))

            if let bar = inner.lastIndex(of: "|") {
                // [[target|what to display]] — the author already wrote the readable half.
                inner = String(inner[inner.index(after: bar)...])
            } else {
                if let hash = inner.firstIndex(of: "#") { inner = String(inner[..<hash]) }
                inner = inner.split(separator: "/").last.map(String.init) ?? inner
                inner = inner
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " ")
            }

            result += inner.trimmingCharacters(in: .whitespaces)
            consumed = match.range.location + match.range.length
        }

        result += ns.substring(from: consumed)
        return result
    }

    static func replacing(in s: String, pattern: String, with template: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return s }
        return re.stringByReplacingMatches(
            in: s,
            range: NSRange(s.startIndex..., in: s),
            withTemplate: template
        )
    }
}
