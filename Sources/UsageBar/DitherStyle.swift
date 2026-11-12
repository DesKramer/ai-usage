import SwiftUI

enum DitherPalette {
    static let blue = Color(red: 0.20, green: 0.52, blue: 0.95)
    static let claude = Color(red: 0.86, green: 0.39, blue: 0.25)
    static let codex = Color(red: 0.20, green: 0.67, blue: 0.45)
}

enum DitherRenderer {
    private static let bayer4 = [
        [0, 8, 2, 10],
        [12, 4, 14, 6],
        [3, 11, 1, 9],
        [15, 7, 13, 5],
    ]

    static func drawBayer(
        in context: inout GraphicsContext,
        rect: CGRect,
        cellSize: CGFloat = 3,
        color: Color,
        coverage: (CGPoint) -> Double
    ) {
        guard cellSize > 0, !rect.isEmpty else { return }

        let rows = Int(ceil(rect.height / cellSize))
        let columns = Int(ceil(rect.width / cellSize))

        for row in 0..<rows {
            for column in 0..<columns {
                let cell = CGRect(
                    x: rect.minX + CGFloat(column) * cellSize,
                    y: rect.minY + CGFloat(row) * cellSize,
                    width: min(cellSize, rect.maxX - rect.minX - CGFloat(column) * cellSize),
                    height: min(cellSize, rect.maxY - rect.minY - CGFloat(row) * cellSize))
                let sample = CGPoint(x: cell.midX, y: cell.midY)
                let level = min(1, max(0, coverage(sample)))
                let threshold = (Double(bayer4[row % 4][column % 4]) + 0.5) / 16
                guard level >= threshold else { continue }
                context.fill(Path(cell), with: .color(color))
            }
        }
    }
}

struct DitherPattern: View {
    var cellSize: CGFloat = 3
    var coverage: Double = 0.25
    var color = DitherPalette.blue

    var body: some View {
        Canvas { context, size in
            DitherRenderer.drawBayer(
                in: &context,
                rect: CGRect(origin: .zero, size: size),
                cellSize: cellSize,
                color: color,
                coverage: { _ in coverage })
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
