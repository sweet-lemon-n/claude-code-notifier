import SwiftUI

/// SwiftUI view shown inside the menu bar popover.
struct MenuBarView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var notificationManager: NotificationManager

    var onOpenSettings: () -> Void
    var onToggleMute: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "bell.badge.fill")
                    .font(.title3)
                Text(L10n.menuTitle)
                    .font(.headline)
                Spacer()
                Button(action: onToggleMute) {
                    Image(systemName: settings.muted
                          ? "bell.slash.fill"
                          : "bell.fill")
                        .foregroundColor(settings.muted ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .help(L10n.muteTooltip)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Server status
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text(L10n.listening)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Recent notifications
            if !notificationManager.recentNotifications.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.recentHeader)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 6)

                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(notificationManager.recentNotifications.prefix(5)) { record in
                                HStack(spacing: 6) {
                                    Image(systemName: record.eventType.iconName)
                                        .font(.system(size: 11))
                                        .foregroundColor(.accentColor)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(record.message)
                                            .font(.system(size: 11))
                                            .lineLimit(1)
                                        Text(record.time, style: .relative)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 3)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }

                Divider()
            }

            // Clear history
            if !notificationManager.recentNotifications.isEmpty {
                Button(L10n.clearHistory) {
                    notificationManager.recentNotifications.removeAll()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                Divider()
            }

            // Settings
            Button(L10n.settingsButton) {
                onOpenSettings()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Quit
            Button(L10n.quitButton) {
                onQuit()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .padding(.bottom, 6)
        }
        .frame(width: 270)
    }
}
