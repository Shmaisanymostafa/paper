# Approved Cave Paper artwork

The owner approved these two original images on 2026-11-12. Originals are
preserved unchanged in assets/branding and used with aspect-preserving layout:

- app-logo.png: 1341 x 1173, SHA256 b5b9bd216c1b5b1e9b776abc76fead57afe11cc894e615d9a9f4c35978846d01
- pdf-icon.png: 1122 x 1402, SHA256 16c2a2880c38fdf4ca3878bdf51006e2e0204b4e2f4da3b8a00347cb19fc91cc

The library navigation, About dialog and PDF list use the approved art.
Platform app icons and Windows document ICO are packaged below. macOS PDF document ICNS is now packaged and registered as a bundle resource. Installer/runtime association verification remains pending.
No automatic OS default change is permitted. In Windows the default app's
ProgID controls file-icon presentation, not the mere installation of Paper.

## Platform packaging continuation

`tool/package_icons.swift` creates aspect-preserving app-icon PNGs for macOS,
iOS, Android and Linux, plus Windows size variants. iOS is flattened onto white
because app icons must be opaque. `tool/package_ico.py` wraps the exact PNG
variants in Windows ICO containers for app and document icons. Original art
remains untouched. iOS1024px opacity and Windows six-size ICO structure verified;
iOS icon visually inspected. Native installation/icon-cache checks remain pending.

`tool/package_icns.py` wraps approved 16–256px PDF PNG variants in ICNS without changing pixels. The macOS Viewer document type references this resource. Finder icon/cache and installed-app behavior remain unverified; no default application is changed.


## Repository evidence and current verification limit (2026-11-18)

The approved originals and platform variants exist in the repository. Library
navigation/About and PDF-list source reference the originals; package scripts
reference the same originals, preserve aspect ratio, and package native icons.
This is repository/source evidence, not a fresh comparison with the original
chat attachment bytes or a new native rendering check. The historical original
hashes above were recorded during integration. Current attachment retrieval and
GitHub binary access were unavailable in the cloud; neither hash was freshly
recomputed in this pass. Existing approval remains valid; no new artwork was
requested, generated or substituted.

Windows ICO packaging now validates the six ordered sizes, PNG headers,
dimensions, chunk checksums and complete endings before packaging. It validates
both app and PDF sets before writing either output. Five synthetic regression
tests verify offsets and byte-preserving payloads plus invalid-input rejection.
These checks do not decode pixels or establish visual fidelity, native rendering,
or installed OS icon-cache behavior. Existing production assets were not
regenerated or changed in this source-only pass.
