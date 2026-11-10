import AppKit
import Charts
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
                color: Color(red: 0.86, green: 0.39, blue: 0.25),
                dashboard: URL(string: "https://claude.ai/settings/usage")!,
                scopedWeekly: store.claude?.scopedWeekly ?? [])
            Divider().padding(.leading, 14)
            providerRow(
                usage: store.codex,
                provider: .codex,
                name: "Codex",
                fallbackPlan: "ChatGPT",
                brand: .codex,
                color: .primary,
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
        color: Color,
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
                            .foregroundStyle(color)
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
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 28)
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private var drawdownChart: some View {
        let samples = store.history
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

            Chart(samples) { sample in
                LineMark(
                    x: .value("Time", sample.date),
                    y: .value("Remaining", sample.remainingPercent),
                    series: .value("Provider", sample.providerName))
                    .foregroundStyle(by: .value("Provider", sample.providerName))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.linear)

                if samples.filter({ $0.provider == sample.provider }).count < 3 {
                    PointMark(
                        x: .value("Time", sample.date),
                        y: .value("Remaining", sample.remainingPercent))
                        .foregroundStyle(by: .value("Provider", sample.providerName))
                }
            }
            .chartXScale(domain: start...now)
            .chartYScale(domain: 0...100)
            .chartForegroundStyleScale([
                "Claude": Color(red: 0.86, green: 0.39, blue: 0.25),
                "Codex": Color(red: 0.20, green: 0.67, blue: 0.45),
            ])
            .chartLegend(position: .top, alignment: .leading, spacing: 12)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisGridLine().foregroundStyle(.primary.opacity(0.08))
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { value in
                    AxisGridLine().foregroundStyle(.primary.opacity(0.08))
                    AxisValueLabel {
                        if let percent = value.as(Int.self) {
                            Text("\(percent)%")
                        }
                    }
                }
            }
            .frame(height: 112)
            .overlay {
                if samples.isEmpty {
                    Text("History starts with the next refresh")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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

private struct WindowCell: View {
    let window: UsageWindow?

    var body: some View {
        if let window {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(Int(window.remainingPercent.rounded()))% left")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .monospacedDigit()
                UsageProgress(value: window.remainingPercent / 100)
                    .frame(height: 5)
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
                    .frame(height: 5)
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

    private var tint: Color {
        if value <= 0.2 { return .red }
        if value <= 0.4 { return .orange }
        return Color(red: 0.20, green: 0.67, blue: 0.45)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.12))
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(1, max(0, value)))
            }
        }
        .accessibilityLabel("Usage remaining")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}
