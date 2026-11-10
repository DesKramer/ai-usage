import Foundation
import ServiceManagement

/// Non-UI entry point for managing the login item, so installation scripts can enable
/// Open at Login without driving the menu bar UI. Launch through LaunchServices:
/// `open -a /Applications/UsageBar.app --args --login-item enable`
enum LoginItemControl {
    static func handleIfRequested() {
        let arguments = CommandLine.arguments
        guard let flagIndex = arguments.firstIndex(of: "--login-item") else { return }

        let command = arguments.count > flagIndex + 1 ? arguments[flagIndex + 1] : "status"
        let service = SMAppService.mainApp

        switch command {
        case "enable":
            if service.status != .enabled {
                do {
                    try service.register()
                } catch {
                    FileHandle.standardError.write(
                        Data("login-item enable failed: \(error.localizedDescription)\n".utf8))
                    exit(1)
                }
            }
            print("login-item: \(describe(service.status))")
            exit(service.status == .enabled ? 0 : 1)
        case "disable":
            do {
                try service.unregister()
            } catch {
                FileHandle.standardError.write(
                    Data("login-item disable failed: \(error.localizedDescription)\n".utf8))
                exit(1)
            }
            print("login-item: \(describe(service.status))")
            exit(0)
        case "status":
            print("login-item: \(describe(service.status))")
            exit(service.status == .enabled ? 0 : 1)
        default:
            FileHandle.standardError.write(Data("unknown --login-item command: \(command)\n".utf8))
            exit(2)
        }
    }

    private static func describe(_ status: SMAppService.Status) -> String {
        switch status {
        case .enabled: return "enabled"
        case .notRegistered: return "not registered"
        case .requiresApproval: return "requires approval in System Settings > General > Login Items"
        case .notFound: return "not found"
        @unknown default: return "unknown (\(status.rawValue))"
        }
    }
}
