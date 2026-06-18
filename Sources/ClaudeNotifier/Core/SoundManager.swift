import AppKit

/// Manages sound listing and playback using NSSound.
final class SoundManager {
    unowned let settings: SettingsStore

    /// Cached sounds keyed by name
    private var cache: [String: NSSound] = [:]

    /// Hold strong references to currently playing sounds so ARC doesn't kill them mid-playback.
    private var activePlayers: [NSSound] = []

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
        for name in Self.systemSounds {
            if let s = NSSound(named: .init(name)) {
                cache[name] = s
            }
        }
    }

    /// Play the sound configured for the given event.
    @MainActor func play(for event: EventType) {
        guard settings.enableSound, !settings.muted else { return }
        let name = settings.soundName(for: event)
        playSound(name: name)
    }

    /// Preview a sound by name — keeps a strong reference so it plays to completion.
    @MainActor func preview(name: String) {
        playSound(name: name)
    }

    // MARK: - Private

    @MainActor private func playSound(name: String) {
        // Custom file
        if name == "__custom__", !settings.customSoundPath.isEmpty {
            if let s = NSSound(contentsOfFile: settings.customSoundPath, byReference: false) {
                s.delegate = playerDelegate
                activePlayers.append(s)
                s.play()
            }
            return
        }

        // Cached system sound: clone so concurrent calls don't cut each other off
        if let cached = cache[name], let clone = cached.copy() as? NSSound {
            clone.delegate = playerDelegate
            activePlayers.append(clone)
            clone.play()
        } else if let s = NSSound(named: .init(name)) {
            s.delegate = playerDelegate
            activePlayers.append(s)
            s.play()
        }
    }

    // Small helper to satisfy NSSoundDelegate (requires NSObject)
    private let playerDelegate = SoundDelegateHelper()
}

private final class SoundDelegateHelper: NSObject, NSSoundDelegate {
    func sound(_ sound: NSSound, didFinishPlaying finished: Bool) {
        // The SoundManager holds strong refs in activePlayers; nothing to do here.
    }
}
