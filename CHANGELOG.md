# Changelog

## 0.1.0-beta.1 - unreleased source

- Implement offline managed imports, reader controls, search and outline.
- Add saved bookmarks, local notes/highlights and fingerprinted annotation JSON.
- Add English/Arabic, IBM Plex and light/dark/system modes.
- Add file-integrity, serialized metadata and corruption-recovery safeguards.
- Add unit/widget/native test sources and development/license tools.
- Flutter compilation, native packaging, complete license audit and public
  repository publication remain blocked or unverified. No installer released.

## Unreleased — 2026-11-17
- Explicit native PDF sharing with optional separate annotation JSON on Android,
  iOS, macOS and Windows, bilingual privacy warning, safe filenames and interrupted
  navigation protection. PDF password protection and original bytes are preserved.
- Added eight sharing regression tests; macOS PDFium sample integration now passes.
- No beta publication or claim of native share-sheet/device acceptance yet.

- Fixed first-run native cache creation after manual macOS share testing; added
  real native cache-provider coverage and a missing-directory regression.
- Added explicit offline system printing on Apple/Android for unchanged,
  uniform-size, unprotected PDFs up to 64 MiB; sidecar notes excluded. Eight safety
  tests and macOS sample print-preview/cancel acceptance pass. Windows/Linux
  printing and all installer publication remain blocked pending native review.
