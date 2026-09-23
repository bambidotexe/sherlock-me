# Changelog

Every released version, newest first. `scripts/version.sh` holds the tree's version; a local install always
builds exactly that version. `scripts/publish.sh <patch|minor|major>` is the only thing that moves it: it
bumps by that level, commits and pushes the bump before it builds anything, then releases exactly that
version, and nothing bumps it again afterward. The version at the top of this file is the one being prepared
unless a release carries its tag.

## 0.0.1

The first build. Nothing is published yet, so every update check answers *No release published yet*.

- TEMPLATE: the feature, in the words a user would use.
- A menu-bar item with Launch at Login, Settings and Quit. A three-page Settings window: General, System,
  Tip.
- A three-page welcome wizard: what the app does, where it lives, all set.
- Updates from GitHub releases: checked at launch and weekly, announced by one notification, fetched and
  installed from a window of their own, and rolled back if the new version does not start.
- A **Tip** page: everything is free and stays free, and a one-time tip on Ko-fi if you want to offer a
  coffee. Nothing is ever asked for and nothing is paid inside the app.
- Uninstall from Settings › General, which removes the Login Items entry and the preferences, and moves the
  app to the Trash.
- English and French.
