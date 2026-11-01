import Combine
import Foundation
import ServiceManagement

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var claude: ProviderUsage?
    @Published private(set) var codex: ProviderUsage?
    @Published private(set) var errors: [ProviderUsage.Provider: String] = [:]
    @Published private(set) var history: [UsageSample] = []
    @Published private(set) var isRefreshing = false
    @Published var launchAtLogin = false

    nonisolated static let refreshInterval: TimeInterval = 5 * 60

    private var timer: Timer?
    private var hasStarted = false

    init() {
        loadCache()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    var claudeMenuBarValue: String {
        compactPercent(claude?.lowestRemaining)
    }

    var codexMenuBarValue: String {
        compactPercent(codex?.lowestRemaining)
    }

    var latestUpdate: Date? {
        [claude?.updatedAt, codex?.updatedAt].compactMap { $0 }.max()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        Task { await refresh(forceCredentialReload: false) }
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh(forceCredentialReload: false)
            }
        }
    }

    func refreshFromButton() {
        Task { await refresh(forceCredentialReload: true) }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            errors[.codex] = "Could not change Open at Login: \(error.localizedDescription)"
        }
    }

    private func refresh(forceCredentialReload: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let codexTask = Task.detached(priority: .userInitiated) {
            await Self.outcome(for: .codex) {
                try await CodexUsageClient().fetch()
            }
        }
        let claudeTask = Task.detached(priority: .userInitiated) {
            await Self.outcome(for: .claude) {
                try await ClaudeUsageClient().fetch(forceCredentialReload: forceCredentialReload)
            }
        }

        apply(await codexTask.value)
        apply(await claudeTask.value)
        saveCache()
    }

    private nonisolated static func outcome(
        for provider: ProviderUsage.Provider,
        operation: @Sendable () async throws -> ProviderUsage
    ) async -> FetchOutcome {
        do {
            return FetchOutcome(provider: provider, usage: try await operation(), error: nil)
        } catch {
            return FetchOutcome(
                provider: provider,
                usage: nil,
                error: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func apply(_ outcome: FetchOutcome) {
        if let fresh = outcome.usage {
            errors[outcome.provider] = nil
            switch outcome.provider {
            case .claude: claude = fresh
            case .codex: codex = fresh
            }
            recordSample(from: fresh)
            return
        }

        let message = outcome.error ?? "Usage is unavailable."
        errors[outcome.provider] = message
        switch outcome.provider {
        case .claude:
            if claude != nil { claude?.message = message }
        case .codex:
            if codex != nil { codex?.message = message }
        }
    }

    private func compactPercent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    private func recordSample(from usage: ProviderUsage) {
        guard let remaining = usage.session?.remainingPercent else { return }
        let mostRecent = history.last { $0.provider == usage.provider }
        if let mostRecent, usage.updatedAt.timeIntervalSince(mostRecent.date) < 30 { return }
        history.append(UsageSample(
            provider: usage.provider,
            date: usage.updatedAt,
            remainingPercent: remaining))
        pruneHistory()
    }

    private func pruneHistory() {
        let cutoff = Date().addingTimeInterval(-12 * 60 * 60)
        history.removeAll { $0.date < cutoff }
    }

    private struct Cache: Codable {
        let claude: ProviderUsage?
        let codex: ProviderUsage?
        let history: [UsageSample]?
    }

    private struct FetchOutcome: Sendable {
        let provider: ProviderUsage.Provider
        let usage: ProviderUsage?
        let error: String?
    }

    private var cacheURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("UsageBar", isDirectory: true)
            .appendingPathComponent("usage.json")
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(Cache.self, from: data)
        else { return }
        claude = cache.claude
        codex = cache.codex
        history = cache.history ?? []
        pruneHistory()
    }

    private func saveCache() {
        let cache = Cache(
            claude: claude.map(Self.withoutMessage),
            codex: codex.map(Self.withoutMessage),
            history: history)
        guard let data = try? JSONEncoder().encode(cache) else { return }
        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            // A cache failure should not hide fresh usage data.
        }
    }

    private nonisolated static func withoutMessage(_ usage: ProviderUsage) -> ProviderUsage {
        var copy = usage
        copy.message = nil
        return copy
    }
}
