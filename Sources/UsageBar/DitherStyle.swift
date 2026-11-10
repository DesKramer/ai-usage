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

    static func drawHorizontalGradient(
        in context: inout GraphicsContext,
        rect: CGRect,
        spacing: CGFloat,
        dotSize: CGFloat,
        maxDensity: Double,
        opacity: Double,
        phase: Int = 0,
        color: Color = DitherPalette.blue
    ) {
        guard spacing > 0, dotSize > 0, !rect.isEmpty else { return }

        let bayer4 = [
            0, 8, 2, 10,
            12, 4, 14, 6,
            3, 11, 1, 9,
            15, 7, 13, 5,
        ]
        let rowCount = Int(ceil(rect.height / spacing)) + 1
        let columnCount = Int(ceil(rect.width / spacing)) + 1
        let dotColor = color.opacity(opacity)
        let densityCeiling = min(1, max(0, maxDensity))

        for row in 0...rowCount {
            let offset = (row + phase).isMultiple(of: 2) ? 0 : spacing / 2
            let y = rect.minY + CGFloat(row) * spacing

            for column in 0...columnCount {
                let x = rect.minX + CGFloat(column) * spacing + offset
                let progress = min(1, max(0, Double((x - rect.minX) / rect.width)))
                let density = densityCeiling * (0.06 + 0.94 * pow(progress, 3.2))
                let patternColumn = (column + phase) & 3
                let patternRow = (row + phase * 2) & 3
                let threshold = (Double(bayer4[patternRow * 4 + patternColumn]) + 0.5) / 16
                guard threshold < density else { continue }

                let dot = CGRect(
                    x: x - dotSize / 2,
                    y: y - dotSize / 2,
                    width: dotSize,
                    height: dotSize)
                context.fill(Path(ellipseIn: dot), with: .color(dotColor))
            }
        }
    }

    static func drawAreaGradient(
        in context: inout GraphicsContext,
        rect: CGRect,
        points: [CGPoint],
        cellSize: CGFloat,
        maxDensity: Double,
        opacity: Double,
        phase: Int = 0,
        color: Color
    ) {
        guard cellSize > 0, !rect.isEmpty, points.count > 1 else { return }

        // Ordered dithering keeps the fade stable between redraws. Density is measured
        // from the series line to the bottom of the plot for each column, so short and
        // tall parts of the graph get the same proportional fade.
        let bayer4 = [
            0, 8, 2, 10,
            12, 4, 14, 6,
            3, 11, 1, 9,
            15, 7, 13, 5,
        ]
        let rowCount = Int(ceil(rect.height / cellSize))
        let columnCount = Int(ceil(rect.width / cellSize))
        let squareColor = color.opacity(opacity)
        let densityCeiling = min(1, max(0, maxDensity))
        var segment = 0

        for column in 0..<columnCount {
            let squareX = rect.minX + CGFloat(column) * cellSize
            let sampleX = squareX + cellSize / 2
            guard sampleX >= points[0].x, sampleX <= points[points.count - 1].x else {
                continue
            }

            while segment < points.count - 2, sampleX > points[segment + 1].x {
                segment += 1
            }

            let leading = points[segment]
            let trailing = points[segment + 1]
            let segmentWidth = trailing.x - leading.x
            let fraction = segmentWidth > 0
                ? min(1, max(0, (sampleX - leading.x) / segmentWidth))
                : 1
            let lineY = min(
                rect.maxY,
                max(rect.minY, leading.y + (trailing.y - leading.y) * fraction))
            let fillHeight = rect.maxY - lineY
            guard fillHeight > 0 else { continue }

            for row in 0..<rowCount {
                let squareY = rect.minY + CGFloat(row) * cellSize
                let sampleY = squareY + cellSize / 2
                guard sampleY >= lineY, sampleY <= rect.maxY else { continue }

                let depth = min(1, max(0, Double((sampleY - lineY) / fillHeight)))
                let density = densityCeiling * pow(1 - depth, 4.5)
                let patternColumn = (column + phase) & 3
                let patternRow = (row + phase * 2) & 3
                let threshold = (Double(bayer4[patternRow * 4 + patternColumn]) + 0.5) / 16
                guard threshold < density else { continue }

                let square = CGRect(
                    x: squareX,
                    y: squareY,
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

struct HorizontalDitherGradient: View {
    var spacing: CGFloat = 2.5
    var dotSize: CGFloat = 1.1
    var maxDensity: Double = 1
    var opacity: Double = 0.72
    var phase = 0
    var color = DitherPalette.blue

    var body: some View {
        Canvas { context, size in
            DitherRenderer.drawHorizontalGradient(
                in: &context,
                rect: CGRect(origin: .zero, size: size),
                spacing: spacing,
                dotSize: dotSize,
                maxDensity: maxDensity,
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
