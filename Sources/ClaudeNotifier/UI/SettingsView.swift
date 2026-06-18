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
            MessagesTab(settings: settings)
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

// MARK: - Messages Tab

struct MessagesTab: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                TextField(L10n.notificationTitle, text: $settings.notificationTitle)
            } header: {
                Text(L10n.commonSection)
            }

            Section {
                TextField(L10n.subtitleLabel, text: $settings.stopSubtitleTemplate)
                TextField(L10n.messageLabel, text: $settings.stopMessageTemplate)
            } header: {
                Text(L10n.stopSection)
            } footer: {
                Text(L10n.templateFooter)
            }

            Section {
                TextField(L10n.subtitleLabel, text: $settings.notificationSubtitleTemplate)
                TextField(L10n.messageLabel, text: $settings.notificationMessageTemplate)
            } header: {
                Text(L10n.notifSection)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
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
