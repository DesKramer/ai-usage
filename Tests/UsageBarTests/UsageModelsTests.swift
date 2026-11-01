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
