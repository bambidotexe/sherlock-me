# The icon

**It is a placeholder.** It draws the same mark the menu-bar item draws: a rounded outline with a dot at its
centre, on the indigo the app's onboarding accents its headline with.

| File | What it is |
|---|---|
| `AppIcon.icon/` | The Icon Composer document. `actool` compiles it into the `Assets.car` macOS renders with Liquid Glass. **Never hand-edit `icon.json`**; re-export it. |
| `AppIcon.icon/Assets/mark.svg` | The mark, at 1024. |
| `previews/SherlockMe-preview-1024.png` | The flat 1024 px master `scripts/make-app.sh` rasterises `AppIcon.icns` from, with `sips` and `iconutil`. `actool`'s own `.icns` carries 16 px and 128 px only. |
| `../scripts/make-icon-preview.swift` | What generated that master, from the same numbers as the SVG. |

## Replacing it

Draw one in **Icon Composer**, export over `AppIcon.icon/`, export the 1024 px flat render over
`previews/SherlockMe-preview-1024.png`, resize a copy to 256 for `docs/assets/icon.png`, change the menu-bar
mark in `MenuBarController.icon()` and the brand colour in `OnboardingWindowController` to match, and
**delete `scripts/make-icon-preview.swift`**: it exists only so that the placeholder is reproducible, and a
real icon has Icon Composer behind it instead.

`make-app.sh` needs full Xcode for `actool`. With the Command Line Tools alone the app still builds and
still has an icon; it just loses the glass on macOS 26+, and the script says so.
