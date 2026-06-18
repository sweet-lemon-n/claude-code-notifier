import AppKit

/// Manages sound listing and playback using NSSound.
final class SoundManager {
    unowned let settings: SettingsStore

    /// Hold strong references so ARC doesn't kill sounds mid-playback.
    /// Cleaned up periodically.
    private var activePlayers: [NSSound] = []
    private var cleanupWorkItem: DispatchWorkItem?

    /// Ordered list of system sound names found in /System/Library/Sounds (no extension)
    static let systemSounds: [String] = {
        let url = URL(fileURLWithPath: "/System/Library/Sounds")
        guard let contents = try? FileManager.default
            .contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        else { return [] }
        return contents
            .filter { $0.pathExtension == "aiff" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }()

    init(settings: SettingsStore) {
        self.settings = settings
    }

    /// Play the sound configured for the given event.
    @MainActor func play(for event: EventType) {
        guard settings.enableSound, !settings.muted else { return }
        playSound(name: settings.soundName(for: event))
    }

    /// Preview a sound by name.
    @MainActor func preview(name: String) {
        playSound(name: name)
    }

    // MARK: - Private

    @MainActor private func playSound(name: String) {
        let sound: NSSound?

        if name == "__custom__", !settings.customSoundPath.isEmpty {
            sound = NSSound(contentsOfFile: settings.customSoundPath, byReference: false)
        } else {
            let path = "/System/Library/Sounds/\(name).aiff"
            sound = NSSound(contentsOfFile: path, byReference: false)
        }

        guard let sound else { return }
        activePlayers.append(sound)
        sound.play()

        // Schedule cleanup of finished sounds after a reasonable timeout.
        scheduleCleanup(after: 10)
    }

    private func scheduleCleanup(after seconds: TimeInterval) {
        cleanupWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.activePlayers.removeAll()
        }
        cleanupWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}
