import Foundation

final class CodexNotifyManager {
    private let configURL: URL
    private let nextNotifyURL: URL
    private let wrapperPath: String
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1
    private var debounceWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "CodeNotifier.CodexNotifyManager")

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let codexDir = home.appendingPathComponent(".codex")
        self.configURL = codexDir.appendingPathComponent("config.toml")
        self.nextNotifyURL = codexDir.appendingPathComponent("code-notifier-next-notify.json")
        self.wrapperPath = Bundle.main.path(forResource: "codex-notify", ofType: "sh")
            ?? "\(home.path)/.codex/code-notifier/codex-notify.sh"
    }

    deinit {
        stop()
    }

    func start() {
        ensureNotify()
        startWatching()
    }

    func stop() {
        debounceWorkItem?.cancel()
        source?.cancel()
        source = nil
    }

    func ensureNotify() {
        queue.async { [configURL, nextNotifyURL, wrapperPath] in
            Self.upsertNotify(configURL: configURL,
                              nextNotifyURL: nextNotifyURL,
                              wrapperPath: wrapperPath)
        }
    }

    private func startWatching() {
        stop()

        let dirURL = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let descriptor = open(dirURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        self.descriptor = descriptor

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.scheduleRepair()
        }
        source.setCancelHandler { [weak self] in
            close(descriptor)
            if self?.descriptor == descriptor {
                self?.descriptor = -1
            }
        }
        self.source = source
        source.resume()
    }

    private func scheduleRepair() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.ensureNotify()
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private static func upsertNotify(configURL: URL,
                                     nextNotifyURL: URL,
                                     wrapperPath: String) {
        guard FileManager.default.fileExists(atPath: configURL.path),
              let original = try? String(contentsOf: configURL, encoding: .utf8)
        else { return }

        let notifyPattern = #"(?m)^notify\s*=\s*(\[.*\])\s*$"#
        guard let regex = try? NSRegularExpression(pattern: notifyPattern) else { return }
        let range = NSRange(original.startIndex..<original.endIndex, in: original)
        guard let notifyData = try? JSONSerialization.data(
            withJSONObject: [wrapperPath, "turn-ended"]
        ),
              let notifyValue = String(data: notifyData, encoding: .utf8)
        else { return }
        let wrapperLine = "notify = \(notifyValue)"

        var updated = original
        if let match = regex.firstMatch(in: original, range: range),
           let lineRange = Range(match.range, in: original),
           let valueRange = Range(match.range(at: 1), in: original) {
            let currentLine = String(original[lineRange])
            if currentLine.contains("codex-notify.sh") {
                return
            }
            let currentValue = String(original[valueRange])
            savePreviousNotify(currentValue,
                               nextNotifyURL: nextNotifyURL,
                               wrapperPath: wrapperPath)
            updated.replaceSubrange(lineRange, with: wrapperLine)
        } else {
            updated = wrapperLine + "\n" + original
        }

        guard updated != original else { return }
        try? updated.write(to: configURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: wrapperPath
        )
    }

    private static func savePreviousNotify(_ rawValue: String,
                                           nextNotifyURL: URL,
                                           wrapperPath: String) {
        guard !rawValue.contains("codex-notify.sh"),
              let data = rawValue.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String],
              !parsed.isEmpty,
              parsed.first != wrapperPath,
              let out = try? JSONSerialization.data(withJSONObject: parsed,
                                                    options: [.prettyPrinted])
        else { return }

        try? out.write(to: nextNotifyURL, options: .atomic)
    }
}
