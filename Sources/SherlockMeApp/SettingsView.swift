import AppKit
import SherlockMeCore
import SherlockMePlatform
import SwiftUI

/// The app's settings, one page per subject, picked from the window's toolbar. Every page is a column of
/// groups built from the kit in `SettingsKit.swift`: a title, a card of rows, and under the card its hint,
/// its warnings and its notes.
///
/// Every control writes straight through `SettingsStore`, which persists on `didSet`, so there is no Apply
/// button and no local copy to get out of step.
struct SettingsView: View {
    @ObservedObject var selection: SettingsSelection
    @ObservedObject var store: SettingsStore
    @ObservedObject var status: SystemStatus
    let health: HealthCheck

    var body: some View {
        // The page scrolls because the window's height is capped to what fits on the screen: on a short
        // display a long page is scrolled rather than cut off.
        ScrollView(.vertical) {
            page
                .frame(width: SettingsMetrics.contentWidth, alignment: .topLeading)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: SettingsPageHeight.self, value: proxy.size.height)
                    }
                }
        }
        .frame(width: SettingsMetrics.contentWidth)
        .onPreferenceChange(SettingsPageHeight.self) { [selection] height in
            // Preferences are delivered while SwiftUI updates, which is on the main actor.
            MainActor.assumeIsolated { selection.pageHeightChanged?(height) }
        }
    }

    @ViewBuilder private var page: some View {
        switch selection.page {
        case .general: GeneralPage(store: store, status: status)
        case .system: SystemPage(store: store, status: status)
        case .health: HealthPage(status: status, health: health)
        case .tip: TipPage()
        }
    }
}

/// The pages, in toolbar order. The raw value is the toolbar item's identifier, so the toolbar and the
/// selection cannot disagree about which page a click means.
///
/// General first, then the features in the order a user meets them, then what the app needs from the
/// system, then its health, then the tip jar last. SherlockMe has no setting of its own, so it has no
/// feature page; one would go between `general` and `system`.
enum SettingsPageID: String, CaseIterable, Sendable {
    case general, system, health, tip

    /// The toolbar item's label, and the window's title while the page is shown.
    var title: String {
        switch self {
        case .general: Loc.settings.pageGeneral
        case .system: Loc.settings.pageSystem
        case .health: Loc.settings.pageHealth
        case .tip: Loc.settings.pageTip
        }
    }

    /// The SF Symbol drawn above the title, in the outline style the system's own settings toolbars use.
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .system: "checkmark.shield"
        case .health: "stethoscope"
        case .tip: "mug"
        }
    }
}

/// What the window and its one SwiftUI root share: which page is shown, set by the toolbar, and where the
/// page's measured height goes, set by the window.
@MainActor
final class SettingsSelection: ObservableObject {
    @Published var page: SettingsPageID = .general
    /// Called with the shown page's natural height whenever it changes: on a page switch, and when a page
    /// gains or loses a line of its own.
    var pageHeightChanged: ((CGFloat) -> Void)?
}

/// How tall the shown page wants to be, read from behind the page.
struct SettingsPageHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - The system state the window shows

/// The facts this window reports but does not own: whether the app is registered as a login item, and, in an
/// app that needs one, whether a permission is granted. Both can change while the window is shut, and neither
/// lives in `Settings`.
///
/// **The window drives this, not a view.** `.onAppear` fires once per hosting view, and this window is
/// built once and re-shown, so a view-lifecycle hook would read the system exactly one time in the life of
/// the process. Nor is it a `TimelineView(.periodic:)`: nothing documents such a schedule stopping for a
/// window that is merely ordered out.
///
/// Every property is published only when it actually changes, so an open window that is watching nothing
/// costs one read every two seconds and no SwiftUI invalidation at all.
@MainActor
final class SystemStatus: ObservableObject {
    /// What `SMAppService` says, including the one state the General page's switch cannot show: registered,
    /// then switched off in System Settings. The Health page reports that one.
    @Published private(set) var loginItem: LoginItemState

    /// The General page's switch: on only while the system would open the app at login.
    var launchAtLogin: Bool { loginItem == .enabled }

    private var timer: Timer?

    init() {
        loginItem = LoginItem.state
    }

    func startPolling() {
        refresh()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: K.systemPollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        Log.app.debug("settings: system status poll started")
    }

    func stopPolling() {
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
        Log.app.debug("settings: system status poll stopped")
    }

    /// Re-reads the login item alone, after an attempt to change it. Always read back rather than assumed:
    /// `register()` can fail, and a switch showing what the click asked for over a system that refused it
    /// is the worse of the two lies.
    func refreshLoginItem() {
        let state = LoginItem.state
        if state != loginItem { loginItem = state }
    }

    /// Everything, now, rather than at the next tick: the Health page's Check Again.
    func refresh() {
        refreshLoginItem()
    }
}
