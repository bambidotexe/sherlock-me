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
    /// read-only status lines, a separator, Settings…, a separator, Quit. This app has no feature yet, so
    /// the first two groups are absent.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let words = Loc.menu

        // TEMPLATE: the feature's own switch and state go first, then a separator, then a read-only line
        // saying what the app is doing right now (`isEnabled = false`), then a separator.

        let login = NSMenuItem(title: words.launchAtLogin, action: #selector(toggleLaunchAtLogin),
                               keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)
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
    /// the menu bar's own colour as a template image. It is the same drawing as the app icon's
    /// (`Resources/AppIcon.icon/Assets/mark.svg`), fitted to an 18 pt canvas.
    ///
    /// TEMPLATE: a placeholder, a rounded outline with a dot at its centre. Draw the app's own mark here
    /// and in the SVG, so the two agree.
    static func icon() -> NSImage {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let stroke: CGFloat = 1.2
            let outline = NSRect(x: 2.5, y: 2.5, width: 13, height: 13).insetBy(dx: stroke / 2, dy: stroke / 2)
            let path = NSBezierPath(roundedRect: outline, xRadius: 3.2, yRadius: 3.2)
            path.lineWidth = stroke
            NSColor.black.setStroke()
            path.stroke()
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 6.5, y: 6.5, width: 5, height: 5)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = AppIdentity.name
        return image
    }
}
