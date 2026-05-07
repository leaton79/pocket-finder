import AppKit
import DesktopFileWidgetCore
import SwiftUI

@main
struct DesktopFileWidgetMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = DesktopFileWidgetAppDelegate()
        app.delegate = delegate
        AppDelegateHolder.shared.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegateHolder {
    static let shared = AppDelegateHolder()
    var delegate: DesktopFileWidgetAppDelegate?
}

@MainActor
final class DesktopFileWidgetAppDelegate: NSObject, NSApplicationDelegate {
    private var panels: [NSScreen: NSPanel] = [:]
    private let sharedState = SharedExplorerState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        rebuildPanels()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersDidChange() {
        rebuildPanels()
    }

    private func rebuildPanels() {
        panels.values.forEach { $0.close() }
        panels.removeAll()

        for screen in NSScreen.screens {
            let panel = makePanel(for: screen)
            panels[screen] = panel
            panel.orderBack(nil)
        }
    }

    private func makePanel(for screen: NSScreen) -> NSPanel {
        let frame = Self.defaultFrame(for: screen)
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        panel.title = "Desktop File Widget"
        let desktopLevel = CGWindowLevelForKey(.desktopWindow)
        panel.level = NSWindow.Level(rawValue: Int(desktopLevel))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isFloatingPanel = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.minSize = frame.size
        panel.maxSize = frame.size
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false

        let viewModel = ExplorerViewModel(sharedState: sharedState)
        let root = ExplorerWidgetView(viewModel: viewModel)
        let host = NSHostingController(rootView: root)
        panel.contentViewController = host
        panel.setFrame(frame, display: true)
        panel.orderBack(nil)
        return panel
    }

    private static func defaultFrame(for screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        return NSRect(
            x: visible.minX,
            y: visible.minY,
            width: visible.width * 0.625,
            height: visible.height * 0.78125
        )
    }
}
