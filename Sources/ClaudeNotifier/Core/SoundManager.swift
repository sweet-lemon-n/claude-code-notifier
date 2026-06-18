import AppKit

/// Manages sound listing and playback using NSSound.
final class SoundManager {
    unowned let settings: SettingsStore

    /// Cached sounds keyed by name
    private var cache: [String: NSSound] = [:]

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
        // Preload all system sounds
        for name in Self.systemSounds {
            if let s = NSSound(named: .init(name)) {
                cache[name] = s
            }
        }
    }

    /// Play the sound configured for the given event.
    /// Does nothing if muted or sound is disabled.
    @MainActor func play(for event: EventType) {
        guard settings.enableSound, !settings.muted else { return }

        let name = settings.soundName(for: event)

        // Custom file path takes precedence
        if name == "__custom__",
           !settings.customSoundPath.isEmpty,
           let custom = NSSound(contentsOfFile: settings.customSoundPath, byReference: false) {
            custom.play()
            return
        }

        // Play from cache (clone avoids concurrent playback issues)
        if let cached = cache[name], let clone = cached.copy() as? NSSound {
            clone.play()
        } else {
            NSSound(named: .init(name))?.play()
        }
    }

    /// Preview a sound by name (e.g. from the settings picker).
    @MainActor func preview(name: String) {
        if name == "__custom__", !settings.customSoundPath.isEmpty {
            NSSound(contentsOfFile: settings.customSoundPath, byReference: false)?.play()
        } else if let cached = cache[name], let clone = cached.copy() as? NSSound {
            clone.play()
        } else {
            NSSound(named: .init(name))?.play()
        }
    }
}
