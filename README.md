<p align="center">
  <img src="docs/assets/icon.png" width="256" height="256" alt="SherlockMe icon">
</p>

<h1 align="center">SherlockMe</h1>

<p align="center">
  <strong>TEMPLATE: one sentence saying what the app does for the person reading this.</strong><br>
  TEMPLATE: two or three lines on the problem it solves, and that it does nothing else.
</p>

<p align="center">
  <img alt="macOS 26+" src="https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.10-F05138?logo=swift&logoColor=white">
  <img alt="No dependencies" src="https://img.shields.io/badge/dependencies-none-1f6feb">
  <img alt="No permission" src="https://img.shields.io/badge/permissions-none-8250df">
  <img alt="English and French" src="https://img.shields.io/badge/languages-English%20%C2%B7%20Fran%C3%A7ais-333333">
</p>

## What it does

TEMPLATE: a table of *You do* / *What happens*, then the rules a user would want to know, in plain words.

## Settings

A three-page window, opened from the menu-bar item (⌘,) or by opening the app again, which is the way in
when the icon is hidden. Every change applies as you make it.

| Page | What is on it |
|---|---|
| **General** | Launch at login · Show in menu bar · Updates · Quit · Uninstall |
| **System** | the way back to the welcome wizard |
| **Tip** | everything is free and stays free · a one-time tip on Ko-fi |

The menu-bar item carries Launch at Login, Settings and Quit.

SherlockMe speaks **English and French**, following the language your Mac is set to.

## Install

Download the disk image from
[the latest release](https://github.com/bambidotexe/sherlock-me/releases/latest), open it and drag
**SherlockMe** to Applications, then open it once. It is signed with a Developer ID and notarized by Apple,
so it opens without a warning.

The first launch opens a short welcome wizard: what the app does, then where it lives. Settings › System ›
Start over opens it again.

From this repository instead:

```sh
make install
```

That builds the same signed, notarized bundle, puts it in `/Applications` and opens it, leaving no `.app`
and no `.dmg` anywhere under the repository.

SherlockMe keeps itself up to date. It looks for a newer version when it starts and once a week, and tells
you with a notification. Click **Update**, there or in Settings › General, and a small window fetches it;
**Install and Relaunch** then swaps the app and reopens it, and says so when it is back. Nothing is fetched
or installed without a click.

**Settings › General › Uninstall** is how it comes off: it removes the Login Items entry, removes its
settings and its update folder, moves itself to the Trash and quits. Dragging it to the Trash yourself
leaves the first behind, pointing at an app that is gone.

## Build from source

```sh
swift build         # three targets and the probe
swift test          # two bundles; read both summary lines
make app            # assembles build/SherlockMe.app
make install        # the real thing, into /Applications
```

It is a SwiftPM package with no Xcode project and no third-party dependency. `make app` wants full Xcode for
the `actool` that compiles the app icon; with the Command Line Tools alone it still builds, warns, and ships
the flat icon without Liquid Glass.

## Requirements

- **macOS 26 or later**, and a Swift toolchain to build it.
- **No permission.** The only thing the app ever sends over the network is its own update check.

## Documentation

| | |
|---|---|
| [CLAUDE.md](CLAUDE.md) | The operating manual for working on it: what it is, where each change lands, commands, rules, traps, status. Start here. |
| [docs/README.md](docs/README.md) | The index of the documents below. |
| [docs/functional.md](docs/functional.md) | What it does: every rule, every number. Authoritative. |
| [docs/architecture.md](docs/architecture.md) | Targets, threading, persistence, the update, the build. |
| [docs/shared/](docs/shared/README.md) | What every app of this family shares: the conventions, the workflow, the platform facts, the traps, the walks. |
| [docs/manual-test-checklist.md](docs/manual-test-checklist.md) | What only a person can see. |

## Support

SherlockMe is free and carries no ads. If it saves you trouble, you can leave a tip on
[Ko-fi](https://ko-fi.com/bambidotexe).

## Notes

- Personal build: English and French.
- The app icon is a placeholder, generated from the same mark the menu-bar item draws. See
  `Resources/ICON-NOTES.md`.
