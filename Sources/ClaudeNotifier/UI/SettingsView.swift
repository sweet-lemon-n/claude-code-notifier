import SwiftUI

/// Main settings / preferences window with tabbed sections.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        TabView {
            GeneralTab(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            SoundsTab(settings: settings)
                .tabItem {
                    Label("Sounds", systemImage: "speaker.wave.2")
                }
            MessagesTab(settings: settings)
                .tabItem {
                    Label("Messages", systemImage: "text.bubble")
                }
            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
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
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)

                Toggle("Show notification preview", isOn: $settings.showNotificationPreview)

                Toggle("Enable sound", isOn: $settings.enableSound)

            } header: {
                Text("Behavior")
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
                    label: "Task Complete",
                    selection: $settings.soundForStop,
                    settings: settings
                )

                SoundPickerView(
                    label: "Needs Confirm",
                    selection: $settings.soundForNotification,
                    settings: settings
                )
            } header: {
                Text("Alert Sounds")
            } footer: {
                Text("Select a system sound or choose Custom to pick your own audio file. Click a sound name to preview.")
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
                TextField("Title", text: $settings.notificationTitle)
            } header: {
                Text("Common")
            }

            Section {
                TextField("Subtitle", text: $settings.stopSubtitleTemplate)
                TextField("Message", text: $settings.stopMessageTemplate)
            } header: {
                Text("Task Complete (Stop Event)")
            } footer: {
                Text("Use {project} for project folder name, {path} for full path.")
            }

            Section {
                TextField("Subtitle", text: $settings.notificationSubtitleTemplate)
                TextField("Message", text: $settings.notificationMessageTemplate)
            } header: {
                Text("Needs Confirmation (Notification Event)")
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

            Text("Claude Notifier")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Desktop notifications for Claude Code.\nGet alerted when Claude finishes a task or needs your input.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            Link("GitHub Repository",
                 destination: URL(string: "https://github.com/sweet-lemon-n/claude-code-notifier")!)
                .font(.callout)
                .padding(.top, 8)

            Text("MIT License")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
