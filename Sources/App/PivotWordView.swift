import SwiftUI
import AppKit

/// Draws one word with its pivot letter pinned to the horizontal centre of the view.
///
/// The font is monospaced on purpose: every character is the same width, so the
/// offset that puts the pivot on the anchor is exact arithmetic rather than a
/// text measurement that could wobble by a fraction of a point between words.
struct PivotWordView: View {
    let text: String
    let pivotIndex: Int
    let fontSize: CGFloat

    var body: some View {
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
        let charWidth = ("0" as NSString).size(withAttributes: [.font: font]).width
        let chars = Array(text)
        let pivot = min(max(0, pivotIndex), max(0, chars.count - 1))

        let prefix = chars.isEmpty ? "" : String(chars[0..<pivot])
        let anchor = chars.isEmpty ? " " : String(chars[pivot])
        let suffix = chars.count > pivot + 1 ? String(chars[(pivot + 1)...]) : ""

        // Shift the whole word so the centre of the pivot glyph sits on the view's centre.
        let dx = CGFloat(chars.count) * charWidth / 2 - (CGFloat(pivot) + 0.5) * charWidth

        HStack(spacing: 0) {
            Text(prefix).foregroundStyle(Theme.word)
            Text(anchor).foregroundStyle(Theme.pivot)
            Text(suffix).foregroundStyle(Theme.word)
        }
        .font(Font(font))
        .tracking(0)
        .fixedSize()
        .offset(x: dx)
    }
}
