import AppKit
import SherlockMeCore
import SherlockMePlatform
import SwiftUI

/// What the app needs from macOS, and whether it has it. This app needs nothing yet, so the page holds only
/// the way back to the wizard.
///
/// TEMPLATE: a permission is one group here, and a state the user can fix is three things: the row
/// (`StatusRow`, green *Granted* or red *Denied*); while it is denied, a `ButtonRow` to the pane it is fixed
/// in and a warning naming the exact switch; once granted, the button and the warning go and the row stays,
/// so the link between the app and the permission stays visible. `status` follows the system while the
/// window is open. The `macos-building-settings-pages` skill has the rest.
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
