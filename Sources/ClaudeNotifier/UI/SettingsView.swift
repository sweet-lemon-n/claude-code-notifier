import SwiftUI

/// Main settings / preferences window with tabbed sections.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        TabView {
            GeneralTab(settings: settings)
                .tabItem {
                    Label(L10n.tabGeneral, systemImage: "gearshape")
                }
            SoundsTab(settings: settings)
                .tabItem {
                    Label(L10n.tabSounds, systemImage: "speaker.wave.2")
                }
            NotificationsTab(settings: settings)
                .tabItem {
                    Label(L10n.tabMessages, systemImage: "text.bubble")
                }
            AboutTab()
                .tabItem {
                    Label(L10n.tabAbout, systemImage: "info.circle")
                }
        }
        .frame(minWidth: 480, minHeight: 360)
        .padding(.top, 16)
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle(L10n.launchAtLogin, isOn: $settings.launchAtLogin)
                Toggle(L10n.showPreview, isOn: $settings.showNotificationPreview)
                Toggle(L10n.enableSound, isOn: $settings.enableSound)
            } header: {
                Text(L10n.behaviorSection)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Sounds Tab

struct SoundsTab: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                SoundPickerView(
                    label: L10n.taskCompleteLabel,
                    selection: $settings.soundForStop,
                    settings: settings
                )
                SoundPickerView(
                    label: L10n.needsConfirmLabel,
                    selection: $settings.soundForNotification,
                    settings: settings
                )
            } header: {
                Text(L10n.alertSoundsSection)
            } footer: {
                Text(L10n.soundsFooter)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Notifications Tab

struct NotificationsTab: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.showProjectNameInNotif) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isCN ? "显示项目名称" : "Show project name")
                        Text(isCN ? "通知中展示当前项目文件夹名"
                             : "Include the project folder name in notifications")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $settings.showTimestampInNotif) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isCN ? "显示时间戳" : "Show timestamp")
                        Text(isCN ? "通知中展示当前时间"
                             : "Include the current time in notifications")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $settings.useClaudeMessageInNotif) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isCN ? "显示 Claude 的原话" : "Show Claude's message")
                        Text(isCN ? "当 Claude 需要确认时,用它的原文作为通知内容"
                             : "Use Claude's own words when it needs confirmation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(isCN ? "通知内容" : "Notification Content")
            } footer: {
                Text(isCN
                     ? "开启后通知内容会自动变化。关闭全部选项时使用简洁的默认文案。"
                     : "When enabled, notification content varies dynamically. Disable all for simple default text.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var isCN: Bool { LocaleManager.isChinese }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            Text(L10n.menuTitle)
                .font(.title2)
                .fontWeight(.semibold)

            Text(L10n.versionLabel)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(L10n.aboutDescription)
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            Link(L10n.githubLink,
                 destination: URL(string: "https://github.com/sweet-lemon-n/claude-code-notifier")!)
                .font(.callout)
                .padding(.top, 8)

            Text(L10n.licenseLabel)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
