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
        // Register localized defaults before @AppStorage reads them.
        let defaults: [String: Any] = [
            "soundForStop": "Glass",
            "soundForNotification": "Ping",
            "customSoundPath": "",
            "notificationTitle": L10n.defaultTitle,
            "stopSubtitleTemplate": L10n.defaultStopSubtitle,
            "stopMessageTemplate": L10n.defaultStopMessage,
            "notificationSubtitleTemplate": L10n.defaultNotifSubtitle,
            "notificationMessageTemplate": L10n.defaultNotifMessage,
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

    // MARK: - Notification content

    @AppStorage("notificationTitle")
    var notificationTitle: String = L10n.defaultTitle

    @AppStorage("stopSubtitleTemplate")
    var stopSubtitleTemplate: String = L10n.defaultStopSubtitle

    @AppStorage("stopMessageTemplate")
    var stopMessageTemplate: String = L10n.defaultStopMessage

    @AppStorage("notificationSubtitleTemplate")
    var notificationSubtitleTemplate: String = L10n.defaultNotifSubtitle

    @AppStorage("notificationMessageTemplate")
    var notificationMessageTemplate: String = L10n.defaultNotifMessage

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

    // MARK: - Computed

    /// Resolve the sound name for an event.
    /// Returns a system sound name (without .aiff), or "__custom__" if a custom file is set.
    func soundName(for event: EventType) -> String {
        switch event {
        case .stop: return soundForStop
        case .notification: return soundForNotification
        }
    }

    func subtitleTemplate(for event: EventType) -> String {
        switch event {
        case .stop: return stopSubtitleTemplate
        case .notification: return notificationSubtitleTemplate
        }
    }

    func messageTemplate(for event: EventType) -> String {
        switch event {
        case .stop: return stopMessageTemplate
        case .notification: return notificationMessageTemplate
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
            print("[ClaudeNotifier] SMAppService error: \(error.localizedDescription)")
        }
    }
}
