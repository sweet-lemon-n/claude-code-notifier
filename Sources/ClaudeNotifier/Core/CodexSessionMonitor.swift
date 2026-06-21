import Foundation

final class CodexSessionMonitor {
    private let sessionsURL: URL
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "CodeNotifier.CodexSessionMonitor")
    private var seenCompletions = Set<String>()
    private var baselineComplete = false
    private let onComplete: (HookPayload) -> Void

    init(onComplete: @escaping (HookPayload) -> Void) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.sessionsURL = home.appendingPathComponent(".codex/sessions")
        self.onComplete = onComplete
    }

    deinit {
        stop()
    }

    func start() {
        scan(deliverNewEvents: false)

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in
            self?.scan(deliverNewEvents: true)
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func scan(deliverNewEvents: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            let files = self.recentSessionFiles()
            for file in files {
                self.scan(file: file, deliverNewEvents: deliverNewEvents && self.baselineComplete)
            }
            self.baselineComplete = true
        }
    }

    private func recentSessionFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        var files: [(URL, Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate,
                  modified >= cutoff else { continue }
            files.append((url, modified))
        }
        return files.sorted { $0.1 < $1.1 }.map(\.0)
    }

    private func scan(file: URL, deliverNewEvents: Bool) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return }
        defer { try? handle.close() }

        let data = handle.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return }

        var cwd: String?
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let lineData = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let payload = object["payload"] as? [String: Any] else { continue }

            if cwd == nil {
                cwd = payload["cwd"] as? String
            }

            guard payload["type"] as? String == "task_complete" else { continue }
            let turnID = payload["turn_id"] as? String ?? ""
            let completedAt = payload["completed_at"] as? String ?? ""
            let key = "\(file.path)|\(turnID)|\(completedAt)"
            guard !seenCompletions.contains(key) else { continue }
            seenCompletions.insert(key)

            guard deliverNewEvents else { continue }
            appendLog("codex session task_complete file=\(file.lastPathComponent) turn_id=\(turnID)")
            onComplete(makePayload(file: file, cwd: cwd, taskComplete: payload))
        }
    }

    private func makePayload(file: URL, cwd: String?, taskComplete: [String: Any]) -> HookPayload {
        let duration = (taskComplete["duration_ms"] as? Double)
            ?? (taskComplete["duration_ms"] as? Int).map(Double.init)
        let message: String?
        if let duration, duration > 0 {
            message = LocaleManager.isChinese
                ? "用时: \(format(milliseconds: duration))"
                : "Elapsed: \(format(milliseconds: duration))"
        } else {
            message = LocaleManager.isChinese ? "Codex 任务已完成" : "Codex task completed"
        }

        return HookPayload(
            event: .codexStop,
            cwd: cwd,
            message: message,
            sessionId: taskComplete["turn_id"] as? String,
            transcriptPath: file.path,
            notifierScriptReceivedAt: Date().timeIntervalSince1970,
            notifierSourceEvent: "codex_session_task_complete",
            actionSummary: nil
        )
    }

    private func format(milliseconds: Double) -> String {
        let seconds = Int((milliseconds / 1000).rounded())
        if seconds < 60 {
            return LocaleManager.isChinese ? "\(seconds) 秒" : "\(seconds)s"
        }
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes < 60 {
            return LocaleManager.isChinese
                ? "\(minutes) 分 \(remainder) 秒"
                : "\(minutes)m \(remainder)s"
        }
        let hours = minutes / 60
        return LocaleManager.isChinese
            ? "\(hours) 小时 \(minutes % 60) 分"
            : "\(hours)h \(minutes % 60)m"
    }

    private func appendLog(_ line: String) {
        let path = "\(NSHomeDirectory())/.claude/claude-notifier-latency.log"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let entry = "\(formatter.string(from: Date())) [CodeNotifier] \(line)\n"
        guard let data = entry.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: path),
           let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
}
