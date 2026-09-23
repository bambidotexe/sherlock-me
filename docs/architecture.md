# SherlockMe — how it is built

## Three targets, dependencies pointing one way

```
SherlockMeCore  ←  SherlockMePlatform  ←  SherlockMeApp
                                  ←  Tools/axprobe (its own, imports nothing of the app's)
```

- **`SherlockMeCore`** imports **Foundation and CoreGraphics and nothing else**, and never reads a clock:
  `now` is always passed in. `PurityTests` fails the build otherwise. Everything here is a value in and a
  value out, which is what lets every rule be tested with no Mac in the state it describes.
- **`SherlockMePlatform`** is the only code that talks to the system. Nothing above it opens a URL, reads a
  file outside the bundle, or asks the system a question.
- **`SherlockMeApp`** owns the run loop, the windows and the wiring.
- **`Tools/axprobe`** never ships. `scripts/make-app.sh` copies one executable into the bundle and this is
  not it.

### What lives where

| Layer | Files | What they own |
|---|---|---|
| Core | TEMPLATE: the feature's rules | Values in, a decision out. |
| | `Settings`, `Constants` (`K`), `AppIdentity`, `Paths`, `QuietLaunch`, `SupportLink` | The values the rest of the app is built on. |
| | `UpdateCheck`, `UpdateSchedule`, `UpdatePanel`, `UpdateSession`, `StagedUpdateCheck`, `UpdateInstallScript` | Every rule of the update that does not need a network or a disk. |
| | `UninstallPlan` | What an uninstall removes, and the text of the helper that finishes it. |
| | `Health`, `HealthRules`, `HealthReport` | The Health page's two tables (checks, readings) from plain facts, and the one colour rule every page's states follow. |
| | `Localization`, `Strings*` | Every sentence the user reads, in both languages. |
| Platform | TEMPLATE: the one call that touches the system for the feature | |
| | `LoginItem`, `SettingsStore`, `Log` | The rest of the system boundary. |
| | `CrashReports`, `ProcessStats` | What the Health page reads about the app itself: its crash reports, its age and memory. |
| | `UpdateChecker` + `UpdateDownload`, `UpdateStager`, `CodeSignature`, `UpdateInstaller`, `DetachedProcess` | The update's I/O. The only network code in the app. |
| | `Uninstall` | The registrations an uninstall gives back. |
| App | `SherlockMeMain`, `AppDelegate`, `MenuBarController` | The app, and TEMPLATE: the one object that decides the behaviour. |
| | `OnboardingWindow` + `GrantCatalogue` + `ControlActionHandler`, `SettingsKit`, `SettingsWindow`, `SettingsView`, `Settings…Page`, `HealthCheck` | The windows. The wizard is the one hand-built AppKit window; everything else is SwiftUI in a hosting controller. |
| | `UpdateController`, `UpdateNotifier`, `UpdateWindow` | The update's one owner and its two surfaces. |

## Threading

- Everything is on the **main actor**: the windows, the settings store, the wiring. TEMPLATE: a feature
  that must answer fast, or that blocks, gets a queue of its own and says so here.
- **Two exceptions, both in the update.** `URLSession` calls its delegate on its own queue and the caller
  hops; unpacking a disk image runs on one serial queue of its own, because it mounts, copies and verifies,
  and two of those at once would share a mount point.
- **Nothing polls while idle.** With no window open, the only timer armed is the update schedule's, which is
  coarse (`K.updateTick`) and tolerant. The Settings window starts and stops its own two-second poll; the
  onboarding wizard starts and stops the other, also two seconds.

## Persistence

| What | Where |
|---|---|
| The switches, and whether the wizard has been walked | one JSON blob in `UserDefaults`, key `settings.v1` |
| Launch at login | `SMAppService`, and nowhere else: the system's answer is the only one |
| The quiet-launch marker, the update's working folder | `~/Library/Application Support/SherlockMe` |

## Build and signing

`scripts/make-app.sh` assembles `build/SherlockMe.app`: the release binary, `Assets.car` compiled by
`actool` from `Resources/AppIcon.icon`, a flat `.icns` rasterised from the 1024 px master, two `.lproj`
directories so the app appears in Language & Region's per-app list, a generated `Info.plist`, and one
`codesign` with `--options runtime --timestamp`. There is nothing nested to sign.

**The app's name, its bundle identifier and its GitHub repository are written once**, in
`scripts/signing.env`. `make-app.sh` puts all three into the built `Info.plist` — the repository as a
private `AppUpdateRepository` key — and `Core/AppIdentity` reads them back, so the running app never spells
its own name out.

`scripts/release.sh` is the shippable build in the order Apple's checks need: build → verify the signature,
the runtime flag and the entitlements → notarize the app → staple → disk image → sign and notarize the
image → staple → `spctl` on both. It publishes nothing.

`scripts/install.sh` and `scripts/publish.sh` are **the only two ways a build reaches a Mac**, and neither
leaves an `.app` or a `.dmg` anywhere under the repository on any exit path. The whole pipeline is described
once for the family in `docs/shared/conventions.md`.

## The update, end to end

1. `UpdateController` is the one owner. It holds the schedule, the panel the Settings group draws, the
   session the window draws, and the outcome of the last install.
2. A check is `UpdateChecker.check`; what the answer means is `Core/UpdateCheck`.
3. Update opens `UpdateWindow`, which fetches through `UpdateDownload` — held against the length and
   SHA-256 GitHub stated — then `UpdateStager` mounts the image, copies the app out and checks it against
   `StagedUpdateCheck` and `CodeSignature`. **Everything that can refuse an update runs while the app is
   still up.**
4. Install and Relaunch writes `UpdateInstallScript.text` next to the update, starts it through
   `DetachedProcess` in a process group of its own, and quits. The helper waits for the pid, swaps two
   folders, opens the new copy, and puts the old one back if the new version is not seen running.
5. The helper leaves one line behind. The next launch reads it, renames it to `<result>.read` — which is
   how the helper knows a version that is gone again two seconds later had started properly — and opens the
   window that says how it ended.
