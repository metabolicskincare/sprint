import Foundation

func layoutSuite() -> Suite {
    let s = Suite("Fitting words on screen")

    s.test("space needed is set by the wider side of the anchor") {
        // "reading", anchor on the third letter: 2.5 cells left, 4.5 right.
        try expectClose(PivotLayout.halfCells(characterCount: 7, pivotIndex: 2), 4.5, tolerance: 0.0001)
        // A long word with an early anchor is dominated by its right-hand side.
        try expectClose(PivotLayout.halfCells(characterCount: 73, pivotIndex: 5), 67.5, tolerance: 0.0001)
    }

    s.test("a word that already fits is not shrunk") {
        let half = PivotLayout.halfCells(characterCount: 7, pivotIndex: 2)
        try expectClose(
            PivotLayout.fitScale(halfCells: half, characterWidth: 30, usableHalfWidth: 400),
            1.0, tolerance: 0.0001)
    }

    s.test("an over-wide word is shrunk exactly enough to fit") {
        let half = PivotLayout.halfCells(characterCount: 40, pivotIndex: 3)
        let scale = PivotLayout.fitScale(halfCells: half, characterWidth: 30, usableHalfWidth: 400)
        try expect(scale < 1, "expected a shrink, got \(scale)")
        try expectClose(half * 30 * scale, 400, tolerance: 0.0001, "should exactly fill the space")
    }

    s.test("degenerate inputs don't shrink anything") {
        try expectEqual(PivotLayout.fitScale(halfCells: 0, characterWidth: 30, usableHalfWidth: 400), 1.0)
        try expectEqual(PivotLayout.fitScale(halfCells: 5, characterWidth: 0, usableHalfWidth: 400), 1.0)
        try expectEqual(PivotLayout.fitScale(halfCells: 5, characterWidth: 30, usableHalfWidth: 0), 1.0)
        try expectClose(PivotLayout.halfCells(characterCount: 0, pivotIndex: 0), 0.5, tolerance: 0.0001)
    }

    return s
}
