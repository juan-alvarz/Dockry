# App bundle files

- `Info.plist`: the bundle's metadata, copied into `Dockry.app` by `scripts/bundle.sh`.
- `AppIcon.svg`: the app icon ("Dot, magnified"), drawn on macOS's 1024-point icon grid.
- `AppIcon.iconset`: the icon at every size macOS uses, rendered from the SVG.
  `scripts/bundle.sh` turns it into `AppIcon.icns` with `iconutil`.

After changing the SVG, render the PNGs again (needs Node and Playwright with Chromium):

```bash
node scripts/render-icon.js App/AppIcon.svg App/AppIcon.iconset
```
