import Foundation
import ServiceManagement

/// "Open at login", using the system's login-item service (macOS 13 and later).
enum LoginItem {
    static var isSupported: Bool {
        if #available(macOS 13.0, *) { return true }
        return false
    }

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    /// True when macOS needs the user to approve the login item in System Settings.
    static var needsApproval: Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .requiresApproval }
        return false
    }

    static func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else { return }
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}
