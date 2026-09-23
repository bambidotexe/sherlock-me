# SherlockMe — the platform boundary

What this app relies on macOS to do, and what was measured rather than assumed. **Read this before
designing on a platform assumption.**

**The facts every app of the family leans on are in `docs/shared/macOS.md`**: the process model, windows
and activation, login items, permissions, the update mechanics, the uninstall, language, build and signing,
the disk image. This file holds only what is this app's own, and nothing here repeats that document.

## What a Touch ID key press does

Read out of loginwindow, login.framework and biometrickitd, and off the log of the owner's own presses, on
macOS 27.0 (26A428), a MacBook Pro (Mac16,8) and a Magic Keyboard with Touch ID (USB-C, product 0x0321).
`Tools/touchprobe` prints the same timeline live (`watch`) or from the stored log (`replay`).

- **The key is the Consumer page's Menu usage (0x0C/0x40) on both keyboards.** The built-in button
  (`AppleM68Buttons`) lists it among its press-count usages; the Magic Keyboard's report carries a Menu bit
  beside an AL Terminal Lock bit (0x019E). Menu reaches loginwindow as a system-defined event of subtype 16
  (`NX_SUBTYPE_MENU`).
- **One place locks on it**: `-[ApplicationManager handleSystemEvent:]` in loginwindow, which calls
  `lockScreenImmediateFromTouchIDPress`, the same `lockScreenImmediateUsingShortTimeout:` that
  `SACLockScreenImmediate()` runs. It declines when `DisableScreenLockImmediate` is set in its defaults,
  within a debounce after the session came on console, when nobody is logged in, the display is captured,
  the shield is up or an unlock is in progress, and **while any process holds the Touch ID hold**.
- **The Touch ID hold** is `SACAssertScreenLockViaTouchIDBlocked()` and
  `SACRemoveAssertScreenLockViaTouchIDBlocked()` in the private login.framework: no argument, an `int32`
  status, 0 for success. loginwindow keeps one per client name and pid and drops it 60 s after it was last
  taken (`touchIDBlockScreenLockAssertionTimeout`; taking it again resets the 60 s). Nothing clears it when
  its process dies. On macOS 27 these two and `SACLockScreenImmediate()` are in
  `LFSessionAgentListenerPublicInterface`, which needs no entitlement; the privileged interface
  (`com.apple.private.sessionagent.spi`) holds `SACLockScreenWhenBroughtOnConsole:` and none of them.
- **coreautha takes the hold for every read of the sensor, an app's as much as the lock screen's**, the
  moment the read begins (`match:withOptions:`, when the prompt comes up, 1 to 2 s before a finger lands)
  and gives it back when the read ends (`cancelWithClient:`, after a match or a cancel) with a debounce
  that keeps it **3 s** more. Measured on one day: within 1 ms of 10 of the 11 reads made with the screen
  unlocked, System Settings' Touch ID pane holding it for the 11th, and 302 releases of 302 with the 3 s.
  So a click of the sensor while an app reads it does nothing, and a key press within 3 s of a Touch ID
  unlock does nothing either, which the owner met three times in one day. loginwindow logs the hold at the
  default level, `-[LWTouchIDLockScreen addNewTouchIDBlockScreenLockAssertionForClient:withPID:] |
  addNewTouchIDBlockScreenLockAssertionForClient: coreautha, with PID: 35068` and
  `clearTouchIDBlockScreenLockAssertionForClient: …` followed by `assertion timeout set to 3.000000 seconds
  from now`, and SherlockMe reads both (`functional.md` §1).
