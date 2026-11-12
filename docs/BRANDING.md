# Approved Cave Paper artwork

The owner approved these two original images on 2026-11-12. Originals are
preserved unchanged in assets/branding and used with aspect-preserving layout:

- app-logo.png: 1341 x 1173, SHA256 b5b9bd216c1b5b1e9b776abc76fead57afe11cc894e615d9a9f4c35978846d01
- pdf-icon.png: 1122 x 1402, SHA256 16c2a2880c38fdf4ca3878bdf51006e2e0204b4e2f4da3b8a00347cb19fc91cc

The library navigation, About dialog and PDF list use the approved art.
Platform app icons and Windows document ICO are packaged below. macOS PDF document ICNS and installer registration remain pending.
No automatic OS default change is permitted. In Windows the default app's
ProgID controls file-icon presentation, not the mere installation of Paper.

## Platform packaging continuation

`tool/package_icons.swift` creates aspect-preserving app-icon PNGs for macOS,
iOS, Android and Linux, plus Windows size variants. iOS is flattened onto white
because app icons must be opaque. `tool/package_ico.py` wraps the exact PNG
variants in Windows ICO containers for app and document icons. Original art
remains untouched. iOS1024px opacity and Windows six-size ICO structure verified;
iOS icon visually inspected. Native installation/icon-cache checks remain pending.
