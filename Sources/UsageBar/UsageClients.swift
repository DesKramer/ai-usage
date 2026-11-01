import Foundation

struct CodexUsageClient: Sendable {
    private struct AuthFile: Decodable {
        let tokens: Tokens?

        struct Tokens: Decodable {
            let accessToken: String?
            let accountID: String?

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case accountID = "account_id"
            }
        }
    }

    private struct Response: Decodable {
        let planType: String?
        let rateLimit: RateLimit?

        enum CodingKeys: String, CodingKey {
            case planType = "plan_type"
            case rateLimit = "rate_limit"
        }

        struct RateLimit: Decodable {
            let primary: Window?
            let secondary: Window?

            enum CodingKeys: String, CodingKey {
                case primary = "primary_window"
                case secondary = "secondary_window"
            }
        }

        struct Window: Decodable {
            let usedPercent: Double
            let resetAt: Double?

            enum CodingKeys: String, CodingKey {
                case usedPercent = "used_percent"
                case resetAt = "reset_at"
            }

            var model: UsageWindow {
                UsageWindow(
                    usedPercent: usedPercent,
                    resetsAt: resetAt.map(Date.init(timeIntervalSince1970:)))
            }
        }
    }

    func fetch() async throws -> ProviderUsage {
        let credentials = try readCredentials()
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("UsageBar/1.0", forHTTPHeaderField: "User-Agent")
        if let accountID = credentials.accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UsageError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw UsageError.badResponse("Codex")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw UsageError.unauthorized("Codex")
        }
        if http.statusCode == 429 {
            throw UsageError.rateLimited("Codex")
        }
        guard http.statusCode == 200 else {
            throw UsageError.server("Codex", http.statusCode)
        }
        guard let payload = try? JSONDecoder().decode(Response.self, from: data) else {
            throw UsageError.badResponse("Codex")
        }

        return ProviderUsage(
            provider: .codex,
            plan: payload.planType.map(Self.displayPlan),
            session: payload.rateLimit?.primary?.model,
            weekly: payload.rateLimit?.secondary?.model,
            updatedAt: Date(),
            message: nil)
    }

    private func readCredentials() throws -> (token: String, accountID: String?) {
        let environment = ProcessInfo.processInfo.environment
        let home: URL
        if let configured = environment["CODEX_HOME"], !configured.isEmpty {
            home = URL(fileURLWithPath: NSString(string: configured).expandingTildeInPath)
        } else {
            home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        }
        let url = home.appendingPathComponent("auth.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw UsageError.missingCodexLogin
        }
        guard let data = try? Data(contentsOf: url),
              let auth = try? JSONDecoder().decode(AuthFile.self, from: data),
              let token = auth.tokens?.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty
        else {
            throw UsageError.invalidCodexCredentials
        }
        return (token, auth.tokens?.accountID)
    }

    private static func displayPlan(_ raw: String) -> String {
        switch raw.lowercased() {
        case "plus": "ChatGPT Plus"
        case "pro": "ChatGPT Pro"
        case "team": "ChatGPT Team"
        case "business": "ChatGPT Business"
        case "enterprise": "ChatGPT Enterprise"
        case "free": "ChatGPT Free"
        default: raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

struct ClaudeUsageClient: Sendable {
    private struct Credentials: Decodable {
        let claudeAiOauth: OAuth?

        struct OAuth: Decodable {
            let accessToken: String?
            let expiresAt: Double?
            let subscriptionType: String?
        }
    }

    struct StoredCredentials: Sendable, Equatable {
        let token: String
        let subscription: String?
        let expiresAt: Date?

        var isFresh: Bool {
            guard let expiresAt else { return true }
            return expiresAt.timeIntervalSinceNow > 60
        }
    }

    /// Holds the last token read from Keychain so routine refreshes don't touch Keychain at
    /// all. Claude Code rewrites its Keychain item each time it refreshes the token, so the
    /// item is re-read only when the cached token is near expiry or the API rejects it.
    private actor CredentialCache {
        static let shared = CredentialCache()

        private var credentials: StoredCredentials?
        private var keychainDenied = false

        func load(forceReload: Bool) throws -> StoredCredentials {
            if !forceReload, let credentials, credentials.isFresh {
                return credentials
            }
            // After a denial, wait for the user to press Refresh rather than asking again
            // from the background timer.
            if keychainDenied, !forceReload {
                throw UsageError.claudeKeychainDenied
            }
            do {
                let fresh = try ClaudeUsageClient.readKeychain()
                credentials = fresh
                keychainDenied = false
                return fresh
            } catch UsageError.claudeKeychainDenied {
                keychainDenied = true
                throw UsageError.claudeKeychainDenied
            }
        }

        func invalidate(_ rejected: StoredCredentials) {
            if credentials == rejected { credentials = nil }
        }
    }

    private struct Response: Decodable {
        let fiveHour: Window?
        let sevenDay: Window?

        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
        }

        struct Window: Decodable {
            let utilization: Double
            let resetsAt: String?

            enum CodingKeys: String, CodingKey {
                case utilization
                case resetsAt = "resets_at"
            }

            var model: UsageWindow {
                UsageWindow(
                    usedPercent: utilization,
                    resetsAt: resetsAt.flatMap(Self.parseDate))
            }

            private static func parseDate(_ value: String) -> Date? {
                let fractional = ISO8601DateFormatter()
                fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
            }
        }
    }

    func fetch(forceCredentialReload: Bool) async throws -> ProviderUsage {
        let cache = CredentialCache.shared
        let credentials = try await cache.load(forceReload: forceCredentialReload)
        do {
            return try await fetch(with: credentials)
        } catch UsageError.unauthorized {
            // Claude Code may have refreshed the token since it was cached. Retry once with
            // whatever is in Keychain now.
            await cache.invalidate(credentials)
            let reloaded = try await cache.load(forceReload: false)
            guard reloaded.token != credentials.token else { throw UsageError.unauthorized("Claude") }
            return try await fetch(with: reloaded)
        }
    }

    private func fetch(with credentials: StoredCredentials) async throws -> ProviderUsage {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-cli/2.1.0 (external, cli)", forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UsageError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw UsageError.badResponse("Claude")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw UsageError.unauthorized("Claude")
        }
        if http.statusCode == 429 {
            throw UsageError.rateLimited("Claude")
        }
        guard http.statusCode == 200 else {
            throw UsageError.server("Claude", http.statusCode)
        }
        guard let payload = try? JSONDecoder().decode(Response.self, from: data) else {
            throw UsageError.badResponse("Claude")
        }

        return ProviderUsage(
            provider: .claude,
            plan: credentials.subscription.map(Self.displayPlan),
            session: payload.fiveHour?.model,
            weekly: payload.sevenDay?.model,
            updatedAt: Date(),
            message: nil)
    }

    /// Reads Claude Code's Keychain item through /usr/bin/security, the same way Claude Code
    /// itself reads it. Claude Code creates the item with that tool, so the item's access list
    /// trusts it and the read never asks for a password. Reading the item directly with
    /// SecItemCopyMatching would instead require UsageBar to be on the access list, and that
    /// approval is lost whenever Claude Code rewrites the item after a token refresh.
    fileprivate static func readKeychain() throws -> StoredCredentials {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw UsageError.claudeKeychainDenied
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        // 44 is errSecItemNotFound: Claude Code has never signed in on this Mac.
        if process.terminationStatus == 44 { throw UsageError.missingClaudeLogin }
        guard process.terminationStatus == 0 else { throw UsageError.claudeKeychainDenied }
        guard let credentials = parseCredentials(data) else { throw UsageError.missingClaudeLogin }
        return credentials
    }

    static func parseCredentials(_ data: Data) -> StoredCredentials? {
        guard let root = try? JSONDecoder().decode(Credentials.self, from: data),
              let token = root.claudeAiOauth?.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty
        else { return nil }
        return StoredCredentials(
            token: token,
            subscription: root.claudeAiOauth?.subscriptionType,
            expiresAt: root.claudeAiOauth?.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) })
    }

    private static func displayPlan(_ raw: String) -> String {
        switch raw.lowercased() {
        case "pro": "Claude Pro"
        case "max": "Claude Max"
        case "team": "Claude Team"
        case "enterprise": "Claude Enterprise"
        default: "Claude \(raw.capitalized)"
        }
    }
}
