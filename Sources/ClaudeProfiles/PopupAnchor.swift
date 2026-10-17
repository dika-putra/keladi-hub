import AppKit
import SwiftUI

// MenuBarExtra keeps the window's bottom edge when its content shrinks, which leaves a gap under the menu bar.
// Remember the top edge when the popup opens, size the window to its content and pin the top after every resize.
struct PopupAnchor: NSViewRepresentable {
    // Changes whenever the content size may change, so updateNSView re-fits the window.
    let trigger: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { context.coordinator.attach(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { context.coordinator.refit(view.window) }
    }

    final class Coordinator {
        private var top: CGFloat?
        private var tokens: [NSObjectProtocol] = []

        // The window can keep its old height after the content shrinks; size it to the content and re-pin the top.
        func refit(_ window: NSWindow?) {
            guard let window, let content = window.contentView else { return }
            let fit = content.fittingSize
            guard fit.height > 0 else { return }
            window.setContentSize(fit)
            if let top { window.setFrameTopLeftPoint(NSPoint(x: window.frame.minX, y: top)) }
        }

        func attach(_ window: NSWindow?) {
            guard let window, tokens.isEmpty else { return }
            top = window.frame.maxY
            let nc = NotificationCenter.default
            tokens.append(nc.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
                self?.top = window.frame.maxY
            })
            tokens.append(nc.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                guard let top = self?.top else { return }
                window.setFrameTopLeftPoint(NSPoint(x: window.frame.minX, y: top))
            })
        }
    }
}
