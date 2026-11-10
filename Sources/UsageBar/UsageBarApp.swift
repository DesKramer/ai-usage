import SwiftUI

@main
struct UsageBarApp: App {
    @StateObject private var store: UsageStore

    init() {
        LoginItemControl.handleIfRequested()

        let store = UsageStore()
        _store = StateObject(wrappedValue: store)
        store.start()
    }

    var body: some Scene {
        MenuBarExtra {
            UsagePanel()
                .environmentObject(store)
        } label: {
            Image(nsImage: MenuBarStatusImage.make(
                claudeValue: store.claudeMenuBarValue,
                codexValue: store.codexMenuBarValue))
                .renderingMode(.template)
                .foregroundStyle(.white)
                .accessibilityLabel(
                    "Claude \(store.claudeMenuBarValue), Codex \(store.codexMenuBarValue)")
        }
        .menuBarExtraStyle(.window)
    }
}
