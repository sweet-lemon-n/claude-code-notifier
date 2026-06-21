import Foundation

/// Provides localized UI strings. Detects system language preference.
/// Falls back to English if the preferred language is not Chinese.
enum LocaleManager {
    /// Returns `true` if the user's preferred language is a variant of Chinese.
    static var isChinese: Bool {
        guard let lang = Locale.preferredLanguages.first else { return false }
        return lang.hasPrefix("zh-Hans") || lang.hasPrefix("zh-Hant") || lang.hasPrefix("zh")
    }
}

// MARK: - Localized string tables

enum L10n {
    // Menu bar
    static var menuTitle: String {
        isCN ? "代码提醒" : "Code Notifier"
    }
    static var listening: String {
        isCN ? "本地服务运行中" : "Listening on 127.0.0.1"
    }
    static var recentHeader: String {
        isCN ? "最近通知" : "RECENT"
    }
    static var clearHistory: String {
        isCN ? "清除历史" : "Clear History"
    }
    static var settingsButton: String {
        isCN ? "设置\u{2026}" : "Settings\u{2026}"
    }
    static var quitButton: String {
        isCN ? "退出代码提醒" : "Quit Code Notifier"
    }
    static var muteTooltip: String {
        isCN ? "切换静音" : "Toggle Mute"
    }

    // Settings window
    static var settingsWindowTitle: String {
        isCN ? "代码提醒设置" : "Code Notifier Settings"
    }

    // Tab labels
    static var tabGeneral: String { isCN ? "通用" : "General" }
    static var tabSounds: String { isCN ? "音效" : "Sounds" }
    static var tabMessages: String { isCN ? "通知文案" : "Messages" }
    static var tabAbout: String { isCN ? "关于" : "About" }

    // General tab
    static var behaviorSection: String { isCN ? "行为" : "Behavior" }
    static var launchAtLogin: String { isCN ? "开机启动" : "Launch at Login" }
    static var showPreview: String { isCN ? "显示通知预览" : "Show notification preview" }
    static var enableSound: String { isCN ? "启用音效" : "Enable sound" }

    // Sounds tab
    static var alertSoundsSection: String { isCN ? "提醒音效" : "Alert Sounds" }
    static var taskCompleteLabel: String { isCN ? "任务完成" : "Task Complete" }
    static var needsConfirmLabel: String { isCN ? "需要确认" : "Needs Confirm" }
    static var customOption: String { isCN ? "自定义..." : "Custom..." }
    static var chooseFile: String { isCN ? "选择文件..." : "Choose..." }
    static var fileSet: String { isCN ? "已设置" : "Set" }
    static var soundsFooter: String {
        isCN ? "选择一个系统音效，或选择「自定义」来使用你自己的音频文件。点击音效名称可试听。"
             : "Select a system sound or choose Custom to pick your own audio file. Click a sound name to preview."
    }

    // Messages tab
    static var commonSection: String { isCN ? "通用" : "Common" }
    static var notificationTitle: String { isCN ? "通知标题" : "Title" }
    static var stopSection: String { isCN ? "任务完成（Stop 事件）" : "Task Complete (Stop Event)" }
    static var notifSection: String { isCN ? "需要确认（Notification 事件）" : "Needs Confirmation (Notification Event)" }
    static var subtitleLabel: String { isCN ? "副标题" : "Subtitle" }
    static var messageLabel: String { isCN ? "正文" : "Message" }
    static var templateFooter: String {
        isCN ? "可用变量：{project} = 项目文件夹名，{path} = 完整路径"
             : "Available variables: {project} = folder name, {path} = full path"
    }

    // About tab
    static var versionLabel: String { "Version 1.0.0" }
    static var aboutDescription: String {
        isCN ? "Claude Code 和 Codex 的桌面通知工具。\n当任务完成或需要确认时发出提醒。"
             : "Desktop notifications for Claude Code and Codex.\nGet alerted when tasks finish or need your input."
    }
    static var githubLink: String {
        "GitHub Repository"
    }
    static var licenseLabel: String { "MIT License" }

    // Events
    static var stopDisplayName: String { isCN ? "任务完成" : "Task Complete" }
    static var notifDisplayName: String { isCN ? "需要确认" : "Needs Confirmation" }

    // Default notification content
    static var defaultTitle: String { "Code Notifier" }
    static var defaultStopSubtitle: String { isCN ? "任务已完成" : "Task Complete" }
    static var defaultStopMessage: String {
        isCN ? "Claude 已写完，等你确认下一步"
             : "Claude is ready — awaiting your next instruction"
    }
    static var defaultNotifSubtitle: String { isCN ? "需要你的确认" : "Needs Your Confirmation" }
    static var defaultNotifMessage: String {
        isCN ? "Claude 正在等待你的输入"
             : "Claude is waiting for your input"
    }
}

// MARK: - Convenience

private var isCN: Bool { LocaleManager.isChinese }
