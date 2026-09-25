# SherlockMe — CLAUDE.md

The operating manual for an agent working in this tree. Read it whole before the first edit.

## What this project is

SherlockMe fixes one thing: clicking the Touch ID key locks the Mac, and the finger that clicked it, still on
the sensor, unlocks it again about a second later. SherlockMe locks the Mac the instant the key goes down
(0.1 s, against macOS's 0.38 s) and, when the finger that pressed the key unlocks it anyway, locks it again
0.5 s later, once per press; a deliberate unlock is never undone. It
watches the key through the unified log (`log stream`: an administrator account, no permission prompt, no
event tap) and locks through the private login.framework. **The one thing it must never do is leave the key
unable to lock**: `docs/functional.md` §0 holds its guarantees. **Before changing the mechanism, read the design
(`docs/superpowers/specs/2026-09-23-sherlockme-core-design.md`) and `docs/pitfalls.md`**: every other way of
stopping the finger was measured on the owner's Mac and fails, and the reasons are there.

Swift, SwiftPM (tools 5.10), macOS 26+, no Xcode project, no third-party dependency. One process, a
menu-bar accessory, signed with the Wooflab team's Developer ID and notarized, not sandboxed. It looks for a
newer release on GitHub at launch and once a week, announces one with a notification, and installs it on a
click. **The check is anonymous, so the repository has to be public for it to see anything**: a private one
reads exactly like no release at all.

## The family, and the shared documents

This app is one of the macOS apps under `~/Projects` that share one shape (the `macos-map` skill lists them).
**`docs/shared/` is a synced copy of `~/Projects/macos-app-template/docs/shared/`, and it is never edited
here**: a change goes in the template and `sh ~/Projects/macos-app-template/scripts/sync-shared-docs.sh`
replicates it to every app. A trap, a convention or a platform fact that applies to more than this app goes
there, not in this app's own documents.

| Shared document | What it is |
|---|---|
| `docs/shared/workflow.md` | **The change workflow.** Every change to what the app does follows it, and it is not restated here. |
| `docs/shared/conventions.md` | How every app of the family is built: layout, targets, scripts, the app shell, Settings, updates, uninstall, code style, commits. |
| `docs/shared/macOS.md` | The platform facts every app leans on. |
| `docs/shared/pitfalls.md` | The traps every app has already fallen into. |
| `docs/shared/manual-test-checklist.md` | The walks every app repeats: the wizard, Settings, updates, uninstall, language. |

## Read first

| File | What it is |
|---|---|
| `docs/README.md` | The index: which document answers which question, and how to start. |
| `docs/functional.md` | **The authority on behaviour.** Every rule of the app, with the numbers. Kept in sync with the code by the workflow. |
| `docs/superpowers/specs/2026-09-23-sherlockme-core-design.md` | **The core's design**, chosen with the owner: what SherlockMe does, the rule and its numbers with their evidence, the guarantees, the open questions for the build, and every approach that was rejected and why. |
| `docs/architecture.md` | The three targets, what each layer owns, threading, the update, the build. |
| `docs/macOS.md` | This app's own platform facts. The family's are in `docs/shared/macOS.md`. |
| `docs/pitfalls.md` | This app's own traps, and its open issues. The family's are in `docs/shared/pitfalls.md`. |
| `docs/manual-test-checklist.md` | What only a person can see. The app target has no automated tests. |

## Where a change usually lands

| To change… | Edit | Then document in |
|---|---|---|
| the Touch ID key: what is read, the rule, a lock | **`functional.md` §0 and `docs/pitfalls.md` first.** `Core/TouchIDLog.swift` (the lines), `Core/LockRule.swift` (the rule), `Core/Watcher.swift` (the restarts), the Touch ID numbers in `Core/Constants.swift` — `TouchIDLogTests`, `LockRuleTests`, `LockRuleReplayTests` (the owner's recordings, `Tools/touchprobe/fixtures/`), `WatcherTests`; `Platform/TouchIDLogStream.swift`, `SessionAgent.swift`, `LoginSession.swift` — their tests; `App/TouchIDGuard.swift` | `functional.md` §0, §1 |
| a constant | `Core/Constants.swift`, with its measurement in the comment | the section that states it |
| a user setting | **Invoke the `macos-building-settings-pages` skill first.** `Core/Settings.swift` + a row on its page + `SettingsTests` | `functional.md` §2 |
| the Settings window's pages, look or copy | **Invoke the `macos-building-settings-pages` skill first**: it holds every rule of the window's structure, numbers and wording. `App/SettingsKit.swift` (the kit and `SettingsMetrics`), `App/SettingsView.swift` (`SettingsPageID`, `SystemStatus`), `App/SettingsWindow.swift`, `App/Settings…Page.swift`. **The words are not in the page files**: they are `Core/Strings<Page>Page.swift` | `functional.md` §2 |
| the Health page: a check, a reading, a colour, a fix sentence | **Invoke the `macos-building-settings-pages` skill first** (*The Health page*: two tables, what is a check, the limits). `Core/HealthReport.swift` (`HealthFacts` → `checks(for:)`, `readings(for:)`, `crashes(_:)`), `Core/HealthRules.swift` (the grant rule, shared with the other pages), `Core/Health.swift` (the level, `HealthRow`, `InfoRow`, `HealthLimits`), `Core/StringsHealthPage.swift`; `App/HealthCheck.swift` (the readings, taken when the page is shown and on Check Again), `App/SettingsHealthPage.swift` (draws only); the reader `Platform/CrashReports.swift` — `HealthTests` (the worst case holds `HealthLimits`), `CrashReportsTests`. SherlockMe's own: *Watching the Touch ID key* (`HealthReport.watching`, one line whatever stops it) and the last lock and the last unlock caught, read from `TouchIDGuard.status` | `functional.md` §2 |
| the menu-bar item or its menu | `App/MenuBarController.swift`, `Core/StringsMenu.swift` | `functional.md` §3 |
| onboarding, or a permission | **Invoke the `macos-building-onboarding` skill first**: it holds every rule of the wizard, who is in front, and what a grant button may do. `App/OnboardingWindow.swift` (the controller, the pages, the row, `OnboardingMetrics`), `App/GrantCatalogue.swift` (what a grant is, the lists), `App/AppDelegate` (`showOnboarding`). **The words are not in the page files**: they are `Core/StringsOnboarding.swift` | `functional.md` §4 |
| updates: the check, its schedule, the notification | `Core/UpdateCheck.swift`, `UpdateSchedule.swift`, `UpdatePanel.swift`, the `update…` numbers in `Core/Constants.swift`; `Platform/UpdateChecker.swift`; `App/UpdateController.swift` (the one owner), `UpdateNotifier.swift` | `functional.md` §5 |
| updates: the window, the fetch, making it ready, Install and Relaunch | `Core/UpdateSession.swift`, `StagedUpdateCheck.swift`, `UpdateInstallScript.swift` (the helper's text, run under a real `/bin/sh` by `UpdateInstallScriptTests`); `Platform/UpdateStager.swift`, `CodeSignature.swift`, `UpdateInstaller.swift`, `DetachedProcess.swift`; `App/UpdateWindow.swift` | the same, plus `docs/shared/pitfalls.md` *Updates*. **Read those entries before touching the order of an install** |
| the uninstall | `Core/UninstallPlan.swift` (the helper's text and why it waits for the pid), `Platform/Uninstall.swift` (the order), the Uninstall group of `App/SettingsGeneralPage.swift`, `Core/StringsGeneralPage.swift` | `functional.md` §6 |
| **any sentence the user reads**, in either language | `Core/Strings*.swift` (one table per surface; a string is one accessor switching over `Language`, so the two languages are added together or not at all), `Core/Localization.swift` — `LocalizationTests`, which also reads the tables off disk | `functional.md` §7 |
| the app's name, its identifier or its repository | **`scripts/signing.env` only.** `make-app.sh` writes all three into the built `Info.plist` and `Core/AppIdentity.swift` reads them back | `docs/shared/conventions.md` §7 |
| the icon | `Resources/AppIcon.icon` (re-export from Icon Composer, never hand-edit `icon.json`), `Resources/previews/SherlockMe-preview-1024.png`, `Resources/MenuBarMark.svg`, `Resources/ICON-NOTES.md`, the mark in `App/MenuBarController.swift` | `architecture.md` *Build and signing* |
| the signing identity, the build or the release | `scripts/signing.env`, `scripts/make-app.sh`, `Resources/SherlockMe.entitlements`, `scripts/make-dmg.sh`, `scripts/release.sh` | `architecture.md` *Build and signing* |

## Commands

```bash
# ---- the two actions. A build of this app reaches a Mac by one of these and by nothing else. ----
make install     # skill: macos-install-locally. The production build → /Applications; leaves no .app or .dmg behind
make release     # skill: macos-publish-release. The same, plus tag, push, GitHub release, and the tree moves on
# -------------------------------------------------------------------------------------------------
```

- `swift build` — the three code targets and the probe. **This is the truth**; editor diagnostics are
  frequently stale.
- `swift test` — two bundles, and **one summary line each: count two.** `SherlockMeCoreTests` runs in under
  three seconds; `SherlockMePlatformTests` spawns real subprocesses and takes a moment longer.
  `swift test --filter <SuiteName>` runs one suite.
- `swift run axprobe elements SherlockMe` — the front window's Accessibility subtree, every element's frame;
  `swift run axprobe hit <x> <y>` — what a real hit test finds at a point. **A command-line tool inherits the
  Accessibility grant of the terminal that starts it.** A frame that names a rectangle where `hit` finds
  nothing is the class of bug the probe exists for (`docs/shared/pitfalls.md` *Onboarding*).
- `swift run touchprobe watch|relock|replay …` — the Touch ID probe (`Tools/touchprobe`, never shipped): what
  happens around each press of the key, read off the log; `relock` tries the design's mechanism live and
  `replay` reads the stored log. Every live mode but `watch` locks the Mac, so it runs only with the owner at
  the keyboard and asking first. The owner's recorded presses are in `Tools/touchprobe/fixtures/`.
- `make install` (`scripts/install.sh`) — **one of the two ways a build of this app reaches a Mac.** It
  builds the real thing — Release, Developer ID, Hardened Runtime, notarized, stapled, wrapped in the disk
  image — takes the bundle out of that image into `/Applications`, and opens it. It leaves **no `.app` and
  no `.dmg` anywhere under the repository**, on any exit path.
- `make release LEVEL=<patch|minor|major> NOTES=<file>` (`scripts/publish.sh <level> --notes=<file>`) —
  **the other way.** Refuses without release notes (written from every commit since the last tag, skill
  `macos-publish-release`, *Release notes*), on a dirty tree, computes the new version and refuses if that tag already exists, then bumps the version by the
  level given, commits and pushes that bump, and only then builds — the same build `install` makes, then the tag,
  the push and the GitHub release carrying the image. Nothing bumps the version again afterward. Run it only
  when the owner has asked for a release, and ask which level if they have not said. It leaves
  `/Applications` alone, so the copy here finds the release and installs it itself, as a user's does; `--install`
  (`make release … INSTALL=1`) installs it here too, and is passed only when the owner asks for it.
- **There is no third way.** A bundle left in `build/` is a complete application that Spotlight offers;
  launching it by accident gives a second instance with the same bundle identifier and the same preferences.
  `scripts/no-leftovers.sh` holds that rule.
- `scripts/version.sh` — the version rule, and the only thing that writes the version: **a local install
  always builds and installs exactly the tree's own version.** `scripts/publish.sh <patch|minor|major>` is
  the only thing that moves it. The last release is `1.0.0`, and so is the tree.
- `/usr/bin/log stream --predicate 'subsystem == "dev.rubens.SherlockMe"' --level debug` — the app's log
  (`log` alone is a zsh builtin, hence the full path). Categories: `app`, `update`, `onboarding` (the
  wizard's poll, the stepping button's word, and at `debug` where that button actually is), `touchid` (the
  stream starting and ending, every lock and relock, every press left to macOS and why, every unlock left
  alone and why, and at `debug` every line the rule was given).
- `SHERLOCKME_UPDATE_FEED=file:///…/latest.json` in the installed app's environment replaces GitHub's reply
  with a stand-in, which is how the whole update is walked offline (`docs/shared/manual-test-checklist.md`).

## Architecture

Three code targets, dependencies pointing one way: Core ← Platform ← App. Full version in
`docs/architecture.md`.

- **`Sources/SherlockMeCore`** — pure rules, **Foundation and CoreGraphics only** (`PurityTests` fails the
  build otherwise), and it never reads a clock. `TouchIDLog` + `LockRule` + `Watcher` (the Touch ID key:
  what is read, the rule, the restarts) · `Settings` · `Constants` (`K`, every number with its
  measurement) · `AppIdentity` + `Paths` · `QuietLaunch` · `UninstallPlan` · the update's rules
  (`UpdateCheck`, `UpdateSchedule`, `UpdatePanel`, `UpdateSession`, `StagedUpdateCheck`,
  `UpdateInstallScript`) · `Health` + `HealthRules` + `HealthReport` (the Health page's two tables, and the
  colour rule every page's states follow) · `Localization` (`Language`, `Loc`) + `Strings*` (every user-facing
  string, English and French side by side, one table per surface).
- **`Sources/SherlockMePlatform`** — the only code that talks to the system. `TouchIDLogStream` +
  `SessionAgent` + `LoginSession` (the Touch ID key: the `log stream` child, the lock, the session) ·
  `LoginItem` · `SettingsStore` ·
  `CrashReports` (what the Health page reads about the app itself) ·
  `Log` · the update's I/O (`UpdateChecker` + `UpdateDownload`, the only network code; `UpdateStager`,
  `CodeSignature`, `UpdateInstaller`, `DetachedProcess`) · `Uninstall`.
- **`Sources/SherlockMeApp`** — `AppDelegate` wires everything. `TouchIDGuard` (the behaviour, on a queue of
  its own) · `MenuBarController` · the onboarding wizard
  (`OnboardingWindow` the controller, the pages, the row and `OnboardingMetrics`; `GrantCatalogue` what a
  grant is and the lists; `ControlActionHandler`) · `UpdateController` (the update's one owner) +
  `UpdateNotifier` + `UpdateWindow` · the settings window (`SettingsKit` the kit, `SettingsWindow` the
  toolbar window whose height follows the page, four `Settings…Page`, `SettingsView` with `SettingsPageID`
  and `SystemStatus`, `HealthCheck` the Health page's readings).
- **`Tools/axprobe`** — the Accessibility probe. Ships with nothing.
- **`Tools/touchprobe`** — the Touch ID probe, and the owner's recorded presses in `fixtures/`. Ships with
  nothing.

The app target has no automated tests. Its verification is `docs/manual-test-checklist.md` and the log.

## Rules

The rules every app of the family keeps are `docs/shared/workflow.md` *Rules*; they hold here and are not
restated. This app's own:

- **SherlockMe holds nothing in macOS**: no hold on loginwindow, no preference, no Touch ID setting. Not
  running must always mean the key does what macOS makes it do (`functional.md` §0).
- **A relock needs every condition of the rule**: a press SherlockMe followed, the lock screen's read within
  3 s, a finger in its first half-second, the unlock within 6 s, once. Each one is what keeps a deliberate
  unlock alone; widening one to catch more undoes one (`docs/pitfalls.md` 6).
- **A press macOS ignores for an app's read of the sensor is macOS's**: while an app holds loginwindow's
  Touch ID hold (reading the sensor, and 3 s after), SherlockMe does not lock on the key; the lock screen's
  own hold is the owner's exception, and a click right after a Touch ID unlock locks. It never locks while
  another session is at the keyboard. `LockRuleTests` pins all of it (`functional.md` §0).
- **Nothing locks the Mac unless the owner is at the keyboard and has said so**: no test, no probe run, no
  build step. `SessionAgentTests` looks the call up and never makes it.
- **Everything the key does runs on `TouchIDGuard`'s queue**, never on the main thread.
- `SherlockMeCore` imports Foundation and CoreGraphics only, and never reads a clock: `now` is passed in.

## Traps

`docs/shared/pitfalls.md` is the family's list and `docs/pitfalls.md` this app's own, with the measurements.
The seven that cost the most:

- A lock that waits for the key to come up does not stop a resting finger, and neither does putting the
  displays to sleep first (pitfalls 1, 2).
- `bioutil` wants the user's password, and switching Touch ID for unlock off and on again makes macOS demand
  it at the next unlock (pitfalls 3, 4).
- Relocking at once leaves a lock screen with no login box; 0.5 s is the owner's number (pitfalls 5).
- A relock decided by time alone undoes a deliberate unlock: each condition of the rule is what keeps it
  from doing so (pitfalls 6).
- `DisableScreenLockImmediate` stops every immediate lock, SherlockMe's included, and outlives the app
  (pitfalls 7).
- A Touch ID hold outlives the process that took it, for up to 60 s (pitfalls 10).
- Locking on every click of the key interrupts an authentication in another app: coreautha holds
  loginwindow's Touch ID hold for every read of the sensor, and loginwindow ignores the key meanwhile
  (pitfalls 11).

## Status

`swift build` is clean and `swift test` is green at this commit. The app target has no automated tests;
`docs/manual-test-checklist.md` is its verification.

Known limitations, in plain words:

- **The owner has walked the feature on the Magic Keyboard, the lid closed**: the instant lock, the relock,
  presses on the lock screen, and loginwindow's own lock declining after SherlockMe's. Not walked yet
  (`docs/manual-test-checklist.md` §1): the built-in button, a click of the sensor during another app's
  Touch ID read, a second user's session, an account that is not an administrator.
