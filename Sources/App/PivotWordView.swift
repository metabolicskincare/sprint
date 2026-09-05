import SwiftUI
import AppKit

/// Draws one word with its pivot letter pinned to the horizontal centre of the view.
///
/// The font is monospaced on purpose: every character is the same width, so the
/// offset that puts the pivot on the anchor is exact arithmetic rather than a
/// text measurement that could wobble by a fraction of a point between words.
///
/// Because the word is shifted to keep the anchor centred, a long one can run off
/// the right edge. Any word that doesn't fit is drawn a little smaller so all of
/// it stays on screen.
struct PivotWordView: View {
    let text: String
    let pivotIndex: Int
    let fontSize: CGFloat
    let availableWidth: CGFloat

    /// Below this the text is too small to read, so an extreme word is allowed to
    /// overflow rather than shrink into nothing.
    private let minimumFontSize: CGFloat = 13

    var body: some View {
        let chars = Array(text)
        let pivot = min(max(0, pivotIndex), max(0, chars.count - 1))

        let nominalFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
        let nominalWidth = characterWidth(of: nominalFont)
        let halfCells = PivotLayout.halfCells(characterCount: chars.count, pivotIndex: pivot)
        let usableHalf = max(1, Double(availableWidth) / 2 - Double(fontSize) * 1.2)
        let scale = PivotLayout.fitScale(
            halfCells: halfCells,
            characterWidth: Double(nominalWidth),
            usableHalfWidth: usableHalf
        )

        let size = max(fontSize * CGFloat(scale), minimumFontSize)
        let font = NSFont.monospacedSystemFont(ofSize: size, weight: .medium)
        let charWidth = characterWidth(of: font)

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

    private func characterWidth(of font: NSFont) -> CGFloat {
        ("0" as NSString).size(withAttributes: [.font: font]).width
    }
}
