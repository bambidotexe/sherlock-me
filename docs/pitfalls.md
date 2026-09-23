# SherlockMe — pitfalls

What looks right on macOS and is not, with the measurement that settled it. **This is the only place that
records approaches that failed.** Nothing here is a rule; the rules are in `functional.md`.

**The traps every app of the family shares are in `docs/shared/pitfalls.md`**: the onboarding wizard, the
Settings window, updates, the uninstall, launch and login items, signing and the build, the icon, tooling,
tests. A trap that any app could fall into goes there, in the template; this file holds only what is this
app's own.

---

Every entry below was measured on the owner's Mac (MacBook Pro Mac16,8, macOS 27.0, 26A428, a Magic
Keyboard with Touch ID) with `Tools/touchprobe`, the owner pressing the key. The design they led to is
`docs/superpowers/specs/2026-09-23-sherlockme-core-design.md`. **Each one is a way of stopping the finger
that pressed the key from unlocking the Mac that was tried and does not work: do not try it again without a
new measurement that says otherwise.**

### 1. Locking a moment after the key comes up does not stop a resting finger
- **Symptom.** The key's own lock held off, the Mac locked 0.6 s after the key came up, and a finger left on
  the sensor still unlocked it.
- **Measured.** Run 1b, the owner resting the finger 3 s after each click: 4 of 10 presses unlocked by the
  resting finger, 1.1 to 1.2 s after the lock. The lock screen saw it 0.35 to 0.42 s into its read.
- **What holds.** The lock at the instant the key goes down, and a relock for the case where the finger gets
  in anyway (the design).
- **Rule.** A delay alone never. Waiting longer makes every lock slow and still fails for a longer rest.

### 2. The lock screen reads the sensor with the displays asleep
- **Symptom.** The displays turned off before the lock, and a resting finger still unlocked the Mac.
- **Measured.** Run 2: a resting finger unlocked it 1.2 s after the lock, the displays asleep. The owner's
  own log: after a lock caused by display sleep, the lock screen started reading 0.17 s later and went on
  for 9 s with nobody there.
- **Rule.** Display sleep, the screen saver or "require password" do not keep the sensor from being read.

### 3. `bioutil` for the user wants the user's password
- **Symptom.** `bioutil -w -u 0` (Touch ID for unlock off, for the user) did nothing.
- **Measured.** Run 4: status 1 in 22 ms, "Enter user's (501) password: Incorrect password." It reads the
  password from its input; the app had none to give. The setting never changed.
- **Rule.** An app cannot drive the user's Touch ID setting without the login password, and storing the
  login password is not an option.

### 4. Switching Touch ID for unlock off and on again makes macOS demand the password
- **Symptom.** With Touch ID for unlock switched off for the whole Mac just before the lock and back on 2 s
  later, the resting finger was stopped, and then Touch ID refused to unlock at all.
- **Measured.** Run 6, as root through a passwordless sudoers rule (`bioutil -w -s -u 0` and `1`, status 0,
  0.41 to 0.43 s each): after every switch back on, loginwindow logged "Password required to enable Touch
  ID" and the owner had to type the password, five presses out of five. Each switch being that slow, the
  lock also came later than macOS's own.
- **Why it cannot be worked around.** It is macOS's own rule after Touch ID for unlock has been turned off.
  The admin rule it needs was also refused by Claude Code's auto mode as a lasting privilege change: the
  owner installed it for the test and removed it afterwards.
- **Rule.** Never switch Touch ID off to stop the finger, as the user or as root.

### 5. Relocking at once leaves a blank lock screen
- **Symptom.** Locking again the moment the unwanted unlock happened: the desktop flashed, and the Mac sat
  locked showing only the wallpaper, no login box, until a key was pressed.
- **Measured.** Run 7: unlocked for 0.10 to 0.12 s, six times. With a 1 s wait (run 8) the relocked screen
  is normal and the Mac is unlocked for 1.16 to 1.19 s; with 0.5 s (run 9), normal, 0.61 to 0.64 s.
- **What holds.** The relock comes 0.5 s after the unlock, the owner's choice.

### 6. A relock decided by time alone undoes a deliberate unlock
- **Symptom.** The Mac locked again a second after the owner had unlocked it on purpose.
- **Measured.** Run 8, twice: the owner pressed the key on the lock screen just after a relock; the rule saw
  a finger early in that lock's read and took the unlock for the resting finger.
- **What holds.** One relock per press, and a key press while the screen is locked cancels any relock still
  to come (run 9: 28 presses, no deliberate unlock touched).

### 7. `DisableScreenLockImmediate` stops more than the key
- **Symptom.** It looks like the switch that stops the key from locking, so an app could lock later itself.
- **Measured.** loginwindow reads it (its standard defaults) before every immediate lock: the key's
  ("TouchID pressed event, but pref blocks with DisableScreenLockImmediate") and `SACLockScreenImmediate()`
  ("pref setting prevented screenlock") alike. It stays set when the app is gone.
- **Rule.** Never: SherlockMe could not lock, and without SherlockMe the key would never lock again.

### 8. Acting after macOS has locked is a race
- **Measured.** The lock screen starts reading 0.03 to 0.15 s after the lock, and a finger resting there is
  seen at once (0.08 s in the morning's bug). Anything started on `com.apple.screenIsLocked` comes too late.
- **Rule.** SherlockMe acts on the key going down, which the log reports 0.31 s before loginwindow locks.

### 9. Where the finger is, while the Mac is unlocked, is out of reach
- **Measured.** biometrickitd reports a finger (status 63 on, 64 off) only while something reads the
  sensor. BiometricKit's presence detection needs `com.apple.private.bmk.allow`, the HID system's biometric
  events `com.apple.private.hid.client.event-monitor`, and only `/usr/bin/bioutil` carries
  `com.apple.private.biometrickit.allow-config`. None of them is an app's to have.
- **Rule.** Do not design on knowing the finger before the lock. After the lock, the lock screen's own read
  says it, and the relock rule is built on that.

### 10. A Touch ID hold outlives the process that took it
- **Measured.** loginwindow keeps each hold per client name and pid and drops it 60 s after it was last
  taken; nothing clears it when the process dies.
- **What holds.** SherlockMe takes no hold: its own lock comes 0.09 to 0.14 s after the key, before
  loginwindow hears of the key at 0.31 s, so there is nothing to stop, and a crash leaves the key as macOS
  makes it.
- **Rule.** A hold comes back only with a measurement that SherlockMe's lock alone is not enough, and then
  with a way to give it back that survives a crash.

---

## Open issues

Known, bounded, and left alone.

- **The update has never been walked end to end in this app.** Its rules are unit-tested and the install
  helper has installed and rolled back a stand-in app under a real `/bin/sh`; the notification, the window
  and the app installing over itself are `manual-test-checklist.md`.
- **The uninstall has not been walked.** Its two halves are tested apart.
- **After a crash, SherlockMe's `log stream` child can outlive it** until the next line it would write, a press
  of the Touch ID key, which ends it on a broken pipe. It holds nothing and changes nothing meanwhile.
