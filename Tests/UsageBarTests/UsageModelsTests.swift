import Foundation
import Testing
@testable import UsageBar

@Test func remainingPercentageIsClamped() {
    #expect(UsageWindow(usedPercent: 25, resetsAt: nil).remainingPercent == 75)
    #expect(UsageWindow(usedPercent: 130, resetsAt: nil).remainingPercent == 0)
    #expect(UsageWindow(usedPercent: -10, resetsAt: nil).remainingPercent == 100)
}

@Test func lowestRemainingUsesMostConstrainedWindow() {
    let usage = ProviderUsage(
        provider: .codex,
        plan: "ChatGPT Plus",
        session: UsageWindow(usedPercent: 10, resetsAt: nil),
        weekly: UsageWindow(usedPercent: 55, resetsAt: nil),
        scopedWeekly: [
            ScopedUsage(name: "Fable", window: UsageWindow(usedPercent: 90, resetsAt: nil)),
        ],
        updatedAt: Date(),
        message: nil)
    #expect(usage.lowestRemaining == 45)
}

@Test func claudeCredentialsIncludeExpiry() throws {
    let json = #"{"claudeAiOauth":{"accessToken":" token ","expiresAt":1800000000000,"subscriptionType":"max"}}"#
    let credentials = try #require(ClaudeUsageClient.parseCredentials(Data(json.utf8)))
    #expect(credentials.token == "token")
    #expect(credentials.subscription == "max")
    #expect(credentials.expiresAt == Date(timeIntervalSince1970: 1_800_000_000))
    #expect(credentials.isFresh == (Date(timeIntervalSince1970: 1_800_000_000).timeIntervalSinceNow > 60))
}

@Test func expiredClaudeCredentialsAreNotFresh() {
    let expired = ClaudeUsageClient.StoredCredentials(
        token: "token", subscription: nil, expiresAt: Date().addingTimeInterval(-10))
    #expect(!expired.isFresh)
}

@Test func claudeScopedWeeklyLimitsAreDecoded() throws {
    let data = Data(#"""
    {
      "five_hour": {
        "utilization": 1,
        "resets_at": "2026-11-10T19:40:00Z"
      },
      "seven_day": {
        "utilization": 0,
        "resets_at": "2026-11-15T03:00:00Z"
      },
      "limits": [
        {
          "kind": "weekly_all",
          "percent": 0,
          "resets_at": "2026-11-15T03:00:00Z"
        },
        {
          "kind": "weekly_scoped",
          "percent": 7,
          "resets_at": "2026-11-15T03:00:00Z",
          "scope": {
            "model": {
              "display_name": "Fable"
            }
          }
        }
      ]
    }
    """#.utf8)

    let usage = try ClaudeUsageClient.decodeUsageResponse(
        data,
        subscription: "pro",
        updatedAt: Date(timeIntervalSince1970: 0))

    #expect(usage.plan == "Claude Pro")
    #expect(usage.session?.usedPercent == 1)
    #expect(usage.weekly?.usedPercent == 0)
    #expect(usage.scopedWeekly == [
        ScopedUsage(
            name: "Fable",
            window: UsageWindow(
                usedPercent: 7,
                resetsAt: ISO8601DateFormatter().date(from: "2026-11-15T03:00:00Z"))),
    ])
}
