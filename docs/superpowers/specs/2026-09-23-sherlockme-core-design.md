# SherlockMe: the core, design

What SherlockMe does and how, chosen with the owner after every alternative was measured on the owner's
hardware. The owner approved the mechanism and this document; the build followed
`docs/superpowers/plans/2026-09-23-sherlockme-core.md`, and the last section here is what it decided. Since
the build, **`docs/functional.md` is the authority on behaviour**. The platform facts it rests on are in
`docs/macOS.md`; the approaches that were tried and fail are in `docs/pitfalls.md`, with their
measurements. **Read both before changing anything here.**

## The problem

Clicking the Touch ID key locks the Mac, and the finger that clicked it is still on the sensor. The lock
screen reads that finger and unlocks. Measured on the owner's own presses (Magic Keyboard with Touch ID,
macOS 27.0, 26A428): loginwindow locks 0.31 s after the key goes down, the lock screen starts reading the
sensor about 0.1 s later, and the Mac is unlocked again **1.1 to 1.4 s after the press**. The owner walks
away from a Mac they believe is locked.

## What SherlockMe does (the owner's decisions)

1. **The Touch ID key locks the Mac the instant it goes down**, on the built-in button and on a Magic
   Keyboard with Touch ID alike. Measured: locked 0.09 to 0.14 s after the key goes down, where macOS alone
   takes 0.38 s. The owner kept it on the table on purpose: "the instant lock is too nice to be left out".
2. **When the finger that pressed the key unlocks the Mac, SherlockMe locks it again 0.5 s after that
   unlock, once per press.** The Mac is then unlocked for 0.61 to 0.64 s (ten cases, run 9), a trade-off the
   owner accepted. An ordinary press never gets there: the instant lock alone holds, and the relock only
   catches the unwanted unlock. In every run, a Mac locked again stayed locked until the owner unlocked it.
3. **A deliberate unlock is never undone**: a touch that comes after the first half-second of the lock
   screen's read, a password, and any press of the key while the screen is locked (the user unlocking)
   leave the Mac unlocked. The owner, after run 9: "never made something I didn't want".
4. **No setting about what it does**, like ShiftPick. The family's shell: a menu-bar item with a status line,
   Settings with General, System, Health and Tip, updates, uninstall, English and French.
5. **No permission prompt.** SherlockMe reads the unified log, which an administrator account can do
   without sudo. It creates no event tap and asks for no TCC grant.
6. **When SherlockMe is not running, or cannot watch the key, the key does exactly what macOS makes it do**:
   it locks, and today's problem comes back. SherlockMe never leaves the key unable to lock.

## How it works

### What it watches

One `/usr/bin/log stream --style ndjson` child process, with the predicate of `Tools/touchprobe`, and the
distributed notifications `com.apple.screenIsLocked` and `com.apple.screenIsUnlocked` for the session
state. The lines, all at the default level and all reported for the built-in button and the Magic Keyboard
alike (the exact texts are in `docs/macOS.md`):

- biometrickitd: the key down and up (`touchIDButtonPressed: 1` / `0`), at the physical press, 0.31 s
  before loginwindow hears of it;
- biometrickitd: the lock screen starting to read the sensor, a finger arriving and leaving (status 63 and
  64), a match;
- loginwindow: the screen locked and unlocked, and its own decision on a press (locking, or declining
  because a hold is active).

### What it does

- **Lock**: `SACLockScreenImmediate()` from the private login.framework, loaded with `dlsym`. It is the
  code loginwindow runs for the key itself, it answers an `int32` (0 for success), and on macOS 27 it is in
  the session agent's public interface, which needs no entitlement.
- **The Touch ID hold**: `SACAssertScreenLockViaTouchIDBlocked()` and
  `SACRemoveAssertScreenLockViaTouchIDBlocked()`, the same private framework: while it is held, loginwindow
  does not lock on the key itself. SherlockMe holds it while the screen is unlocked, gives it back while it
  is locked, and takes it again every 20 s, because loginwindow drops a hold 60 s after it was last taken.
  Runs 7 to 9 were made with it. **Whether it is needed at all is the build's first question** (below).

### The rule

A pure state machine in `SherlockMeCore`: events with their times in, actions out. It never reads a clock.

