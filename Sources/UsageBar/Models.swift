import Foundation

struct UsageWindow: Codable, Equatable, Sendable {
    let usedPercent: Double
    let resetsAt: Date?

    var remainingPercent: Double {
        min(100, max(0, 100 - usedPercent))
    }
}

struct ScopedUsage: Codable, Equatable, Sendable, Identifiable {
    let name: String
    let window: UsageWindow

    var id: String { name }
}

struct ProviderUsage: Codable, Equatable, Sendable {
    enum Provider: String, Codable, Hashable, Sendable {
        case claude
        case codex
    }

    let provider: Provider
    var plan: String?
    var session: UsageWindow?
    var weekly: UsageWindow?
    var scopedWeekly: [ScopedUsage]?
    var updatedAt: Date
    var message: String?

    var lowestRemaining: Double? {
        [session, weekly].compactMap { $0?.remainingPercent }.min()
    }
}

struct UsageSample: Codable, Identifiable, Sendable {
    let id: UUID
    let provider: ProviderUsage.Provider
    let date: Date
    let remainingPercent: Double

    init(provider: ProviderUsage.Provider, date: Date, remainingPercent: Double) {
        self.id = UUID()
        self.provider = provider
        self.date = date
        self.remainingPercent = remainingPercent
    }

    var providerName: String {
        switch provider {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }
}

enum UsageError: LocalizedError, Sendable {
    case missingCodexLogin
    case invalidCodexCredentials
    case missingClaudeLogin
    case claudeKeychainDenied
    case unauthorized(String)
    case rateLimited(String)
    case badResponse(String)
    case server(String, Int)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingCodexLogin:
            "Codex is not signed in. Run `codex login`."
        case .invalidCodexCredentials:
            "Could not read ~/.codex/auth.json. Run `codex login` again."
        case .missingClaudeLogin:
            "Claude Code is not signed in. Run `claude` once to sign in."
        case .claudeKeychainDenied:
            "Keychain access was denied. Click Refresh to try again."
        case let .unauthorized(provider):
            "\(provider) login expired. Sign in again from its CLI."
        case let .rateLimited(provider):
            "\(provider) is limiting usage checks. Showing the last update."
        case let .badResponse(provider):
            "\(provider) returned usage data this app could not read."
        case let .server(provider, code):
            "\(provider) usage request failed with HTTP \(code)."
        case let .network(message):
            "Could not refresh: \(message)"
        }
    }
}
