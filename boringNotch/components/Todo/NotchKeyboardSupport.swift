//
//  NotchKeyboardSupport.swift
//  boringNotch
//
//  Lets a text field inside the (normally non-key) notch panel receive
//  keyboard input, and keeps the notch open only while that input is active.
//

import AppKit
import SwiftUI

/// A notch panel that can temporarily accept key status.
protocol KeyboardAcceptingPanel: NSWindow {
    var acceptsKeyboard: Bool { get set }
}

/// Holds the notch open via `SharingStateManager` while active.
/// Releases on `end()` or, as a safety net, when deallocated
/// (e.g. the hosting window is torn down on a display change).
@MainActor
final class NotchOpenHold {
    private var active = false

    func begin() {
        guard !active else { return }
        active = true
        SharingStateManager.shared.beginInteraction()
    }

    func end() {
        guard active else { return }
        active = false
        SharingStateManager.shared.endInteraction()
    }

    deinit {
        guard active else { return }
        Task { @MainActor in SharingStateManager.shared.endInteraction() }
    }
}

/// Reports the `NSWindow` hosting a SwiftUI view.
struct HostingWindowReader: NSViewRepresentable {
    var onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowReportingView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowReportingView)?.onWindow = onWindow
    }

    private final class WindowReportingView: NSView {
        var onWindow: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow?(window)
        }
    }
}
