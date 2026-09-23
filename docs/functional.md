# SherlockMe — what it does

**The authority on behaviour.** Every rule the app is held to, with its numbers. It is kept in sync with
the code in the same commit as any change, and it never carries an outdated rule: one the owner has
overruled is replaced, not annotated.

Numbers are interpolated from `Sources/SherlockMeCore/Constants.swift` (`K`) wherever one appears; the value
in the code is the one that counts.

---

## 0. The guarantees

**SherlockMe must never leave the Touch ID key unable to lock the Mac, and never undo an unlock the user made
on purpose.** The sections below are the rules the app follows; these are the rules every other one is held
to. **A request that would loosen one is a conflict** under step 2 of `docs/shared/workflow.md`: the rule is
quoted to the owner, and nothing changes until the owner has said so for that rule. `LockRuleTests` pins 2
and 3.

1. **It holds nothing in macOS**: no hold on loginwindow, no preference, no Touch ID setting. Whenever
   SherlockMe is not running, has crashed or cannot read the log, the key does exactly what macOS makes it
   do. §1.
2. **It locks the Mac again at most `K.relocksPerPress` (1) time per press**, and only after an unlock that
   comes within `K.relockWindow` (6 s) of the lock, by the finger the lock screen found resting on the
   sensor as it began to read. §1.
3. **A press of the key on the lock screen, a password, a touch later in the read and every unlock outside
   that window are left alone.** §1.
4. **It never touches the Touch ID settings, and never runs anything as root.** §1.
5. **It asks for no permission.** §4.
6. **Nothing it does waits on the main thread**, so a window being drawn never delays a lock.
   `docs/architecture.md`, *Threading*.

## 1. The feature

SherlockMe does one thing: **when the Touch ID key is clicked, the Mac locks, and stays locked.** macOS alone
locks 0.31 s after the key goes down, and the lock screen then reads the finger still resting on the sensor
and unlocks the Mac again, 1.1 to 1.4 s after the press (`docs/macOS.md`). There is no setting.

**What it watches**: one `/usr/bin/log stream` child process, reading these lines and no other
(`TouchIDLog`). All are logged at the default level, which an administrator account reads without sudo.

| Line | What it means |
|---|---|
| biometrickitd `touchIDButtonPressed: 1` | the key went down, the built-in button or a Magic Keyboard with Touch ID |
| loginwindow `handleSystemEvent:` … `calling to lock screen immediate` | macOS locking on the key itself, 0.31 s after it went down |
| biometrickitd `match:withOptions:` | something started reading the sensor |
| biometrickitd status 63, status 64 | a finger arrived on the sensor, left it; reported only while it is read |
| loginwindow `com.apple.screenIsLocked`, `com.apple.screenIsUnlocked` | the screen locked, unlocked |

**What it does** (`LockRule`), on the log's own times:

1. **The key goes down while the screen is unlocked: SherlockMe locks the Mac at once**, with loginwindow's
   own immediate lock (`SACLockScreenImmediate`). Measured: locked 0.09 to 0.14 s after the key went down,
   where macOS alone takes 0.38 s. That press is the current one. A press whose key line was not read, known
   only from macOS locking on it, becomes the current one the same way.
2. **The lock screen starts reading the sensor within `K.readAfterLock` (3 s) of that lock**: when it did is
   kept.
3. **A finger seen within `K.restingFinger` (0.5 s) of that read beginning was already there**: the finger
   that pressed the key, resting. One that leaves within `K.keyBlip` (0.1 s) was the key coming up, and is
   forgotten.
4. **The screen unlocks within `K.relockWindow` (6 s) of the lock, with that finger still on the sensor or
   gone at most `K.matchAfterLift` (0.5 s) before: SherlockMe locks the Mac again `K.relockDelay` (0.5 s)
   later**, if the screen has stayed unlocked. Once per press (`K.relocksPerPress`). The Mac is unlocked for
   about 0.6 s in between, and in every measured run a Mac locked again stayed locked until the owner
   unlocked it.
5. **Everything else is left alone**: the key pressed on the lock screen (the user unlocking, which also
   gives up a relock still to come), a finger that arrives later in the read, a password, an Apple Watch, an
   unlock after the window, and any unlock that follows no press.

**When it cannot watch**, the key does exactly what macOS makes it do, and the menu and the Health page say
why:

- **An account that is not an administrator** cannot read the log: nothing is started. The wizard's last
  page says so too.
