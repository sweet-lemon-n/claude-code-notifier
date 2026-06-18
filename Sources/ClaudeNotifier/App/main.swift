import AppKit

// Hide from Dock and Cmd+Tab immediately.
// Must reference the shared application first to initialize NSApp.
let application = NSApplication.shared
application.setActivationPolicy(.accessory)

let appDelegate = AppDelegate()
application.delegate = appDelegate
application.run()
