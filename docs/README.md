# SherlockMe documentation

SherlockMe locks the Mac the instant the Touch ID key is clicked, and locks it again when the finger still on
the key unlocks it. Swift, SwiftPM, no Xcode project.

## Where to look

| Document | Read it when |
|---|---|
| [`functional.md`](functional.md) | You need to know what the app does: every rule, with the numbers. **The authority on behaviour.** |
| [`architecture.md`](architecture.md) | You need to know how it is built: the three targets, threading, the update, the build. |
| [`macOS.md`](macOS.md) | You are about to rely on a platform assumption of this app's own. |
| [`pitfalls.md`](pitfalls.md) | Something of this app's looks like it should work and does not. The only place that records approaches that failed. |
| [`manual-test-checklist.md`](manual-test-checklist.md) | You changed something and want to see it work. The app target has no automated tests. |
| [`shared/`](shared/README.md) | **What every app of the family shares**: the workflow, the conventions, the platform facts, the traps, the walks. Synced from `~/Projects/macos-app-template`; never edited here. |
| [`../CLAUDE.md`](../CLAUDE.md) | You are an agent working in this tree: commands, rules, traps, status. |
| [`../README.md`](../README.md) | You are a user: what it does, requirements, install, settings. |

## How to start

1. Read `CLAUDE.md` whole, then `docs/shared/workflow.md`: the workflow for a change, and the rules.
2. Read the section of `functional.md` that governs what you are about to touch, then the matching entries
   of `docs/shared/pitfalls.md` and `pitfalls.md`, then `architecture.md` for where it lives. If `CLAUDE.md`
   names a skill for that area, that skill comes first: it holds rules the documents only summarise.
3. `git status --short`. Another agent may be working in this tree; stage by path.

```sh
swift build                                     # three targets and the probe
swift test                                      # two bundles; count two summary lines
make install                                    # production build, notarized, into /Applications
/usr/bin/log stream --predicate 'subsystem == "dev.rubens.SherlockMe"' --level debug
```

## Keeping the documents true

- `functional.md` changes in the same commit as the behaviour it describes. An outdated rule is replaced,
  never annotated.
- `architecture.md` changes when a target, an object, an ownership or a thread changes.
- `macOS.md` changes when a platform fact of this app's own is learned or measured; one that every app leans
  on goes in `docs/shared/macOS.md`, in the template.
- `pitfalls.md` gains an entry when something that looked right was not; a trap any app could fall into goes
  in `docs/shared/pitfalls.md`, in the template.
- `manual-test-checklist.md` gains a line for every behaviour only a person can see.
- `CLAUDE.md` § Status says what is tagged, released and installed, and what has not been walked on hardware.
