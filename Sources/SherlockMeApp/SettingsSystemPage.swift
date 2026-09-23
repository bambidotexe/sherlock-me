import AppKit
import SherlockMeCore
import SherlockMePlatform
import SwiftUI

/// What the app needs from macOS, and whether it has it. SherlockMe asks for no permission, so the page holds
/// only the way back to the wizard. An account that cannot read the log is not here either: nothing in the
/// app can change that, and a state with nothing to press beside it goes on Health (the
/// `macos-building-settings-pages` skill).
struct SystemPage: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var status: SystemStatus

    var body: some View {
        let words = Loc.settings.system
        SettingsPage {
            // The wizard is the one place that explains the app and what it asks for together, so it stays
            // reachable after the first run. A fresh one is built each time, starting at page one.
            SettingsGroup(title: words.startOverTitle) {
                ButtonRow {
                    Button(words.showOnboardingButton) {
                        (NSApp.delegate as? AppDelegate)?.showOnboarding()
                    }
                }
            }
        }
    }
}
