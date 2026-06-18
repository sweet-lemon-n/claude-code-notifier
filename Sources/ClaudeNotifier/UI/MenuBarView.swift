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
                Text("Claude Notifier")
                    .font(.headline)
                Spacer()
                Button(action: onToggleMute) {
                    Image(systemName: settings.muted
                          ? "bell.slash.fill"
                          : "bell.fill")
                        .foregroundColor(settings.muted ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .help(settings.muted ? "Unmute" : "Mute")
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
                Text("Listening on 127.0.0.1")
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
                    Text("RECENT")
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

            // Quick toggle
            if !notificationManager.recentNotifications.isEmpty {
                Button("Clear History") {
                    notificationManager.recentNotifications.removeAll()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                Divider()
            }

            // Actions
            Button("Settings\u{2026}") {
                onOpenSettings()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            Button("Quit Claude Notifier") {
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
