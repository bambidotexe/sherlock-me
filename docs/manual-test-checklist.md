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

- [ ] TEMPLATE: the feature page, every row, and that each setting survives a quit and relaunch.

## 3. This app's wizard

- [ ] The pitch page: the icon, the headline with *well* in the icon's colour, the two capsules. Nothing is
      cut off, nothing is truncated, every sentence wraps. TEMPLATE: the permission page, if there is one,
      by the shared checklist's *The permission* section.
