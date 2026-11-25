# Changelog

Changes are recorded here before release. No binary version has been qualified
by this repository review. `0.1.0-beta.2+2` is the current candidate version in
`pubspec.yaml`, not a claim of an accepted installer.

## Unreleased

### Device library, sharing and Cave theme — 2026-11-25

- **On this device** (opt-in): lists PDFs already on the device without
  copying them; a PDF is copied into the library only when opened. Android
  searches shared storage after the person grants All files access (read-only
  legacy permission up to Android 10). Windows/Linux search Desktop, Documents
  and Downloads; macOS and desktop can add folders through the system picker.
  iOS does not offer it. The scan never follows links and skips hidden folders
  and other apps' private Android data.
- **Share to Cave Paper** on Android (single and multiple PDFs).
- Files opened from another Android app keep their real name as the library
  title instead of a temporary `paper-import-…` name.
- First-page thumbnails and a "Continue reading" row in the library.
- Ctrl+O / Cmd+O opens a PDF from the library.
- **Default PDF app** help in Settings: per-platform steps, and on Windows a
  button that opens Default apps. The app still never changes defaults itself.
- Cave design-system colours, a new **Black** appearance and 10px rectangular
  buttons.

### Android installation fix — 2026-11-19

- Refuse ordinary unsigned release builds when local signing is missing;
  allow unsigned artifacts only through explicit audit opt-in.
- Document APK signature verification and preserve existing app data when
  diagnosing update/signing conflicts. A local development-signed test copy
  fixes the confirmed unsigned-artifact installation blocker.

### Release-readiness fixes — 2026-11-18

- Publish annotation JSON as a new file without replacing existing files,
  symlinks or hardlinks on macOS/Linux; use explicit clipboard export on
  Windows/mobile until safe native publication is qualified there.
- Bound and fingerprint-check staged shared PDFs before native handoff;
  abort and clean preparation files if the source changes or disappears.
- Release late native access grants after screen disposal and recover from
  bridge errors; guard disposed picker/dialog/viewer callbacks.
- Remove Android debug signing from release builds; support validated local
  signing configuration and explicitly unsigned unconfigured release output.
- Disable Xcode's injected debugger entitlement in macOS Release builds;
  retain development configuration and sandbox permissions.
- Correct native app/company metadata; add author/SPDX attribution,
  contributor/conduct/support guidance and a third-party notice index.
- Correct setup instructions and release gates; discover all tooling tests and
  verify lockfile/package notice consistency in the check command.

### Implemented candidate features

- Offline managed PDF import/read/search/outline, bookmarks and reading state.
- Fingerprinted local notes/highlights, edit/removal Undo and annotation JSON.
- English/Arabic RTL, bundled IBM Plex and system/light/dark appearance.
- Checksummed metadata generations, serialized updates and corruption recovery.
- Grouped/pinnable tools, focus mode, remembered panels and library search/sort.
- Keyboard Find, accessible page navigation and lazy original-page thumbnails.
- First-import guidance; device-wide access only through the opt-in device list.
- User-initiated unchanged-PDF sharing with optional separate annotation JSON.
- System printing on Apple/Android with explicit limits and confirmation;
  Windows/Linux backend qualification remains blocked.
- Original-preserving page-copy/reorder/duplication/rotation to a new PDF on
  macOS/Linux, with explicit fidelity-loss warnings.
- Native PDF-opening adapter/association source for five targets; device and
  installation acceptance remain separate gates.
- Opt-in device PDF listing (see above); folder syncing is not offered.

See [release readiness](docs/RELEASE_READINESS.md) for current checks and
[validation history](docs/VALIDATION.md) for earlier scoped evidence.
