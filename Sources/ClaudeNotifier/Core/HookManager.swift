import Foundation

final class HookManager {
    private let settingsURL: URL
    private let notifyScriptPath: String
    private var directorySource: DispatchSourceFileSystemObject?
    private var settingsSource: DispatchSourceFileSystemObject?
    private var repairTimer: DispatchSourceTimer?
    private var directoryDescriptor: CInt = -1
    private var settingsDescriptor: CInt = -1
    private var debounceWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "ClaudeNotifier.HookManager")

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.settingsURL = home.appendingPathComponent(".claude/settings.json")
        self.notifyScriptPath = Bundle.main.path(forResource: "notify", ofType: "sh")
            ?? "\(home.path)/.claude/claude-notifier/notify.sh"
    }

    deinit {
        stop()
    }

    func start() {
        ensureHooks()
        startWatching()
    }

    func stop() {
        debounceWorkItem?.cancel()
        repairTimer?.cancel()
        repairTimer = nil
        directorySource?.cancel()
        directorySource = nil
        settingsSource?.cancel()
        settingsSource = nil
    }

    func ensureHooks() {
        queue.async { [settingsURL, notifyScriptPath] in
            Self.upsertHooks(settingsURL: settingsURL, notifyScriptPath: notifyScriptPath)
        }
    }

    private func startWatching() {
        stop()

        let dirURL = settingsURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: dirURL, withIntermediateDirectories: true
        )

        let descriptor = open(dirURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        directoryDescriptor = descriptor

        let directorySource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: queue
        )
        directorySource.setEventHandler { [weak self] in
            self?.scheduleRepair()
            self?.restartSettingsFileWatcher()
        }
        directorySource.setCancelHandler { [weak self] in
            close(descriptor)
            if self?.directoryDescriptor == descriptor {
                self?.directoryDescriptor = -1
            }
        }
        self.directorySource = directorySource
        directorySource.resume()

        restartSettingsFileWatcher()
        startRepairTimer()
    }

    private func restartSettingsFileWatcher() {
        settingsSource?.cancel()
        settingsSource = nil

        let descriptor = open(settingsURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        settingsDescriptor = descriptor

        let settingsSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .attrib, .extend],
            queue: queue
        )
        settingsSource.setEventHandler { [weak self] in
            self?.scheduleRepair()
        }
        settingsSource.setCancelHandler { [weak self] in
            close(descriptor)
            if self?.settingsDescriptor == descriptor {
                self?.settingsDescriptor = -1
            }
        }
        self.settingsSource = settingsSource
        settingsSource.resume()
    }

    private func startRepairTimer() {
        repairTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in
            self?.ensureHooks()
        }
        repairTimer = timer
        timer.resume()
    }

    private func scheduleRepair() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.ensureHooks()
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private static func upsertHooks(settingsURL: URL, notifyScriptPath: String) {
        let dirURL = settingsURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: dirURL, withIntermediateDirectories: true
        )

        var root = readJSONDictionary(settingsURL) ?? [:]
        var hooks = root["hooks"] as? [String: Any] ?? [:]

        upsert(event: "Stop", arg: "stop", matcher: nil,
               hooks: &hooks, notifyScriptPath: notifyScriptPath)
        upsert(event: "Notification", arg: "notification", matcher: "idle_prompt",
               hooks: &hooks, notifyScriptPath: notifyScriptPath)
        upsert(event: "PermissionRequest", arg: "permission", matcher: nil,
               hooks: &hooks, notifyScriptPath: notifyScriptPath)
        upsert(event: "PreToolUse", arg: "question", matcher: "AskUserQuestion",
               hooks: &hooks, notifyScriptPath: notifyScriptPath)

        root["hooks"] = hooks
        guard JSONSerialization.isValidJSONObject(root),
              let data = try? JSONSerialization.data(
                withJSONObject: root,
                options: [.prettyPrinted, .sortedKeys]
              ) else { return }

        if let current = readJSONDictionary(settingsURL),
           let currentData = try? JSONSerialization.data(
            withJSONObject: current,
            options: [.prettyPrinted, .sortedKeys]
           ),
           currentData == data {
            return
        }

        try? data.write(to: settingsURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: notifyScriptPath
        )
    }

    private static func readJSONDictionary(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else {
            return nil
        }
        return dict
    }

    private static func upsert(event: String,
                               arg: String,
                               matcher: String?,
                               hooks: inout [String: Any],
                               notifyScriptPath: String) {
        let existing = hooks[event] as? [[String: Any]] ?? []
        let cleaned = existing.compactMap { matcherConfig -> [String: Any]? in
            var matcherConfig = matcherConfig
            let hookItems = matcherConfig["hooks"] as? [[String: Any]] ?? []
            let kept = hookItems.filter { hook in
                !isNotifierCommand(hook["command"] as? String,
                                   notifyScriptPath: notifyScriptPath)
            }
            guard !kept.isEmpty else { return nil }
            matcherConfig["hooks"] = kept
            return matcherConfig
        }

        var entry: [String: Any] = [
            "hooks": [[
                "type": "command",
                "command": "\"\(notifyScriptPath)\" \(arg)"
            ]]
        ]
        if let matcher {
            entry["matcher"] = matcher
        }

        hooks[event] = cleaned + [entry]
    }

    private static func isNotifierCommand(_ command: String?,
                                          notifyScriptPath: String) -> Bool {
        guard let command else { return false }
        if command.contains(notifyScriptPath) { return true }
        return command.contains("notify.sh")
    }
}