- **The stream ends or cannot start**: it is started again after 1, 5, 30, then every 60 s
  (`K.watchRestartDelays`); a stream that ran `K.watchSteadyAfter` (60 s) or longer before it ended starts
  the waits over. Each start reads again whether the screen is locked and forgets any press under way.

**What it logs**, category `touchid`: the stream starting, ending and starting again; every lock and relock
with loginwindow's answer; every unlock left alone soon after a lock, and why; at `debug`, every line the
rule was given.

## 2. Settings

A window of four pages, opened from the menu-bar item (⌘,) or by opening the app again. Its shape, its
numbers and its copy are the `macos-building-settings-pages` skill's, not this document's.

| Page | Group | Rows |
|---|---|---|
| **General** | the app icon, alone | |
| | Startup | Launch at login · Show in menu bar. A note names the way back to this window when the icon is hidden. |
| | Updates | `SherlockMe <version>` with the last answer as its mark · one button, *Check for Updates* or *Update* |
| | Quit | one destructive button |
| | Uninstall | one destructive button, with a warning that never goes away |
| **System** | Start over | one button, *Show Onboarding Again*, which opens a fresh wizard at its first page |
| **Health** | Health | the checks, green, orange or red, never blue: in SherlockMe only *Crashes in the last 7 days* (`K.healthCrashWindow`, read from `~/Library/Logs/DiagnosticReports`), a count in orange with the last one's date as the tooltip, while there is one; *Everything works* in green in its place while there is none · **Check Again**, with a spinner beside it for at least `K.healthMinimumBusy` (0.5 s) |
| | Information | *Running for* and *Memory used*, in blue |
| **Tip** | the app icon beside one sentence, in a card with no title | every feature is free and stays free, and a coffee is how the project is supported |
| | One-time tip | the Ko-fi cup, *A cup of coffee*, what it is, and a button naming the smallest tip the page takes (`SupportLink.smallestTip`, 5 €). It opens `https://ko-fi.com/bambidotexe` in the browser; nothing is paid inside the app. |

TEMPLATE: a feature page goes between General and System, and the app's own switches live on it. The Health
table gains, before the crash line, one line per permission and per setup the wizard asks for (red when the
wizard marks it required, orange otherwise) and one for the service, listener or sensor the feature rests on;
a check with nothing to say while fine is a line only while it is wrong. The Information table's two readings
give way to the app's own (the last time the feature acted, a sensor's value), five at most. The
`*Everything works*` stand-in goes: an app always has checks of its own.