- **The key goes down while the screen is unlocked**: lock now. This press is the current one.
- **The lock screen starts reading the sensor within 3 s of that lock**: remember when.
- **A finger is seen within 0.5 s of that read beginning**: it is the finger that pressed the key, resting.
  A finger that leaves within 0.1 s of arriving is the key coming up, not a finger resting, and is
  forgotten.
- **The screen unlocks within 6 s of the lock, while that resting finger is still on the sensor or within
  0.5 s of it leaving**: lock again 0.5 s later, if the screen is still unlocked then. Once per press.
- **Anything else is left alone**: a key press while the screen is locked (and it cancels a relock still
  to come for that press), a finger that arrives later in the read, a password, an unlock after the window.

### The numbers, and the evidence for each

| Constant | Value | Evidence |
|---|---|---|
| resting finger, seen within | 0.5 s of the read beginning | resting fingers were seen 0.001 to 0.42 s into the read, deliberate touches 0.97 s and later: the owner's own presses and runs 1, 1b, 4, 7, 8, 9 |
| a blip, shorter than | 0.1 s | the key coming up showed a finger for 17 ms (run 4) |
| match after the resting finger left, within | 0.5 s | the match lands 0.2 to 0.25 s after the finger that gave the image leaves |
| unlock after the lock, within | 6 s | every unwanted unlock came 0.9 to 1.6 s after the press |
| relock after the unlock | 0.5 s | 0 s: the desktop flashes for 0.10 to 0.12 s and the relocked screen shows the wallpaper with no login box until a key is pressed (run 7). 1 s: a normal lock screen, the Mac unlocked for 1.16 to 1.19 s (run 8). 0.5 s: a normal lock screen, unlocked for 0.61 to 0.64 s (run 9), approved by the owner |
| relocks per press | 1 | 23 relocks in runs 7 to 9, and not one Mac unlocked by itself afterwards; a second chance is only a way to undo a deliberate unlock |
| hold taken again every | 20 s | loginwindow drops a hold 60 s after it was last taken (`touchIDBlockScreenLockAssertionTimeout`) |

### What SherlockMe never does

1. **It never leaves the key unable to lock.** The hold is held only while the log watcher is alive and the
   screen is unlocked. It is given back when the screen locks, when the Mac sleeps, when the watcher stops,
   and before a quit, an update's install or the uninstall. If loginwindow reports that it declined a press
   because of a hold and SherlockMe has not locked for that press within 0.2 s, SherlockMe locks: a press
   is never lost to the hold, even if the key's own log line changes.
2. **It never undoes a deliberate unlock**: once per press at most, never after a press on the lock screen,
   never outside the window.
3. **It never touches the Touch ID settings**, and never runs anything as root.
4. **It asks for no permission.**

### When something fails

- **The log stream ends, or cannot be read**: the hold is given back, so the key locks the way macOS does;
  the watcher is started again with a growing delay; the menu's status line and the Health page say so.
- **SherlockMe crashes while holding the hold**: loginwindow keeps it for up to 60 s and clears nothing when
  the process dies, so for that time the key would not lock. Open question 1 decides how this goes away.
- **A macOS update changes the lines**: the press is not seen, loginwindow's "declined because of a hold"
  line still is, guarantee 1 locks, and the Health page turns red.

## How it is built

- **`SherlockMeCore`**: the rule as a value (events and times in, actions out), its constants in
  `Constants.swift` with the evidence above, and the Health lines.
- **`SherlockMePlatform`**: the log watcher (the child process, the ndjson lines, the restarts), the
  session agent (the three calls through `dlsym`), the session state (the notifications and
  `CGSessionCopyCurrentDictionary`).
- **`SherlockMeApp`**: one engine wiring them together; the menu's status line; the Health page.
- **Tests**: `SherlockMeCoreTests` replays the owner's recorded presses, `Tools/touchprobe/fixtures/*.ndjson`,
  through the rule and checks its actions: each of the two morning bugs gives one relock; the run 9
  recording gives its ten relocks and none of its deliberate unlocks.
- **Onboarding**: the pitch, *Where it lives*, *All set*; no permission page. If the log cannot be read (an
  account that is not an administrator), the wizard and the System page say so in plain words.
