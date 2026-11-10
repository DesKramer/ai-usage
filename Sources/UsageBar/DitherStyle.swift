import SwiftUI

enum DitherPalette {
    static let blue = Color(red: 0.20, green: 0.52, blue: 0.95)
    static let claude = Color(red: 0.86, green: 0.39, blue: 0.25)
    static let codex = Color(red: 0.20, green: 0.67, blue: 0.45)
}

enum DitherRenderer {
    static func draw(
        in context: inout GraphicsContext,
        rect: CGRect,
        spacing: CGFloat,
        dotSize: CGFloat,
        opacity: Double,
        phase: Int = 0,
        color: Color = DitherPalette.blue
    ) {
        guard spacing > 0, dotSize > 0, !rect.isEmpty else { return }

        let rowCount = Int(ceil(rect.height / spacing)) + 1
        let columnCount = Int(ceil(rect.width / spacing)) + 1
        let dotColor = color.opacity(opacity)

        for row in 0...rowCount {
            let offset = (row + phase).isMultiple(of: 2) ? 0 : spacing / 2
            let y = rect.minY + CGFloat(row) * spacing
            for column in 0...columnCount {
                let x = rect.minX + CGFloat(column) * spacing + offset
                let dot = CGRect(
                    x: x - dotSize / 2,
                    y: y - dotSize / 2,
                    width: dotSize,
                    height: dotSize)
                context.fill(Path(ellipseIn: dot), with: .color(dotColor))
            }
        }
    }

    static func drawCheckerboard(
        in context: inout GraphicsContext,
        rect: CGRect,
        cellSize: CGFloat,
        opacity: Double,
        phase: Int = 0,
        color: Color
    ) {
        guard cellSize > 0, !rect.isEmpty else { return }

        let rowCount = Int(ceil(rect.height / cellSize))
        let columnCount = Int(ceil(rect.width / cellSize))
        let squareColor = color.opacity(opacity)

        for row in 0...rowCount {
            for column in 0...columnCount where (row + column + phase).isMultiple(of: 2) {
                let square = CGRect(
                    x: rect.minX + CGFloat(column) * cellSize,
                    y: rect.minY + CGFloat(row) * cellSize,
                    width: cellSize,
                    height: cellSize)
                context.fill(Path(square), with: .color(squareColor))
            }
        }
    }
}

struct DitherPattern: View {
    var spacing: CGFloat = 4.5
    var dotSize: CGFloat = 1
    var opacity: Double = 0.08
    var phase = 0
    var color = DitherPalette.blue

    var body: some View {
        Canvas { context, size in
            DitherRenderer.draw(
                in: &context,
                rect: CGRect(origin: .zero, size: size),
                spacing: spacing,
                dotSize: dotSize,
                opacity: opacity,
                phase: phase,
                color: color)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct DitherDivider: View {
    var body: some View {
        Canvas { context, size in
            let y = size.height / 2
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(
                path,
                with: .color(DitherPalette.blue.opacity(0.28)),
                style: StrokeStyle(lineWidth: 1, dash: [1, 2]))
        }
        .frame(height: 3)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
