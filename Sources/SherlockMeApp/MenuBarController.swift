import AppKit
import Combine
import SherlockMeCore
import SherlockMePlatform

/// The menu-bar item and its menu. The menu is rebuilt from scratch on every open, so it is never a
/// language or a state behind, and the item's visibility follows the one setting that owns it.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    var store: SettingsStore?
    var openSettings: (() -> Void)?

    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []

    func setup() {
        guard let store else { return }
        apply(visible: store.settings.showInMenuBar)
        store.$settings
            .map(\.showInMenuBar)
            .removeDuplicates()
            .sink { [weak self] visible in MainActor.assumeIsolated { self?.apply(visible: visible) } }
            .store(in: &cancellables)
    }

    /// Releasing the item back to `NSStatusBar.system` is the whole of hiding it: an item merely hidden
    /// keeps its slot, and the icons to its left would not close up. Logged, because a hidden item is an
    /// app with no visible trace and the log is then the only place that says it is running on purpose.
    private func apply(visible: Bool) {
        if visible {
            guard statusItem == nil else { return }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = Self.icon()
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            statusItem = item
        } else {
            guard let item = statusItem else { return }
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
        Log.app.notice("menu bar item \(visible ? "shown" : "hidden", privacy: .public)")
    }

    // MARK: - The menu

    /// The family's order: the feature's own state first, a separator, Launch at Login, a separator, the
    /// read-only status lines, a separator, Settings…, a separator, Quit. SherlockMe has no switch of its
    /// own, so the first group is absent and its one status line says what it is doing.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let words = Loc.menu

        let login = NSMenuItem(title: words.launchAtLogin, action: #selector(toggleLaunchAtLogin),
                               keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        let status = NSMenuItem(title: words.status(TouchIDGuard.shared.status.watcher), action: nil,
                                keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: words.settings, action: #selector(openSettingsItem),
                                  keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: words.quit, action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        quit.target = NSApplication.shared
        menu.addItem(quit)
    }

    /// The system's answer is what the menu shows next time, so nothing is mirrored here. A refusal is
    /// logged rather than swallowed; the Settings window is where it gets a sentence.
    @objc private func toggleLaunchAtLogin() {
        do { try LoginItem.setEnabled(!LoginItem.isEnabled) }
        catch { Log.app.error("launch at login could not be changed: \(error.localizedDescription, privacy: .public)") }
    }

    @objc private func openSettingsItem() { openSettings?() }

    // MARK: - The mark

    /// The brand mark, drawn rather than shipped as an asset so that it rebuilds from source and follows
    /// the menu bar's own colour as a template image. It is the app icon's drawing on an 18 pt canvas.
    ///
    /// A magnifying glass over a fingerprint: a ring, a handle with a rounded end, one ridge that stops
    /// short of closing, and a dot. The numbers are those of `Resources/MenuBarMark.svg`, in its own
    /// top-left coordinates, which is why the image is flipped; its paths are these circles cut into
    /// straight segments. The ring's hole is a second circle cut out by the even-odd rule.
    static func icon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.setFill()
            NSColor.black.setStroke()
            let lens = NSPoint(x: 8.2, y: 8.2)
            let ring = NSBezierPath()
            ring.windingRule = .evenOdd
            ring.appendOval(in: NSRect(x: lens.x - 6.6, y: lens.y - 6.6, width: 13.2, height: 13.2))
            ring.appendOval(in: NSRect(x: lens.x - 5.2, y: lens.y - 5.2, width: 10.4, height: 10.4))
            ring.fill()
            // The handle leaves the ring from the middle of its band, square, so no cap reaches into the
            // lens; its rounded end is a circle of its own width.
            let tip = NSPoint(x: 16.33, y: 16.33)
            let handle = NSBezierPath()
            handle.move(to: NSPoint(x: lens.x + 5.9 / 2.squareRoot(), y: lens.y + 5.9 / 2.squareRoot()))
            handle.line(to: tip)
            handle.lineWidth = 2.6
            handle.stroke()
            NSBezierPath(ovalIn: NSRect(x: tip.x - 1.3, y: tip.y - 1.3, width: 2.6, height: 2.6)).fill()
            // The ridge runs the long way round, through the bottom, and leaves its gap at the upper right.
            let ridge = NSBezierPath()
            ridge.appendArc(withCenter: NSPoint(x: 8.19, y: 8.24), radius: 2.96,
                            startAngle: -34.9, endAngle: 284.7, clockwise: false)
            ridge.lineWidth = 1.2
            ridge.lineCapStyle = .round
            ridge.stroke()
            NSBezierPath(ovalIn: NSRect(x: 8.19 - 0.8, y: 8.15 - 0.8, width: 1.6, height: 1.6)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = AppIdentity.name
        return image
    }
}
