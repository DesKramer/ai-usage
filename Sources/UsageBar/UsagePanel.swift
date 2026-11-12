import AppKit
import SwiftUI

struct UsagePanel: View {
    @EnvironmentObject private var store: UsageStore

    private let nameWidth: CGFloat = 122
    private let windowWidth: CGFloat = 118

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            providerRow(
                usage: store.claude,
                provider: .claude,
                name: "Claude",
                fallbackPlan: "Claude Code",
                brand: .claude,
                dashboard: URL(string: "https://claude.ai/settings/usage")!,
                scopedWeekly: store.claude?.scopedWeekly ?? [])
            Divider().padding(.leading, 14)
            providerRow(
                usage: store.codex,
                provider: .codex,
                name: "Codex",
                fallbackPlan: "ChatGPT",
                brand: .codex,
                dashboard: URL(string: "https://chatgpt.com/settings/usage?tab=overview")!)
            Divider()
            drawdownChart
            Divider()
            footer
        }
        .frame(width: 410)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Usage left")
                .font(.headline)
                .frame(width: nameWidth, alignment: .leading)
            Text("5 hours")
                .frame(width: windowWidth, alignment: .leading)
            Text("Week")
                .frame(width: windowWidth, alignment: .leading)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func providerRow(
        usage: ProviderUsage?,
        provider: ProviderUsage.Provider,
        name: String,
        fallbackPlan: String,
        brand: BrandIcon.Brand,
        dashboard: URL,
        scopedWeekly: [ScopedUsage] = []
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    NSWorkspace.shared.open(dashboard)
                } label: {
                    HStack(alignment: .top, spacing: 9) {
                        BrandIcon(brand: brand)
                            .foregroundStyle(.primary)
                            .frame(width: 19, height: 19)
                            .frame(height: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(usage?.plan ?? fallbackPlan)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .contentShape(Rectangle())
                    .frame(width: nameWidth, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help("Open \(name) usage")

                WindowCell(window: usage?.session)
                    .frame(width: windowWidth, alignment: .leading)
                WindowCell(window: usage?.weekly)
                    .frame(width: windowWidth, alignment: .leading)
            }

            ForEach(scopedWeekly) { scoped in
                HStack(alignment: .top, spacing: 12) {
                    Text(scoped.name)
                        .font(.subheadline.weight(.medium))
                        .frame(width: nameWidth, alignment: .leading)
                    Color.clear
                        .frame(width: windowWidth, height: 1)
                    WindowCell(window: scoped.window)
                        .frame(width: windowWidth, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(scoped.name) weekly usage")
            }

            if let message = usage?.message ?? store.errors[provider] {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 28)
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private var drawdownChart: some View {
        let now = Date()
        let start = now.addingTimeInterval(-12 * 60 * 60)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("12-hour drawdown")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("5-hour allowance remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                DitherLegendItem(
                    name: "Claude",
                    dashed: false,
                    color: DitherPalette.claude)
                DitherLegendItem(
                    name: "Codex",
                    dashed: true,
                    color: DitherPalette.codex)
            }

            DitherDrawdownChart(samples: store.history, start: start, end: now)
                .frame(height: 112)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            HStack {
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                    Text("Refreshing")
                } else if let date = store.latestUpdate {
                    Image(systemName: "clock")
                    Text("Updated \(relativeDate(date))")
                } else {
                    Image(systemName: "clock")
                    Text("Not updated yet")
                }
                Spacer()
                Button {
                    store.refreshFromButton()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRefreshing)
                .keyboardShortcut("r", modifiers: .command)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().padding(.leading, 14)

            HStack {
                Toggle("Open at Login", isOn: Binding(
                    get: { store.launchAtLogin },
                    set: { store.setLaunchAtLogin($0) }))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let seconds = max(0, Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = Int(seconds / 3600)
        if hours < 24 { return "\(hours) hr ago" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct DitherLegendItem: View {
    let name: String
    let dashed: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.primary.opacity(0.04))
                DitherPattern(cellSize: 2, coverage: 0.625, color: color)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: size.height / 2))
                    path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    context.stroke(
                        path,
                        with: .color(color.opacity(0.82)),
                        style: StrokeStyle(lineWidth: 1, dash: dashed ? [3, 2] : []))
                }
            }
            .frame(width: 18, height: 8)

            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DitherDrawdownChart: View {
    let samples: [UsageSample]
    let start: Date
    let end: Date

    var body: some View {
        ZStack {
            Canvas { context, size in
                let plot = CGRect(
                    x: 34,
                    y: 3,
                    width: max(0, size.width - 38),
                    height: max(0, size.height - 22))

                drawGrid(in: &context, plot: plot)
                drawSeries(.claude, in: &context, plot: plot)
                drawSeries(.codex, in: &context, plot: plot)
            }

            if samples.isEmpty {
                Text("History starts with the next refresh")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("12-hour usage drawdown chart")
    }

    private func drawGrid(in context: inout GraphicsContext, plot: CGRect) {
        for percent in [0, 50, 100] {
            let y = plot.maxY - plot.height * CGFloat(percent) / 100
            var line = Path()
            line.move(to: CGPoint(x: plot.minX, y: y))
            line.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(
                line,
                with: .color(.primary.opacity(0.14)),
                style: StrokeStyle(lineWidth: 0.7, dash: [1, 3]))
            context.draw(
                Text("\(percent)%")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary),
                at: CGPoint(x: plot.minX - 5, y: y),
                anchor: .trailing)
        }

        let duration = end.timeIntervalSince(start)
        for tick in 0...3 {
            let fraction = CGFloat(tick) / 3
            let x = plot.minX + plot.width * fraction
            let date = start.addingTimeInterval(duration * Double(fraction))
            context.draw(
                Text(date.formatted(.dateTime.hour()))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary),
                at: CGPoint(x: x, y: plot.maxY + 6),
                anchor: .top)
        }
    }

    private func drawSeries(
        _ provider: ProviderUsage.Provider,
        in context: inout GraphicsContext,
        plot: CGRect
    ) {
        let points = samples
            .filter { $0.provider == provider }
            .sorted { $0.date < $1.date }
            .map { point(for: $0, in: plot) }

        guard let first = points.first else { return }
        let color = provider == .claude ? DitherPalette.claude : DitherPalette.codex

        if points.count == 1 {
            let dot = CGRect(x: first.x - 2, y: first.y - 2, width: 4, height: 4)
            context.fill(Path(ellipseIn: dot), with: .color(color.opacity(0.82)))
            return
        }

        var line = Path()
        line.move(to: first)
        for point in points.dropFirst() {
            line.addLine(to: point)
        }

        let fillRect = CGRect(
            x: first.x,
            y: plot.minY,
            width: max(0, (points.last?.x ?? first.x) - first.x),
            height: plot.height)
        DitherRenderer.drawBayer(
            in: &context,
            rect: fillRect,
            cellSize: 3,
            color: color,
            coverage: { sample in
                guard let lineY = lineY(at: sample.x, through: points),
                      sample.y >= lineY,
                      sample.y <= plot.maxY
                else { return 0 }

                let depth = (sample.y - lineY) / max(1, plot.maxY - lineY)
                return 0.72 * pow(1 - Double(depth), 0.72)
            })

        context.stroke(
            line,
            with: .color(color.opacity(provider == .claude ? 0.88 : 0.78)),
            style: StrokeStyle(
                lineWidth: 1.5,
                lineCap: .round,
                lineJoin: .round,
                dash: provider == .claude ? [] : [4, 3]))
    }

    private func lineY(at x: CGFloat, through points: [CGPoint]) -> CGFloat? {
        guard let first = points.first, let last = points.last,
              x >= first.x, x <= last.x
        else { return nil }

        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            guard x <= end.x else { continue }
            let width = end.x - start.x
            guard width > 0 else { return end.y }
            let fraction = (x - start.x) / width
            return start.y + (end.y - start.y) * fraction
        }
        return last.y
    }

    private func point(for sample: UsageSample, in plot: CGRect) -> CGPoint {
        let duration = max(1, end.timeIntervalSince(start))
        let elapsed = sample.date.timeIntervalSince(start)
        let xFraction = min(1, max(0, elapsed / duration))
        let yFraction = min(1, max(0, sample.remainingPercent / 100))
        return CGPoint(
            x: plot.minX + plot.width * CGFloat(xFraction),
            y: plot.maxY - plot.height * CGFloat(yFraction))
    }
}

private struct WindowCell: View {
    let window: UsageWindow?

    var body: some View {
        if let window {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(Int(window.remainingPercent.rounded()))% left")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .monospacedDigit()
                UsageProgress(value: window.remainingPercent / 100)
                    .frame(height: 6)
                Text(resetText(window.resetsAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("--")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                UsageProgress(value: 0)
                    .frame(height: 6)
                Text("unavailable")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func resetText(_ date: Date?) -> String {
        guard let date else { return "reset unknown" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "resets \(date.formatted(date: .omitted, time: .shortened))"
        }
        if calendar.isDateInTomorrow(date) {
            return "resets tomorrow \(date.formatted(date: .omitted, time: .shortened))"
        }
        return "resets \(date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))"
    }
}

private struct UsageProgress: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * min(1, max(0, value))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(DitherPalette.blue.opacity(0.1))
                Canvas { context, size in
                    let fillRect = CGRect(x: 0, y: 0, width: width, height: size.height)
                    DitherRenderer.drawBayer(
                        in: &context,
                        rect: fillRect,
                        cellSize: 3,
                        color: DitherPalette.blue,
                        coverage: { sample in
                            guard width > 0 else { return 0 }
                            let position = min(1, max(0, sample.x / width))
                            return 0.12 + 0.88 * pow(Double(position), 1.35)
                        })

                    if width > 0 {
                        let cap = CGRect(
                            x: max(0, width - 3),
                            y: 0,
                            width: min(3, width),
                            height: size.height)
                        context.fill(Path(cap), with: .color(DitherPalette.blue))
                    }
                }
                RoundedRectangle(cornerRadius: 1)
                    .stroke(DitherPalette.blue.opacity(0.26), lineWidth: 0.5)
            }
        }
        .animation(.easeOut(duration: 0.6), value: value)
        .accessibilityLabel("Usage remaining")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}
