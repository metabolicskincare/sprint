import Foundation

/// The arithmetic behind fitting a word on screen with its pivot letter pinned to
/// the centre line.
///
/// Because the word is shifted so the anchor sits dead centre, the space it needs
/// is set by whichever side of the anchor is longer — a word can run off the right
/// edge even though it would comfortably fit if it were simply centred.
public enum PivotLayout {

    /// How many character cells the word occupies on its wider side of the anchor.
    public static func halfCells(characterCount: Int, pivotIndex: Int) -> Double {
        guard characterCount > 0 else { return 0.5 }
        let pivot = min(max(0, pivotIndex), characterCount - 1)
        let left = Double(pivot) + 0.5
        let right = Double(characterCount - pivot) - 0.5
        return max(left, right)
    }

    /// How much the font has to shrink for the word to fit. 1 means it already does.
    public static func fitScale(halfCells: Double, characterWidth: Double, usableHalfWidth: Double) -> Double {
        guard halfCells > 0, characterWidth > 0, usableHalfWidth > 0 else { return 1 }
        return min(1, usableHalfWidth / (halfCells * characterWidth))
    }
}
