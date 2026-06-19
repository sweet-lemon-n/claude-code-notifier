import SwiftUI

struct MainWindowView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var notificationManager: NotificationManager

    var onOpenProject: (String) -> Void
    var onOpenSettings: () -> Void
    var onToggleMute: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.menuTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text(L10n.listening)
                        .foregroundColor(.secondary)
                }
                .font(.callout)
            }

            Spacer()

            Button(action: onToggleMute) {
                Image(systemName: settings.muted ? "bell.slash.fill" : "bell.fill")
                    .frame(width: 18, height: 18)
            }
            .help(L10n.muteTooltip)

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .frame(width: 18, height: 18)
            }
            .help(L10n.settingsButton)
        }
        .padding(20)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 0) {
            summaryColumn
            Divider()
            recentColumn
        }
    }

    private var summaryColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocaleManager.isChinese ? "概览" : "Overview")
                .font(.headline)

            statRow(
                icon: "exclamationmark.triangle.fill",
                tint: .orange,
                title: LocaleManager.isChinese ? "确认提醒" : "Confirmations",
                value: "\(count(for: .notification))"
            )
            statRow(
                icon: "checkmark.circle.fill",
                tint: .green,
                title: LocaleManager.isChinese ? "完成通知" : "Completions",
                value: "\(count(for: .stop))"
            )
            statRow(
                icon: settings.muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                tint: settings.muted ? .secondary : .blue,
                title: LocaleManager.isChinese ? "声音" : "Sound",
                value: settings.muted
                    ? (LocaleManager.isChinese ? "静音" : "Muted")
                    : (LocaleManager.isChinese ? "开启" : "On")
            )

            Spacer()
        }
        .padding(22)
        .frame(minWidth: 250, idealWidth: 250, maxWidth: 250,
               maxHeight: .infinity, alignment: .topLeading)
    }

    private var recentColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.recentHeader)
                    .font(.headline)
                Spacer()
                if !notificationManager.recentNotifications.isEmpty {
                    Button(L10n.clearHistory) {
                        notificationManager.recentNotifications.removeAll()
                    }
                }
            }

            if notificationManager.recentNotifications.isEmpty {
                ContentUnavailableView(
                    LocaleManager.isChinese ? "还没有通知" : "No Notifications Yet",
                    systemImage: "bell",
                    description: Text(LocaleManager.isChinese
                                      ? "ClaudeCode 需要确认或任务完成时会出现在这里。"
                                      : "Confirmations and completions will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(notificationManager.recentNotifications) { record in
                            notificationRow(record)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func statRow(icon: String, tint: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(tint)
                .frame(width: 22)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.callout)
    }

    private func notificationRow(_ record: NotificationRecord) -> some View {
        Button {
            if let path = record.projectPath, !path.isEmpty {
                onOpenProject(path)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: record.eventType == .notification
                      ? "exclamationmark.triangle.fill"
                      : "checkmark.circle.fill")
                    .foregroundColor(record.eventType == .notification ? .orange : .green)
                    .font(.title3)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(.headline)
                    Text(record.message)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    Text(record.time, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func count(for eventType: EventType) -> Int {
        notificationManager.recentNotifications.filter { $0.eventType == eventType }.count
    }
}