**Health** is two tables and nothing else, and it reports and changes nothing: each orange or red line says
where it is put right, in a warning under the table. A preference is never on it, and neither are the
version and updates (General's). Its readings are taken when the window shows the page and on Check Again,
never on a timer. Every state has one colour on every page: green as it should be, blue a reading or the
user's own choice on the page that owns it, orange not as it should be while the app still does its job, red
with the stop sign what stops it.

Defaults: **Show in menu bar on**. Launch at login is the system's answer and is not stored here.
`onboardingCompleted` is stored beside the switches and is not a setting: no window shows it, and Start over
opens the wizard rather than clearing it.

Settings are one JSON blob in `UserDefaults`. A key missing from a file written by an older build falls back
to its default instead of resetting the others.

## 3. The menu-bar item

Rebuilt from scratch every time it is opened, so it is never a language or a state behind.

```
Launch at Login             ✓
──────────
Settings…                   ⌘,
──────────
Quit SherlockMe               ⌘Q
```

TEMPLATE: the feature's own switch comes first, then a separator; a read-only line saying what the app is
doing right now sits above Settings…, with a separator on each side.

Hiding the icon leaves the app working. Opening the bundle again from the Applications folder or Spotlight
is then the way back to the Settings window.

## 4. The onboarding wizard

Its shape, its numbers and every trap it avoids are the `macos-building-onboarding` skill's, not this
document's.

**The wizard** is a titled, closable, fixed 540 wide window, stepping through three pages with one button at
the bottom right. Its height follows the page around its **top-left** corner: 440, 440, 400.

| Page | What is on it | Its button |
|---|---|---|
| 1 | the app icon, the headline with one word in the icon's colour, what the app does, two capsules: *Menu bar*, *Nothing leaves your Mac* | Continue |
| 2 | **Where it lives**: *Open at Login* and *Show in menu bar*, both optional, each with *Turn On* or *Turn Off* | *Skip* until either is on, then *Continue* |
| 3 | **All set**: where the menu-bar item is | Finish |

TEMPLATE: an app that needs a permission puts a **Permission** page between 1 and 2, one row per grant,
titled exactly what System Settings calls the switch, marked required when the app cannot work without it;
its button reads *Skip* until every required grant is there.

- **It opens on a first run the person started.** A login item whose wizard was simply never finished opens
  no window. **Opening the app again asks the same question**, so while the wizard is unwalked that is what
  comes up rather than the Settings window, and while it is already up it is simply brought forward; a
  reinstall opens no window at all, so that is the first thing a person does afterwards.
  **Settings › System › Start over** opens it whenever it is wanted. It is a **fresh controller every time**:
  every row re-reads the system and the walk starts at page one.
- **Finish records that it was walked**; a window closed before that button keeps the flag false, so the
  wizard returns at the next launch.
- **Nothing in the app asks macOS for a permission except a row's own button.** Nothing at launch, nothing
  when a window opens, nothing "once, to get it out of the way".
- **Who is in front.** The wizard is an ordinary window at the ordinary level, with the default collection
  behaviour: a permission dialog and System Settings open over it and stay there. The app is activated
  once, when the window opens. Two things bring it back afterwards and nothing else: **System Settings
  quitting** (`K.focusReturnWait`, 300 s, after which the wait is dropped) and the app becoming active while
  the wizard is its only window, which orders it front without activating.
- **Nothing else polls, ever.** The wizard starts its one timer (`K.onboardingPollInterval`, 2 s) when it
  opens and stops it when it closes. With no window open, the app arms no timer at all except the update
  schedule's.

## 5. Updates

- **The check** is an anonymous request to GitHub for the repository's latest release. A release has to
  carry a tag that parses as a version and an asset whose name ends in `.dmg`. A 404 means *no release
  published*, which is also what a repository an anonymous caller cannot see looks like; it is not a
  failure.
- **The schedule**: **`K.updateLaunchDelay` (20 s)** after launch, then **`K.updateInterval` (a week)** after
  the last check that got an answer, asked again at every wake, and retried after **`K.updateRetryDelay`
  (an hour)** when one could not reach GitHub. Nothing is kept across launches.
- **A release found without being asked for** is announced by one notification, which replaces the one
  before it. Permission for notifications is asked the first time there is something to say, and for
  nothing else.
- **The update window** fetches the image, holds it against the length and SHA-256 GitHub stated, mounts
  it, copies the app out, and checks that copy before enabling anything: same bundle identifier, strictly
  newer, runs on this macOS, **signed by the same team as the running app**.
- **Install and Relaunch** starts a detached helper and quits through the ordinary quit. The helper waits
  for the process to go, renames the old bundle aside, renames the new one in, opens it, and **puts the old
  one back if the new version is not seen running**. It leaves one line behind, which the next launch reads
  and shows.
- **An update never installs by itself.** The automatic check only announces; the fetch and the install
  each need a click. If the app has not quit **`K.updateStallNotice` (8 s)** after Install and Relaunch, the
  helper is stopped and the window says so, so that a later quit is only ever a quit.

## 6. Uninstalling

**Settings › General › Uninstall**, after an alert that says what will go. In this order:

1. The **login item**, while the bundle it names is still where it names it. SherlockMe is granted no
   permission, so there is none to give back.
2. The notification authorization, so that a reinstall can be asked again.
3. The **bundle to the Trash**, not deleted: the app the user has just removed is still there to put back.
4. The **preferences and the support folder**, handed to a detached helper that waits for this process to
   go. `cfprefsd` writes the domain out again as the process exits whatever happens, so removing them in
   the app leaves an empty plist where a Mac that never had the app has no file at all.
5. The app quits, and the `log stream` it started stops with it. Whatever could not be done is named, with
   what the system said about it.

**Dragging the bundle to the Trash is not an uninstall**, and the Uninstall group says so permanently: the
Login Items entry would stay, pointing at an app that is gone.

## 7. The words

Every sentence the user reads is in **English and French**, picked from the system language at launch, with
English the fallback for every other language. They live in `Core/Strings*.swift`, one table per surface,
one accessor per sentence switching over the language, so a sentence cannot exist in one language alone.

The copy rules are the `macos-building-settings-pages` skill's. The two `LocalizationTests` enforce here:
**no dash longer than the one on the keyboard**, anywhere; and **a key is its symbol then its name** at every
mention, ⇧ Shift, ⌘ Command, ⌥ Option, ⌃ Control. The app's own name is never translated and never spelt
out in a table: it is read from the bundle, so renaming the app carries through.
