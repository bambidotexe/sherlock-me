# Changelog

Every released version, newest first. `scripts/version.sh` holds the tree's version; a local install always
builds exactly that version. `scripts/publish.sh <patch|minor|major>` is the only thing that moves it: it
bumps by that level, commits and pushes the bump before it builds anything, then releases exactly that
version, and nothing bumps it again afterward. The version at the top of this file is the one being prepared
unless a release carries its tag.

## 0.0.1

The first build. Nothing is published yet, so every update check answers *No release published yet*.

- **The Touch ID key locks, and the Mac stays locked.** A click on the key locks the Mac the instant it goes
  down, and when the finger still on the key unlocks it, SherlockMe locks it again half a second later, once.
  An unlock you make on purpose is never undone. It needs an administrator account and asks for no
  permission.
- **Touch ID in your other apps is untouched.** While an app, System Settings or the lock screen reads your
  finger, and for 3 s after, a click of the sensor does exactly what macOS makes it do: nothing. Another
  user's session on the same Mac is left alone too.
- A menu-bar item with Launch at Login, what SherlockMe is doing, Settings and Quit. A four-page Settings
  window: General, System, Health, Tip.
- A three-page welcome wizard: what the app does, where it lives, all set.
- Updates from GitHub releases: checked at launch and weekly, announced by one notification, fetched and
  installed from a window of their own, and rolled back if the new version does not start.
- A **Tip** page: everything is free and stays free, and a one-time tip on Ko-fi if you want to offer a
  coffee. Nothing is ever asked for and nothing is paid inside the app.
- Uninstall from Settings › General, which removes the Login Items entry and the preferences, and moves the
  app to the Trash.
- English and French.
