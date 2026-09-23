# SherlockMe — what only a person can see

`SherlockMeApp` has no automated tests. This is its verification. Work down it after any change to the app,
and note anything that surprises you in `pitfalls.md`.

**The walks every app of the family repeats are `docs/shared/manual-test-checklist.md`**: the onboarding
wizard, the Settings window, updates, the uninstall, language. Walk them from there; this file holds the
app's own.

```sh
swift run axprobe elements SherlockMe     # the front window's element tree, with every frame
swift run axprobe hit <x> <y>           # what a real hit test finds at a point
/usr/bin/log stream --predicate 'subsystem == "dev.rubens.SherlockMe"' --level debug
```

---

## 1. The feature

**Every press below locks the Mac: the owner at the keyboard, and nobody else.** Keep
`/usr/bin/log stream --predicate 'subsystem == "dev.rubens.SherlockMe" AND category == "touchid"'` open in a
Terminal: it says what SherlockMe decided at each press.

- [ ] The menu's status line reads *Watching the Touch ID key*.
- [ ] Click the Touch ID key and lift the finger: the Mac locks at once, and stays locked.
- [ ] Click it and leave the finger on the key: the Mac locks, may show the desktop for about half a second,
      then locks again and stays locked until you unlock it. The log says "locked again".
- [ ] Unlock with a touch once the lock screen is up, within 6 s of the lock: it stays unlocked. The log says
      "unlock left alone".
- [ ] Click the key on the lock screen to unlock: it stays unlocked.
- [ ] Unlock with the password: it stays unlocked.
- [ ] Click the key within 3 s of a Touch ID unlock: nothing happens, as macOS alone; the log says "left to
      macOS", naming coreautha. Click it 4 s after: it locks.
- [ ] With a Touch ID prompt up in another app (System Settings › Touch ID & Password, or `sudo` on a
      terminal with Touch ID for sudo), click the sensor: the Mac does not lock and the authentication goes
      on; the log says "left to macOS". Cancel the prompt and click the key 4 s later: it locks.
- [ ] With a second account logged in (fast user switching), from that account click the key: SherlockMe's
      log says nothing, or "another session at the keyboard: left to macOS", and that account's Mac does what
      macOS makes it do. Back in yours, the first click locks at once.
- [ ] With the lid open, the same presses on the built-in button. If the log says "macOS locked on a press
      whose key line was not read", its press does not reach biometrickitd's key line: write it in
      `docs/macOS.md`.
- [ ] At every press, nothing odd when loginwindow's own lock arrives after SherlockMe's: no second lock
      screen, no flash, the login box there. loginwindow declines it (`docs/macOS.md`); anything seen goes in
      `docs/pitfalls.md`.
- [ ] Quit SherlockMe: `pgrep -lf 'log stream --style ndjson'` lists nothing of SherlockMe's, and a click with
      the finger left on the key locks and unlocks again, as macOS does alone.
- [ ] Leave SherlockMe running for an hour on battery: in Activity Monitor, the CPU and energy of `log`,
      `logd` and `diagnosticd` stay near zero. Write what you see in `docs/macOS.md`.

## 2. This app's Settings

- [ ] There is no feature page. Health: *Watching the Touch ID key*, green *Running*; the two readings read
      *None yet*, then how long ago after a press and after a caught unlock (Check Again). The menu's status
      line reads *Watching the Touch ID key*.

## 3. This app's wizard

- [ ] The pitch page: the icon, the headline with *stays* (*reste*) in the icon's colour, the two capsules.
      Nothing is cut off, nothing is truncated, every sentence wraps. There is no permission page.
- [ ] On an account that is not an administrator (a standard account made for the test), the last page says
      SherlockMe cannot see the Touch ID key there; Health is red, and the menu line says why.
