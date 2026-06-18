import AppKit
import SwiftUI

/// Central app delegate — initializes all managers, sets up the menu bar,
/// and routes incoming IPC events to notifications + sounds.
final class AppDelegate: NSObject, NSApplicationDelegate {

    // Managers
    private var settingsStore: SettingsStore!
    private var vscodeManager: VSCodeManager!
    private var soundManager: SoundManager!
    private var notificationManager: NotificationManager!
    private var ipcServer: IPCServer!

    // UI
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var eventMonitor: Any?
    private var menuBarView: MenuBarView?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Settings (must come first)
        settingsStore = SettingsStore.shared

        // 2. Core managers
        vscodeManager = VSCodeManager()
        soundManager = SoundManager(settings: settingsStore)
        notificationManager = NotificationManager(settings: settingsStore)

        // Wire notification click → activate VSCode
        notificationManager.onNotificationClicked = { [weak self] projectPath in
            self?.vscodeManager.activateProject(path: projectPath)
        }

        // 3. Request notification permission
        notificationManager.requestPermission()

        // 4. Setup menu bar
        setupMenuBar()

        // 5. Start IPC server
        ipcServer = IPCServer { [weak self] eventType, payload in
            self?.handleIncomingEvent(type: eventType, payload: payload)
        }
        ipcServer?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ipcServer?.stop()
    }

    // MARK: - Event handling

    private func handleIncomingEvent(type: EventType, payload: HookPayload) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.soundManager.play(for: type)
            self.notificationManager.send(eventType: type, payload: payload)
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use SF Symbol as the menu bar icon — always crisp, adapts to theme
            let image = NSImage(
                systemSymbolName: "bell.badge.fill",
                accessibilityDescription: "Claude Notifier"
            )
            // Pick a size that fits well in the menu bar
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = image?.withSymbolConfiguration(config)
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Build the SwiftUI popover content
        let menuView = MenuBarView(
            settings: settingsStore,
            notificationManager: notificationManager,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onToggleMute: { [weak self] in
                DispatchQueue.main.async {
                    self?.settingsStore.muted.toggle()
                }
            },
            onQuit: { [weak self] in self?.terminate() }
        )
        self.menuBarView = menuView

        popover = NSPopover()
        popover.contentSize = NSSize(width: 270, height: 320)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: menuView)
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            eventMonitor = nil
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            // Close when clicking outside
            eventMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] event in
                if self?.popover.isShown == true {
                    self?.popover.performClose(nil)
                    self?.eventMonitor = nil
                }
            }
        }
    }

    // MARK: - Settings Window

    func openSettings() {
        // Activate app first so the window gets proper focus
        NSApp.activate(ignoringOtherApps: true)

        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Claude Notifier Settings"
        window.contentView = NSHostingView(
            rootView: SettingsView(settings: settingsStore)
        )
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.settingsWindow = window
    }

    // MARK: - Quit

    private func terminate() {
        ipcServer?.stop()
        NSApp.terminate(nil)
    }
}
