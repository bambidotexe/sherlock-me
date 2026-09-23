# The icon

A magnifying glass in brass over a fingerprint: the Touch ID key, looked at closely. The menu-bar mark is
the same drawing at 18 pt.

| File | What it is |
|---|---|
| `AppIcon.icon/` | The Icon Composer document. `actool` compiles it into the `Assets.car` macOS renders with Liquid Glass. **Never hand-edit `icon.json`**; re-export it. |
| `AppIcon.icon/Assets/0_background.png` | The background layer. |
| `AppIcon.icon/Assets/1_lens.svg` | The glass of the lens, at 66 % opacity. |
| `AppIcon.icon/Assets/2_fingerprint.svg` | The fingerprint, navy `#233152`, without glass. |
| `AppIcon.icon/Assets/3_brass.svg` | The rim of the lens, brass `#CDA455`. |
| `AppIcon.icon/Assets/4_handle.svg` | The handle, navy. |
| `previews/SherlockMe-preview-1024.png` | The flat 1024 px master `scripts/make-app.sh` rasterises `AppIcon.icns` from, with `sips` and `iconutil`. `actool`'s own `.icns` carries 16 px and 128 px only. |
| `../docs/assets/icon.png` | The master at 256 px, which the README shows. |
| `MenuBarMark.svg` | The menu-bar mark at 18 pt: the ring, the handle, one ridge and a dot. |
| `../Sources/SherlockMeApp/MenuBarController.swift` | `icon()`, the menu-bar mark drawn in code as a template image, from the numbers of `MenuBarMark.svg`. |

The accent of the onboarding wizard, `OnboardingWindow.brand`, is the brass of the rim, not the document's
fill: the fill is a cream no word would read against.

## Replacing it

Export over `AppIcon.icon/` from **Icon Composer**, then render the master with Icon Composer's own renderer
and resize a copy for the README:

```sh
ictool="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
"$ictool" Resources/AppIcon.icon --export-image --output-file Resources/previews/SherlockMe-preview-1024.png \
  --platform macOS --rendition Default --width 1024 --height 1024 --scale 1
sips -z 256 256 Resources/previews/SherlockMe-preview-1024.png --out docs/assets/icon.png
```

If the drawing changes, replace `MenuBarMark.svg`, redraw `MenuBarController.icon()` to match it, and set
`OnboardingWindow.brand` to the new accent.

`make-app.sh` needs full Xcode for `actool`. With the Command Line Tools alone the app still builds and
still has an icon; it just loses the glass on macOS 26+, and the script says so.
