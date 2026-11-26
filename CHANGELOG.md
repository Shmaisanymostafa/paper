# Changelog

Changes are recorded here before release. No binary version has been qualified
by this repository review. `0.1.0-beta.5+5` is the current candidate version in
`pubspec.yaml`, not a claim of an accepted installer.

## Unreleased

### Pen, colours, highlights inside PDFs and default-app check — 2026-11-26

- **Draw with pen** (reader menu): one finger draws, two fingers zoom; six
  colours, undo last stroke, Done. Drawings are notes like highlights (listed,
  captioned, removed, exported in annotation JSON) and are written as standard
  ink annotations by "Save copy with highlights".
- **Highlight colour** (reader menu): new highlights use the chosen colour; both
  colours are remembered. Notes and drawings show their colour in the list.
- **In this PDF**: the notes panel lists highlights, text marks, comments and
  drawings already stored inside the file (by other apps or by Cave Paper's own
  saved copies), with the marked text, and jumps to their page. Read-only;
  bounded to 500 pages and 2,000 items.
- Comments inside PDFs no longer get pdfrx's blue "link" tint; only real links
  (web addresses and jumps) are tinted.
- **Default PDF app (Android)**: the help now says which app opens PDFs right
  now (and therefore whose icon file managers show) and links to that app's
  App info page to clear it. It never changes the default itself.

### Highlights saved into the PDF — 2026-11-26

- **Save copy with highlights** (reader menu) and **PDF with highlights** (share
  dialog) write Cave Paper's highlights and notes into a new copy of the PDF as
  standard annotations, so other PDF apps show them: a highlight per passage,
  with the note as its comment, and a sticky note for each page note. Written
  through PDFium's own annotation functions (`pdfium_dart`, already shipped with
  pdfrx, now a direct dependency together with `ffi`).
- The copy is saved incrementally: the original bytes come first, unchanged, so
  forms, outlines, links and existing annotations are kept. The library's
  original file and its notes never change. Encrypted PDFs and PDFs that do not
  allow annotation changes are refused.
- Verified against real PDFium in tests and rendered by Apple PDFKit by hand.

### Page editing, favourites and reading modes — 2026-11-26

- **Edit pages** (library menu and reader menu, all platforms): drag to reorder,
  rotate, delete, keep only selected pages, reverse, and add pages from other
  library PDFs or a chosen file (merge), with undo and a discard warning. Saving
  creates a new library document; the originals stay byte-for-byte unchanged.
  Protected PDFs are refused. Forms, signatures, outlines and app notes are not
  carried over.
- **Favourites**: mark documents from their menu and filter the library.
- **Reading progress**: the page count is learned when a PDF is opened and the
  library shows "Page X of Y" with a progress bar.
- **Night pages**: inverted page colours with hue correction (display only).
- **Two-page view** on wide screens, right-to-left pairs in Arabic.
- On this device: sort reads "Date modified", quick filters for the busiest
  folders (Download, WhatsApp, …).
- Phones: the library heading is left out (the app bar shows the name) and the
  Allow access button sits above the explanation, so it is visible without
  scrolling.
- Library metadata gains optional `favorite` and `pageCount`, settings gain
  `nightPages` and `twoPages`; older libraries load unchanged.

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
