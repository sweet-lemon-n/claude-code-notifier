import AppKit
import SwiftUI

/// Central app delegate — initializes all managers, sets up the menu bar,
/// and routes incoming IPC events to notifications + sounds.
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    // Managers
    private var settingsStore: SettingsStore!
    private var vscodeManager: VSCodeManager!
    private var soundManager: SoundManager!
    private var notificationManager: NotificationManager!
    private var ipcServer: IPCServer!
    private var hookManager: HookManager!

    // UI
    private var statusItem: NSStatusItem!
    private var popupWindow: NSPanel?
    private var mainWindow: NSWindow?
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
        hookManager = HookManager()

        // Wire notification click → activate VSCode
        notificationManager.onNotificationClicked = { [weak self] path in
            self?.vscodeManager.activateProject(path: path)
        }

        // Request notification permission
        notificationManager.requestPermission()

        // 3. Setup menu bar
        setupMenuBar()

        // 4. Show the foreground app window. Closing it keeps the menu bar
        //    service running in the background.
        openMainWindow()
        settingsStore.hasCompletedSetup = true

        // 5. Start IPC server
        ipcServer = IPCServer { [weak self] eventType, payload in
            self?.handleIncomingEvent(type: eventType, payload: payload)
        }
        ipcServer?.start()
        hookManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hookManager?.stop()
        ipcServer?.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        openMainWindow()
        return true
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
            onOpenMainWindow: { [weak self] in self?.openMainWindow() },
            onOpenSettings: { [weak self] in self?.openSettings() },
            onToggleMute: { [weak self] in
                DispatchQueue.main.async {
                    self?.settingsStore.muted.toggle()
                }
            },
            onOpenProject: { [weak self] path in
                self?.vscodeManager.activateProject(path: path)
            },
            onQuit: { [weak self] in self?.terminate() }
        )
        self.menuBarView = menuView

    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popup = popupWindow, popup.isVisible {
            popup.close()
            popupWindow = nil
            eventMonitor = nil
        } else {
            showPopup(relativeTo: button)
        }
    }

    private func showPopup(relativeTo button: NSStatusBarButton) {
        // Convert the button's frame to screen coordinates.
        guard let buttonWindow = button.window else { return }
        let buttonScreenFrame = buttonWindow.convertToScreen(button.frame)

        let panelWidth: CGFloat = 270
        let panelHeight: CGFloat = 320
        let gap: CGFloat = 2  // small gap below menu bar

        // Center the panel horizontally under the button
        let x = buttonScreenFrame.midX - panelWidth / 2
        let y = buttonScreenFrame.minY - panelHeight - gap

        // Clamp to screen bounds
        let screen = buttonWindow.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame
        let clampedX = max(screenFrame.minX + 8,
                           min(x, screenFrame.maxX - panelWidth - 8))
        let clampedY = max(screenFrame.minY,
                           min(y, screenFrame.maxY - panelHeight))

        let contentRect = NSRect(x: clampedX, y: clampedY,
                                  width: panelWidth, height: panelHeight)

        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, NSWindow.StyleMask.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.hasShadow = true
        panel.level = NSWindow.Level.popUpMenu
        panel.collectionBehavior = [NSWindow.CollectionBehavior.transient,
                                     NSWindow.CollectionBehavior.ignoresCycle]
        panel.isReleasedWhenClosed = false

        // Visual effect backdrop (native macOS frosted glass)
        let visualEffect = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentRect.size))
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 10
        visualEffect.layer?.masksToBounds = true

        let hostingView = NSHostingView(rootView: menuBarView!)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])

        panel.contentView = visualEffect

        popupWindow = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Dismiss on click outside (global event monitor)
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            if let panel = self?.popupWindow, panel.isVisible {
                panel.close()
                self?.popupWindow = nil
                self?.eventMonitor = nil
            }
        }
    }

    // MARK: - Settings Window

    func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let existing = mainWindow {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.menuTitle
        window.contentView = NSHostingView(
            rootView: MainWindowView(
                settings: settingsStore,
                notificationManager: notificationManager,
                onOpenProject: { [weak self] path in
                    self?.vscodeManager.activateProject(path: path)
                },
                onOpenSettings: { [weak self] in self?.openSettings() },
                onToggleMute: { [weak self] in
                    DispatchQueue.main.async {
                        self?.settingsStore.muted.toggle()
                    }
                }
            )
        )
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        mainWindow = window
    }

    func openSettings() {
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
        window.title = L10n.settingsWindowTitle
        window.contentView = NSHostingView(
            rootView: SettingsView(settings: settingsStore)
        )
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)

        self.settingsWindow = window
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === mainWindow {
            sender.orderOut(nil)
            return false
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === settingsWindow {
            settingsWindow = nil
        }
    }

    // MARK: - Quit

    private func terminate() {
        ipcServer?.stop()
        NSApp.terminate(nil)
    }
}