- **Menu**: "Watching the Touch ID key", or why not.
- **Health**: checks: the watcher runs; the log can be read. Readings: the last press seen, the last relock.
- **Documents**: the rules above move into `docs/functional.md` in the same commits as the code that
  implements them, which is then the authority; the guarantees become its §0, the way ShiftPick keeps its
  own.

## Open questions for the build

1. **Is the hold needed?** SherlockMe now locks before loginwindow does (0.1 s against 0.31 s). If
   loginwindow's own lock, arriving on a Mac already locked, changes nothing, the hold goes, and with it
   the crash window: SherlockMe gone would then always mean macOS's own behaviour at once. Measured with
   the probe (a relock run without the hold) before the rule is built on either answer.
2. **The built-in button.** Every run used the Magic Keyboard, the lid closed. The probe is run once with
   the lid open.
3. **Restarting after a crash**: `SMAppService.mainApp`, or a launch agent that restarts it (my-sidepulse's
   way), decided by the answer to 1.
4. **An account that is not an administrator** cannot read the log: how the app says so, and whether the key
   is simply left to macOS.

## What was rejected, and why

Each one was measured on the owner's Mac; `docs/pitfalls.md` has the numbers and the rule that keeps it
from being tried again.

| Approach | Why not |
|---|---|
| Lock a moment after the key comes up (0.6 s), instead of at once | A finger resting after the click is still read: 4 of 10 presses unlocked (run 1b). Waiting longer makes every lock slow and still fails for a longer rest. |
| Turn the displays off, then lock, or lock by display sleep | The lock screen reads the sensor with the displays asleep: a resting finger unlocked the Mac (run 2), and after a display-sleep lock the read began 0.17 s later with nobody there (the owner's log). |
| Switch "Touch ID for unlock" off for the user with `bioutil -w -u 0/1` | `bioutil` asks for the user's password on its input and fails without it (run 4). Only storing the login password would drive it. |
| Switch it off for the whole Mac as root (`bioutil -w -s -u 0/1`) | It stopped the finger, and then macOS refused Touch ID until the password was typed, at every press ("Password required to enable Touch ID", run 6). Each switch also takes 0.42 s. It needed a passwordless admin rule that Claude Code's auto mode refused to install. |
| Relock at once after the unwanted unlock | The desktop flashes, and the relocked screen shows only the wallpaper, no login box, until a key is pressed (run 7). |
| A relock decided by time alone | It relocked two deliberate unlocks: pressing the key on the lock screen just after a relock (run 8). |
| `DisableScreenLockImmediate` in loginwindow's defaults | It stops the key's lock, but also every immediate lock, SherlockMe's own included, and it outlives the app: the key would never lock again. |
| React after macOS has locked | The lock screen starts reading 0.03 to 0.15 s after the lock and sees a resting finger at once; anything done then is a race. |
| Know where the finger is while the Mac is unlocked | Nothing an app can reach reports it: BiometricKit wants `com.apple.private.bmk.allow`, the HID biometric events `com.apple.private.hid.client.event-monitor`, and biometrickitd reports the finger only while something reads the sensor. |
| An event tap on the key | Not needed: the log gives both keyboards with no permission. Reports on the web say the built-in button never reaches an event tap; not measured here. |

## The runs

`Tools/touchprobe`, never shipped, made every measurement; each run lasted up to three minutes with the
owner pressing the key. Runs 3 (a slower lock with natural presses) and 5 (a display-sleep lock alone) were
planned and made unnecessary by what the others showed; run 6 was made by the owner in their own Terminal,
because it needed the admin rule.

| Run | What it tried | Result |
|---|---|---|
| the owner's day | nothing (the stored log) | the bug twice, locked 0.31 s and unlocked 1.1 to 1.4 s after the press |
| 1, 1b | the hold, lock 0.6 s after the key comes up | a resting finger unlocks (4 of 10 in 1b) |
| 2 | the hold, displays off then lock | a resting finger unlocks |
| 4 | the hold, `bioutil` for the user around the lock | `bioutil` wanted the password; nothing switched; the lock at key down felt instant |
| 6 | the hold, `bioutil` for the whole Mac as root | the finger was stopped; Touch ID then refused until the password, every time |
| 7 | lock at key down, relock at once | every resting finger caught; a flash and a blank lock screen |
| 8 | lock at key down, relock after 1 s | a normal lock screen; two deliberate unlocks relocked by a time-only rule, fixed |
| 9 | lock at key down, relock after 0.5 s, once per press, a press on the lock screen cancels | 28 presses, 10 relocks, no deliberate unlock touched; accepted |

The recordings of the two morning bugs and of runs 7 to 9 are in `Tools/touchprobe/fixtures/`, one line per
log line (time, process, message).

## What the build decided

The owner approved this document and asked for the build to run to its end without questions, so the four
open questions were answered without a new measurement (items 1 to 4), with one more that came up while
building (item 5). Each answer is reversible.

1. **No hold.** SherlockMe's lock lands 0.09 to 0.14 s after the key goes down, before loginwindow hears of
   the key at 0.31 s, and loginwindow's handler declines while the shield is up (read from loginwindow, not
   measured with SherlockMe running). Without the hold there is no crash window: SherlockMe gone is macOS's
   own behaviour at once. `docs/manual-test-checklist.md` §1 looks at loginwindow's own lock arriving second.
