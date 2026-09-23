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

TEMPLATE: one line per thing to do and what to expect, as `- [ ]` items.

## 2. This app's Settings

- [ ] There is no feature page. Health: *Watching the Touch ID key*, green *Running*; the two readings read
      *None yet*, then how long ago after a press and after a caught unlock (Check Again). The menu's status
      line reads *Watching the Touch ID key*.

## 3. This app's wizard

- [ ] The pitch page: the icon, the headline with *stays* (*reste*) in the icon's colour, the two capsules.
      Nothing is cut off, nothing is truncated, every sentence wraps. There is no permission page.
- [ ] On an account that is not an administrator (a standard account made for the test), the last page says
      SherlockMe cannot see the Touch ID key there; Health is red, and the menu line says why.
