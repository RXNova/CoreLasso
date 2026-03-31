import AppKit

// Without an .app bundle, macOS defaults to registering SPM executables as
// BackgroundOnly, which suppresses all windows. Setting .regular here — before
// SwiftUI's run-loop starts — tells the WindowServer to treat this process as a
// normal foreground application so windows appear as expected.
NSApplication.shared.setActivationPolicy(.regular)

CoreLassoApp.main()