2. **The built-in button** is not measured. The rule also follows a press known only from loginwindow's own
   lock on it (`handleSystemEvent:` … `calling to lock screen immediate`), so a keyboard whose press never
   reaches biometrickitd's key line still gets the relock; only the instant lock is then macOS's.
3. **No launch agent.** Without the hold a crash costs the protection and nothing else; the family's login
   item starts SherlockMe at login, and the Health page shows the crash.
4. **An account that is not an administrator**: nothing is started, and the menu's line, the Health page and
   the wizard's last page say so. Not the System page: it holds only what has a button beside it, and nothing
   in the app can make an account an administrator.
5. **A lock the log did not show.** A stream shows nothing logged before it attached, so a lock landing
   while one starts would be missed. `K.watchSettle` (2 s) after each start, a lock the window server reports
   and the rule has not seen is taken as read (`LockRule.settle`); an unlock never is.

Four things differ from the sections above. The Health page has one check, *Watching the Touch ID key*,
whatever stops it (one cause, one line), and its readings are the last lock and the last unlock caught. A key
line that a macOS update changes is not detected: SherlockMe follows the press from macOS's own lock on it, so
the relock still comes, and the Health page stays green. The screen's state comes from loginwindow's own log
lines of `com.apple.screenIsLocked` and `com.apple.screenIsUnlocked`, not from subscribing to the
notifications, so every event reaches the rule from one stream with the log's own times. And the replay of the
owner's recorded presses is `LockRuleReplayTests`.

## What the first walk decided

The owner installed the build and walked `docs/manual-test-checklist.md` §1 on the Magic Keyboard; a review
of that day's log then measured what the build had left open, and changed one rule.

1. **loginwindow's own lock, arriving after SherlockMe's, declines** with the shield already up
   (`shieldShowing:1`, 16 presses of 16): open question 1 is settled with no hold, and nothing odd follows
   the second lock.
2. **The key is macOS's while anyone holds loginwindow's Touch ID hold.** coreautha takes that hold the moment
   any read of the sensor begins, an app's Touch ID prompt as much as the lock screen's (10 of the day's 11
   reads made with the screen unlocked; System Settings' Touch ID pane the 11th), and loginwindow ignores the
   key while it is held. The rule above locked on every key-down, and so would have locked in the middle of an
   authentication in another app, where the resting finger would then have unlocked and the relock locked
   again. The rule now reads the hold from loginwindow's own lines, with its 3 s debounce and 60 s lapse, and
   leaves such a press to macOS. That covers the 3 s after a Touch ID unlock as well, where the key now does
   what macOS makes it do: nothing. The relock is not the key and never waits for the hold.
3. **Another user's session** is not this one: its loginwindow's lines carry its uid and are dropped, and
   nothing is locked while this session is not at the keyboard.
4. **The lock screen makes one read per lock** (188 of 188), and a NO-MATCH continues that read rather than
   starting another, so a finger seen at the start of "the read" is seen at the start of the only one.
5. **The stream costs nothing worth a setting**: 0.7 s of CPU for the `log` child in half an hour.