- **loginwindow's decision on a press is one line** of `handleSystemEvent:`: `No assertions, calling to lock
  screen immediate`; `touchID Screenlock blocked assertion, do not lock the screen`; or `do NOT lock screen
  not loggedIn:0, is not on console:0, displayCaptured:0, mbsetupuser:0, shieldShowing:1,
  isTouchIDDebounceInEffect:0, isUnlockInProgress:0`, each flag a reason. **On a Mac SherlockMe has already
  locked, loginwindow's own lock on the same press declines with `shieldShowing:1`**, 0.31 s after the key
  (16 presses of 16 on the owner's first walk): nothing odd follows the second lock.
- `DisableScreenLockImmediate` also refuses `SACLockScreenImmediate()` ("pref setting prevented
  screenlock"): it stops the key's lock and every immediate lock with it.
- **The race, measured on ten Magic Keyboard presses** (the lid closed): loginwindow gets the key
  **0.305 to 0.321 s after it goes down**, whenever it comes up (0.34 to 0.97 s); the screen is locked about
  0.07 s later; the lock screen starts reading the sensor 0.03 to 0.15 s after that. A finger still resting
  is seen at once (0.08 and 0.22 s into the read in the two cases that unlocked) and matched: **unlocked
  1.11 and 1.42 s after the press**, one of them with the finger still on the sensor until 1.35 s, 0.85 s
  after the key came up.
- **Where the finger is, is reported only while something reads the sensor** (biometrickitd's status 63
  on, 64 off). With the Mac unlocked and nothing reading, nothing an app can reach knows: BiometricKit's
  presence detection needs `com.apple.private.bmk.allow`, the HID biometric events
  `com.apple.private.hid.client.event-monitor`, and `/usr/bin/bioutil` alone carries
  `com.apple.private.biometrickit.allow-config`.
- **The log lines**, at the default level and kept: biometrickitd `touchIDButtonPressed: 1` and `: 0` (the
  key down and up, both keyboards), `match:withOptions:` (a read begins),
  `statusMessage:withData:timestamp: 63,` and `64,`, `matchResult:timestamp: MATCH` or `NO-MATCH`,
  `cancelWithClient:` (the read ends); loginwindow's `handleSystemEvent:` lines, the hold's two, and
  `sendDistributedNotification: com.apple.screenIsLocked` / `Unlocked`, `with object:<uid>` naming the
  session. An administrator account reads them without sudo. **The lock screen makes one read per lock**
  (188 locks of 188 on one day), and a NO-MATCH is retried inside that read rather than starting another
  (three cases): a finger seen at the start of the read is seen at the start of the only one.
- **What the stream costs**: in half an hour of watching, the `log` child spent 0.7 s of CPU and SherlockMe
  0.4 s; `logd` ran at 0.6 % of one core over the day and `diagnosticd` for 44 s in 14 h, neither of them
  attributable to it.
- **`bioutil -w -u 0|1`** (the user's own switch) **asks for the user's password on its input**: "Enter
  user's (501) password: Incorrect password.", status 1, when it gets none. **`bioutil -w -s -u 0|1`** (the
  whole Mac's) works as root, 0.41 to 0.43 s a switch, and **once Touch ID for unlock has been switched off
  and on again, loginwindow will not use it until the password is typed** ("Password required to enable
  Touch ID", five presses out of five). `docs/pitfalls.md` 3 and 4.
- **A lock taken with the displays asleep still reads the sensor**: after a lock caused by display sleep,
  the lock screen starts reading 0.17 s later, with nobody there; with the displays put to sleep first, a
  resting finger still unlocks the Mac. `docs/pitfalls.md` 2.
- **`SACLockScreenImmediate()` called on the key-down line locks the Mac 0.09 to 0.14 s after the key goes
  down** (runs 7 to 9, the log stream's own delay included), against 0.38 s when loginwindow locks on the
  key itself.
- **Locking again after the finger that pressed the key has unlocked the Mac**: done at once, the desktop
  shows for 0.10 to 0.12 s and the relocked screen stays on the wallpaper with no login box until a key is
  pressed; done 1 s later, the lock screen is normal and the Mac was unlocked for 1.16 to 1.19 s; done 0.5 s
  later, normal, 0.61 to 0.64 s. In 23 relocks, not one Mac unlocked by itself again afterwards.
- **The session agent's interface is split on macOS 27**: `LFSessionAgentListenerPublicInterface` (28
  methods, among them `SACLockScreenImmediate:` and both Touch ID hold calls) needs no entitlement, and the
  privileged `LFSessionAgentListenerInterface` (`com.apple.private.sessionagent.spi`) holds
  `SACLockScreenWhenBroughtOnConsole:`, read off the Objective-C runtime.

Not measured yet, and what the app does meanwhile:

- **macOS 26.** Every measurement is on 27.0. Where `SACLockScreenImmediate` is missing or refused, the key
  locks the way macOS does, no relock follows, and the log says the lock call is missing or failed; the Health
  page does not show it.
- **The built-in button's timeline**: every run used the Magic Keyboard, the lid closed. If its press does
  not reach biometrickitd's key line, SherlockMe follows the press from loginwindow's own lock on it: the
  relock still works, and the lock is macOS's own, 0.31 s after the key.
- **A click of the sensor during another app's read, with SherlockMe running.** The hold is measured and
  the rule follows it; that nothing locks is what `docs/manual-test-checklist.md` §1 looks at.
- Whether an event tap sees the subtype-16 event of either keyboard. SherlockMe has no event tap.

## What the app calls

| Call | Where | What it answers |
|---|---|---|
| `/usr/bin/log stream --style ndjson --predicate …` | `TouchIDLogStream` | one JSON line per entry that matches `TouchIDLog.predicate`, until it is stopped; started only on an administrator account |
| `SACLockScreenImmediate()`, login.framework, through `dlsym` | `SessionAgent.lockScreen` | an `int32`, 0 on success; the screen locked 0.09 to 0.14 s after the key's line when called on it (macOS 27.0, 26A428) |
| `CGSessionCopyCurrentDictionary()`, `CGSSessionScreenIsLocked` | `LoginSession.screenIsLocked` | whether the screen is locked; read when a stream starts, and again `K.watchSettle` (2 s) after, when a lock the log did not show is taken from it (`LockRule.settle`) |
| `CGSessionCopyCurrentDictionary()`, `kCGSessionOnConsoleKey` | `LoginSession.isOnConsole` | whether this session is at the keyboard; read before every lock and relock, and nothing is locked when it is not |
| `getuid()` | `TouchIDLogStream` | the session whose lock and unlock lines are this app's (`with object:<uid>`) |
| `CBUserIdentity.isMember(ofGroup:)` against the `admin` group (80) | `LoginSession.userIsAdministrator` | whether the account may read the log; the functions of `<membership.h>` are not visible to Swift |
