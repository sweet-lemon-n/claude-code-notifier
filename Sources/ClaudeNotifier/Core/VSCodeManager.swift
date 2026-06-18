import AppKit

/// Finds and activates the VSCode window for a given project path.
///
/// Strategy (in order):
/// 1. Run `code <project_path>` — handles multi-window matching perfectly
/// 2. NSWorkspace.open — opens folder in VSCode
/// 3. Activate any running VSCode process as last resort
final class VSCodeManager {
    private let bundleIDs = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.microsoft.VSCodeExploration"
    ]

    /// Bring the VSCode window for `projectPath` to the foreground.
    func activateProject(path projectPath: String) {
        // Strategy 1: code CLI
        if let codePath = findCodeCLI() {
            runCodeCLI(codePath, projectPath: projectPath)
            return
        }

        // Strategy 2: NSWorkspace
        if let vscodeURL = findVSCodeApp() {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open(
                [URL(fileURLWithPath: projectPath)],
                withApplicationAt: vscodeURL,
                configuration: config
            ) { _, _ in }
            return
        }

        // Strategy 3: activate any VSCode
        for bid in bundleIDs {
            if let app = NSRunningApplication.runningApplications(
                withBundleIdentifier: bid
            ).first {
                app.activate()
                return
            }
        }
    }

    // MARK: - Helpers

    private func findCodeCLI() -> String? {
        // Check known locations first
        let candidates = [
            "/opt/homebrew/bin/code",
            "/usr/local/bin/code",
            NSHomeDirectory() + "/.vscode/bin/code"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // Fall back to `which code`
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["which", "code"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let found = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let found, !found.isEmpty,
           FileManager.default.isExecutableFile(atPath: found) {
            return found
        }
        return nil
    }

    private func findVSCodeApp() -> URL? {
        for bid in bundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                return url
            }
        }
        let fallback = [
            "/Applications/Visual Studio Code.app",
            "/Applications/Visual Studio Code - Insiders.app"
        ]
        for path in fallback {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    private func runCodeCLI(_ codePath: String, projectPath: String) {
        let task = Process()
        task.launchPath = codePath
        task.arguments = [projectPath]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        // Process is short-lived; no need to wait
    }
}
