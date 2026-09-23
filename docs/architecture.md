# SherlockMe — how it is built

## Three targets, dependencies pointing one way

```
SherlockMeCore  ←  SherlockMePlatform  ←  SherlockMeApp
                                  ←  Tools/axprobe, Tools/touchprobe (their own, import nothing of the app's)
```

- **`SherlockMeCore`** imports **Foundation and CoreGraphics and nothing else**, and never reads a clock:
  `now` is always passed in. `PurityTests` fails the build otherwise. Everything here is a value in and a
  value out, which is what lets every rule be tested with no Mac in the state it describes.
- **`SherlockMePlatform`** is the only code that talks to the system. Nothing above it opens a URL, reads a
  file outside the bundle, or asks the system a question.
- **`SherlockMeApp`** owns the run loop, the windows and the wiring.
- **`Tools/axprobe`** and **`Tools/touchprobe`** never ship. `scripts/make-app.sh` copies one executable into
  the bundle, and neither is it.

### What lives where

| Layer | Files | What they own |
|---|---|---|
| Core | `TouchIDLog`, `LockRule`, `Watcher` | The feature: the lines SherlockMe reads and what each means, the rule that turns them into a lock or a relock, when a stream that ended starts again. Values in, a decision out. |
| | `Settings`, `Constants` (`K`), `AppIdentity`, `Paths`, `QuietLaunch`, `SupportLink` | The values the rest of the app is built on. |
| | `UpdateCheck`, `UpdateSchedule`, `UpdatePanel`, `UpdateSession`, `StagedUpdateCheck`, `UpdateInstallScript` | Every rule of the update that does not need a network or a disk. |
| | `UninstallPlan` | What an uninstall removes, and the text of the helper that finishes it. |
| | `Health`, `HealthRules`, `HealthReport` | The Health page's two tables (checks, readings) from plain facts, and the one colour rule every page's states follow. |
| | `Localization`, `Strings*` | Every sentence the user reads, in both languages. |
| Platform | `TouchIDLogStream`, `SessionAgent`, `LoginSession` | The feature's system boundary: the `log stream` child, loginwindow's immediate lock through the private login.framework, whether the screen is locked and whether the user is an administrator. |
| | `LoginItem`, `SettingsStore`, `Log` | The rest of the system boundary. |
| | `CrashReports` | What the Health page reads about the app itself: its crash reports. |
| | `UpdateChecker` + `UpdateDownload`, `UpdateStager`, `CodeSignature`, `UpdateInstaller`, `DetachedProcess` | The update's I/O. The only network code in the app. |
| | `Uninstall` | The registrations an uninstall gives back. |
| App | `SherlockMeMain`, `AppDelegate`, `MenuBarController`, `TouchIDGuard` | The app, and the one object that runs the behaviour: the stream's lines into the rule, the rule's actions out. |
| | `OnboardingWindow` + `GrantCatalogue` + `ControlActionHandler`, `SettingsKit`, `SettingsWindow`, `SettingsView`, `Settings…Page`, `HealthCheck` | The windows. The wizard is the one hand-built AppKit window; everything else is SwiftUI in a hosting controller. |
| | `UpdateController`, `UpdateNotifier`, `UpdateWindow` | The update's one owner and its two surfaces. |

## Threading

- Everything is on the **main actor**: the windows, the settings store, the wiring, **except the Touch ID
  key**. `TouchIDGuard` runs on one serial queue of its own (`<bundle identifier>.touchid`,
  user-interactive): the stream's lines, the rule, the lock call, and three timers: the relock's, the stream's
  restart, and the settle `K.watchSettle` after each start, so a window being drawn never delays a lock. The
  menu and the Health page read its status, a copy kept under a lock, and never wait on that queue; the one
  wait on it is `stop()` at quit, which returns once the `log` child has been sent its end.
- **Two exceptions, both in the update.** `URLSession` calls its delegate on its own queue and the caller
  hops; unpacking a disk image runs on one serial queue of its own, because it mounts, copies and verifies,
  and two of those at once would share a mount point.
- **Nothing polls while idle.** With no window open, the only repeating timer is the update schedule's, which
  is coarse (`K.updateTick`) and tolerant. The Touch ID key's timers are one-shots, armed only around a press
  or when a stream starts or ends: the relock's, the settle's, and the restart's, which a stream that keeps
  failing arms again every 60 s. The Settings window starts and stops its own two-second poll; the onboarding
  wizard starts and stops the other, also two seconds. The `log stream` child is not a poll: it writes only
  when one of the lines SherlockMe reads is logged, a few per press. What keeping the stream open costs the
  system's log daemons is not measured (`manual-test-checklist.md` §1).

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
