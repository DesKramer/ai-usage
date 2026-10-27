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
