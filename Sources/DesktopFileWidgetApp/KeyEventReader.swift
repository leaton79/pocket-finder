import AppKit
import SwiftUI

struct KeyEventReader: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Void
    let onNavigateBack: () -> Void
    let onNavigateForward: () -> Void

    func makeNSView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.onKeyDown = onKeyDown
        view.onNavigateBack = onNavigateBack
        view.onNavigateForward = onNavigateForward
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: KeyCatcherView, context: Context) {
        nsView.onKeyDown = onKeyDown
        nsView.onNavigateBack = onNavigateBack
        nsView.onNavigateForward = onNavigateForward
        DispatchQueue.main.async {
            if nsView.window?.firstResponder == nil {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

final class KeyCatcherView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?
    var onNavigateBack: (() -> Void)?
    var onNavigateForward: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }

    override func otherMouseDown(with event: NSEvent) {
        switch event.buttonNumber {
        case 3:
            onNavigateBack?()
        case 4:
            onNavigateForward?()
        default:
            super.otherMouseDown(with: event)
        }
    }
}
