import AppKit

/// Activates the VSCode window for a given project path.
///
/// Strategy:
/// 1. Activate any running VSCode instance via NSRunningApplication
/// 2. Open the project in VSCode (reuses existing window if already open)
final class VSCodeManager {
    private let bundleIDs = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.microsoft.VSCodeExploration"
    ]

    func activateProject(path projectPath: String) {
        // Step 1: Activate VSCode (bring to front)
        if let running = findRunningVSCode() {
            running.activate()
        }

        // Step 2: Open the project — `open -a "Visual Studio Code" <folder>`
        // This reuses an existing window for that folder, or creates one.
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", "Visual Studio Code", projectPath]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }

    private func findRunningVSCode() -> NSRunningApplication? {
        for bid in bundleIDs {
            if let app = NSRunningApplication.runningApplications(
                withBundleIdentifier: bid
            ).first {
                return app
            }
        }
        return nil
    }
}
