import AppKit
import Combine
import SherlockMeCore
import SherlockMePlatform

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = SettingsStore()
    private let menuBar = MenuBarController()

    private var settingsWindow: SettingsWindow?
    private var onboarding: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Read before anything else can spend the event: `currentAppleEvent` is the launch's own, and only
        // until the first one the app handles itself. A reinstall opens the bundle as well, and the window
        // that got was one nobody asked for; the installer says so with a marker, which this reads once and
        // removes. An update writes that marker too, and says so a second way as well: while its outcome is
        // unread, this launch is the install helper's rather than a person's.
        let openedByHand = !launchedAsLoginItem() && !QuietLaunch.consume()
            && !UpdateController.shared.outcomeIsWaiting

        installMainMenu()
        menuBar.store = store
        menuBar.openSettings = { [weak self] in self?.showSettings() }
        menuBar.setup()

        // TEMPLATE: start the app's own behaviour here, in the layer that owns it. Nothing here may ask
        // macOS for a permission: the wizard's own button is the only thing in the app that does, because a
        // prompt nobody clicked for arrives with no explanation beside it and macOS remembers a refusal for
        // good (the macos-building-onboarding skill).

        // The wizard on a first run the person started. A login item whose onboarding was simply never
        // finished still opens no window. An app that cannot work without a permission also opens the wizard
        // on any launch that finds the permission missing, however the app was launched.
        if openedByHand && !store.settings.onboardingCompleted {
            showOnboarding()
        } else if openedByHand {
            showSettings()
        }
        startUpdates()
        Log.app.notice("\(AppIdentity.name, privacy: .public) \(AppIdentity.version, privacy: .public) launched")
    }

    /// Reached by every quit, the menu's, the Settings button's and the update's alike, because all three go
    /// through `NSApplication.terminate`. TEMPLATE: put back here anything the app changed on the Mac that
    /// must not outlive it.
    func applicationWillTerminate(_ notification: Notification) {
        Log.app.notice("\(AppIdentity.name, privacy: .public) quit")
    }

    /// The one way back into Settings once the icon is hidden: opening the bundle again from the
    /// Applications folder or Spotlight while the app is already running fires this rather than
    /// `applicationDidFinishLaunching`. **The wizard takes precedence while it is up**, and this asks the same
    /// question a launch does, so a wizard that has not been walked is what opening the app brings up. A
    /// reinstall launches quietly and opens no window, so this is the first thing a person does afterwards,
    /// and it must not be the one path that skips the wizard. With no Dock icon, `open -b` is the only way the
    /// user fetches a window back. A login item cannot arrive here: it launches a process that is not running
    /// yet.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if onboarding?.isUp == true {
            onboarding?.show()
        } else if store.settings.onboardingCompleted {
            showSettings()
        } else {
            showOnboarding()
        }
        return true
    }

    // MARK: - Windows

    /// Built on first use and kept: the window is cheap to hold, and re-showing the one the user closed
    /// keeps whatever page they were on.
    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(store: store,
                                            othersNeedUsActive: { [weak self] in
                                                self?.onboarding?.isUp == true
                                                    || UpdateController.shared.windowIsUp
                                            })
        }
        settingsWindow?.show()
    }

    /// **A fresh controller every time**, so every row re-reads its state and the walk starts at page one.
    /// The one already on screen is brought forward instead, rather than replaced under the user.
    ///
    /// `grantMayHaveChanged` is where an app that needs a permission starts or stops its behaviour as the
    /// grant comes and goes; it is called on every poll tick of the wizard and whenever a row's flow ends.
    /// This app needs none, so it is told nothing.
    func showOnboarding() {
        if onboarding?.isUp == true {
            onboarding?.show()
            return
        }
        let controller = OnboardingWindowController.make(
            store: store,
            onFinish: { [weak self] in self?.store.settings.onboardingCompleted = true },
            grantMayHaveChanged: {})
        controller.othersNeedUsActive = { [weak self] in
            self?.settingsWindow?.isUp == true || UpdateController.shared.windowIsUp
        }
        onboarding = controller
        controller.show()
    }

    /// An accessory application never shows a menu bar of its own, so nothing here is ever seen. It exists
    /// for its key equivalents alone: ⌘Q and ⌘W reach a window only through the main menu, and the Settings
    /// window, the onboarding window and the update window are all ordinary key windows.
    private func installMainMenu() {
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: Loc.menu.quit, action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: Loc.mainMenu.window)
        windowMenu.addItem(withTitle: Loc.mainMenu.close, action: #selector(NSWindow.performClose(_:)),
                           keyEquivalent: "w")
        windowMenu.addItem(withTitle: Loc.mainMenu.minimize, action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")
        windowItem.submenu = windowMenu

        let main = NSMenu()
        main.addItem(appItem)
        main.addItem(windowItem)
        NSApplication.shared.mainMenu = main
    }

    /// Whether macOS started the app as a login item rather than a person opening it.
    ///
    /// The open-application Apple event carries `keyAELaunchedAsLogInItem` under `keyAEPropData` when
    /// `SMAppService` is what launched us, and carries nothing there when the Finder, Spotlight or `open`
    /// did. The absent case therefore reads as opened by hand, which is the safe way round: an event this
    /// cannot recognise shows the Settings window rather than swallowing the one route back in when the
    /// menu-bar icon is hidden.
    private func launchedAsLoginItem() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == AEEventID(kAEOpenApplication) else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    // MARK: - Updates

    /// Last, so the launch that follows an Install and Relaunch finds the rest of the app in place when it
    /// opens the window that says how the install ended.
    private func startUpdates() {
        let updates = UpdateController.shared
        updates.onShowSettings = { [weak self] in self?.showSettings() }
        updates.othersNeedUsActive = { [weak self] in
            self?.settingsWindow?.isUp == true || self?.onboarding?.isUp == true
        }
        updates.start()
    }
}
