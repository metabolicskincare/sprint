import SwiftUI

struct ReaderView: View {
    @EnvironmentObject private var engine: ReaderEngine

    var body: some View {
        GeometryReader { geo in
            let fontSize = max(30, min(76, geo.size.width * 0.062))
            let gap = fontSize * 0.55

            ZStack {
                // Guide ticks above and below the anchor, so the eye has a fixed
                // point to rest on even between words.
                VStack(spacing: 0) {
                    Rectangle().fill(Theme.guideLine).frame(width: 1, height: gap)
                    Spacer().frame(height: fontSize * 1.9)
                    Rectangle().fill(Theme.guideLine).frame(width: 1, height: gap)
                }

                if let chunk = engine.current {
                    PivotWordView(text: chunk.text, pivotIndex: chunk.pivotIndex, fontSize: fontSize)
                }

                if engine.isFinished {
                    VStack {
                        Spacer()
                        Text("End of \(engine.documentTitle)")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.dim)
                            .padding(.bottom, gap * 2)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
