import Foundation
import SwiftUI
import ServiceManagement

/// Central settings store backed by UserDefaults via @AppStorage.
/// Published via ObservableObject so SwiftUI views react to changes.
/// Default values adapt to system language (Chinese / English).
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private init() {
        let defaults: [String: Any] = [
            "soundForStop": "Glass",
            "soundForNotification": "Ping",
            "customSoundPath": "",
            "showProjectNameInNotif": true,
            "showTimestampInNotif": true,
            "useClaudeMessageInNotif": true,
            "notifyClaudeCompletion": true,
            "notifyClaudeConfirmation": true,
            "notifyCodexCompletion": true,
            "launchAtLogin": false,
            "showNotificationPreview": true,
            "enableSound": true,
            "muted": false,
            "hasCompletedSetup": false,
        ]
        UserDefaults.standard.register(defaults: defaults)
    }

    // MARK: - Sound settings

    @AppStorage("soundForStop")
    var soundForStop: String = "Glass"

    @AppStorage("soundForNotification")
    var soundForNotification: String = "Ping"

    @AppStorage("customSoundPath")
    var customSoundPath: String = ""

    // MARK: - Notification enrichment (user-friendly toggles)

    /// Show the project folder name in notifications.
    @AppStorage("showProjectNameInNotif")
    var showProjectNameInNotif: Bool = true

    /// Show the current timestamp in notifications.
    @AppStorage("showTimestampInNotif")
    var showTimestampInNotif: Bool = true

    /// Use Claude Code's own message (when available) as the notification body.
    @AppStorage("useClaudeMessageInNotif")
    var useClaudeMessageInNotif: Bool = true

    // MARK: - Notification types

    @AppStorage("notifyClaudeCompletion")
    var notifyClaudeCompletion: Bool = true

    @AppStorage("notifyClaudeConfirmation")
    var notifyClaudeConfirmation: Bool = true

    @AppStorage("notifyCodexCompletion")
    var notifyCodexCompletion: Bool = true

    // MARK: - Behavior

    @AppStorage("launchAtLogin")
    var launchAtLogin: Bool = false {
        didSet { updateLoginItem() }
    }

    @AppStorage("showNotificationPreview")
    var showNotificationPreview: Bool = true

    @AppStorage("enableSound")
    var enableSound: Bool = true

    @AppStorage("muted")
    var muted: Bool = false

    /// First-launch flag: show Dock + settings window, then dismiss to menu bar.
    @AppStorage("hasCompletedSetup")
    var hasCompletedSetup: Bool = false

    // MARK: - Computed

    func soundName(for event: EventType) -> String {
        switch event {
        case .stop, .codexStop: return soundForStop
        case .notification: return soundForNotification
        }
    }

    func isNotificationEnabled(for event: EventType) -> Bool {
        switch event {
        case .stop: return notifyClaudeCompletion
        case .notification: return notifyClaudeConfirmation
        case .codexStop: return notifyCodexCompletion
        }
    }

    /// Default title based on locale
    var effectiveTitle: String {
        L10n.defaultTitle
    }

    /// Default subtitle for an event based on locale
    func effectiveSubtitle(for event: EventType) -> String {
        switch event {
        case .stop, .codexStop: return L10n.defaultStopSubtitle
        case .notification: return L10n.defaultNotifSubtitle
        }
    }

    // MARK: - Login item

    private func updateLoginItem() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[CodeNotifier] SMAppService error: \(error.localizedDescription)")
        }
    }
}
