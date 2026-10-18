import SwiftUI

@main
struct ClaudeProfilesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

private final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
    var onResignKey: (() -> Void)?
    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

// Own panel under the status item instead of MenuBarExtra/NSPopover: both re-anchored wrongly when the content size changed.
// The anchor is read once, when the icon is clicked, and every resize is positioned from it.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = Store()
    private let panel = Panel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let host: NSHostingController<AnyView>
    private var item: NSStatusItem?
    private var anchor: NSRect?
    private var anchorScreen: NSScreen?
    private var lastHidden = Date.distantPast
    private var sizeObserver: NSKeyValueObservation?

    override init() {
        host = NSHostingController(rootView: AnyView(EmptyView()))
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "person.2.circle", accessibilityDescription: "Claude Profiles")
        item.button?.target = self
        item.button?.action = #selector(toggle)
        self.item = item

        host.rootView = AnyView(ContentView(close: { [weak self] in self?.hide() }).environmentObject(store))
        host.sizingOptions = .preferredContentSize

        let background = NSVisualEffectView()
        background.material = .popover
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true
        host.view.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: background.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        panel.contentView = background
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.onResignKey = { [weak self] in self?.hide() }

        sizeObserver = host.observe(\.preferredContentSize, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.resize() }
        }
    }

    @objc private func toggle() {
        // Clicking the icon while the panel is open first resigns key (hide), then lands here; do not reopen it.
        if panel.isVisible || Date().timeIntervalSince(lastHidden) < 0.25 {
            hide()
            return
        }
        guard let window = item?.button?.window else { return }
        anchor = window.frame
        anchorScreen = window.screen
        store.refreshRunning()
        resize()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        lastHidden = Date()
    }

    private func resize() {
        let size = host.preferredContentSize
        guard size.width > 0, size.height > 0, let anchor else { return }
        panel.setContentSize(size)
        var x = anchor.midX - size.width / 2
        if let visible = anchorScreen?.visibleFrame {
            x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: anchor.minY - size.height - 4))
    }
}
