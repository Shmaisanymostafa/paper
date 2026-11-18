# Validation status - 2026-11-12

## Verified on the Mac

- Restored source commit 3de7bf6 from the owner-downloaded ZIP and Git bundle.
- Generated Android/iOS/macOS/Linux/Windows runners using installed Flutter 3.47.6 / Dart 3.13.5.
- Resolved and locked 93 packages. Collected every package license (none missing).
- Corrected nullable PDF text handling, integration-test HTTP override scope, lint findings and real-IO widget test setup.
- Static analyzer passes with fatal infos; 28 automated tests pass. Four optional UI capture tests also pass in English and Arabic at phone and desktop sizes.
- UI captures are actual Flutter test renders with a synthetic bundled PDF. They are not native app/device screenshots or evidence of native file-picker/PDFium behavior.
- Preserved exact mac-arm64 hook PDFium artifact provenance and 20 notice/version files; runtime hash matches that archive. This is not complete platform licensing/security qualification.
- Corrected bookmark page capture before queued mutation and duplicate-back navigation guard following source review. Native reader interaction regression testing remains pending.
- Six Python tooling tests and source audit passed in original workspace.

## Remaining blockers / release gates

1. Native macOS build reached Swift Package resolution but was stopped to preserve the shared disk reserve (about 2.2 GiB free). No app was built or installed.
2. Real PDFium integration, native file picking, encrypted/large/rotated PDFs, Arabic highlight geometry, network isolation, restart/upgrade and device performance need native validation.
3. Apple XCFramework and every other platform artifact need separate notice, compatibility and vulnerability review before distribution.
4. No public GitHub repository exists: available connector does not expose repository creation; no supported authenticated create/push route was available. Local Git origin still refers to the source bundle.
5. UI render Library upload failed before transfer because the prepared-upload service was unavailable. Local renders are retained under evidence/local (ignored by Git).

No backend, paid services, customer data or other product files were changed. This is development work, not a released or fully qualified product.

## Platform continuation

Approved artwork integrated and app-icon sizes packaged for all targets, plus Windows PDF ICO. Dart tests31 pass and optional captures4 pass at this stage. macOS/iOS/Android/Linux/Windows incoming-file adapter sources are present; native platform behavior is not yet verified. See platform checklists.

A coordinated macOS debug build was attempted twice after disk cleanup. Both native commands remained silent and were stopped through their owned sessions; no successful build/launch is claimed. No unrelated process was stopped. Free space remained above5GiB. No public repository exists: create-repository connector, authenticated gh and supported Browser js were unavailable.

## macOS document-icon continuation (2026-11-13)

- Added approved PDF artwork as a 16/32/64/128/256px ICNS container and bundled
  it through the Xcode Resources phase and Viewer document-type declaration.
- `plutil -lint` passed for Info.plist and project.pbxproj; Apple `sips` recognizes
  the ICNS and its largest 256px representation.
- Eight Python tooling tests pass, including ICNS structure and document-resource
  wiring. This is packaging/source validation, not a native app/runtime pass.
- No default PDF handler was changed. Native Finder rendering, cold/warm opening,
  full macOS build and public repository publication remain unverified.
- Avoided a redundant native build while disk space is constrained.

## Finish pass (2026-11-13)

- Re-ran the aggregate command: eight Python tooling checks, source hygiene,
  Dart formatting, fatal-info analyzer and 31 Flutter tests passed; four optional
  capture tests were skipped by the default suite.
- The aggregate now includes tooling/source checks and analyzes with `--no-pub`
  to avoid implicit dependency resolution during repeat validation. Run
  `flutter pub get` explicitly after a deliberate dependency change.
- Corrected README claims about file associations to distinguish implemented
  platform adapters from still-unverified native runtime behavior.
- Native building is deferred while Accounts deployment shares a disk with only
  about 2.9 GiB free; preserve the 2 GiB reserve. This is not release approval.

## Public source publication (2026-11-13)

The owner-created public repository https://github.com/Shmaisanymostafa/paper
was verified empty before publication. Commit 0ec5759 was pushed to main without
force and matched through a fresh remote ref read. A 266-blob history scan found
no matches for the checked credential patterns; tracked files contain only the
synthetic sample PDF, not personal documents or downloaded native archives.
Final source checks passed: nine tooling tests, source audit, formatting, analyzer
and 31 Flutter tests (four optional capture tests skipped).

This supersedes earlier public-repository blockers. Publication is development
source, not a packaged beta, native acceptance pass or binary release.

## 2026-11-17: explicit document sharing and native reader qualification

Added Share PDF for Android/iOS/macOS/Windows using share_plus 13.3.0
(BSD-3-Clause; resolved package notices regenerated). Users choose PDF-only or
PDF plus unencrypted, fingerprint-bound annotation JSON after bilingual disclosure.
PDF bytes/password protection are unchanged; no automatic delivery or external
recipient is selected. Native results do not imply successful delivery. Shared
copies remain in the OS temporary cache for asynchronous recipients.

Independent source review corrected native path-backed filename behavior,
reader-close cancellation, plaintext-note disclosure and Windows/UTF-8 filenames.
Eight fake-data share tests cover bytes, populated notes, PDF-only privacy,
changed/missing copies, repeats, retry, interrupted navigation and safe names.
`python3 tool/check.py` passes: 9 tooling tests, source audit, format, analyzer,
39 Flutter tests (4 optional screenshot tests skipped).

A macOS debug build succeeded. Real PDFium integration passed on macOS:
bundled three-page PDF opens, text extracts and page rasterization succeeds
with Dart HTTP forbidden; imported PDF fingerprint remains unchanged. The test
reported it could not foreground the app, so this is NOT visual desktop QA.
Native share-sheet recipient/cancel acceptance, actual device builds/installs,
Open With/default-handler flows, native notices/security qualification and
release packaging remain gates. No beta artifact was published. This remains
an offline reader, not full Acrobat feature parity.

### Native release-candidate acceptance follow-up (2026-11-17)

Manual macOS release-mode testing caught a first-run cache bug: the native path
provider can return an app cache directory that does not exist yet. Sharing now
creates it before staging. Added a missing-cache unit regression and extended the
real PDFium integration test to exercise the actual native cache provider and
verify shared PDF bytes before a fake handoff.

Final checks: 40 Flutter tests pass (4 optional captures skipped), 9 tooling tests,
source audit, formatting and analyzer pass. The extended real macOS integration
passes. Universal macOS release build succeeds (67 MB). In the actual release
app, the synthetic PDF renders and survives restart. Native share picker opens
for PDF-only (correct document title) and PDF+JSON (2 documents); both were
cancelled without selecting a recipient. The combined flow was reconfirmed after
restart; rapid repeated native picker behavior merits more device acceptance.
Sample source and imported-copy SHA256 remain equal after testing.

`codesign --verify --deep --strict` passes on the local candidate, but the build
is ad-hoc signed with no TeamIdentifier and its effective entitlements include
get-task-allow. It is NOT a distributable/notarized beta. No defaults changed,
no files sent, and no release published. Exact Apple PDFium XCFramework notice/
security qualification, distribution signing/notarization, other device/OS
acceptance and the remaining RELEASE.md gates still block public beta packaging.

### Explicit offline printing (2026-11-17)

Implemented a user-confirmed system Print PDF dialog using printing 5.15.1/pdf 3.13.1
(Apache-2.0; resolved license texts collected). Supplies byte-identical original PDF
bytes, never sidecar notes or stored passwords. Refuses protected/print-restricted,
mixed-page-size or over 64 MiB documents. Validates fingerprint before native handoff,
coalesces repeated calls, cancels if reader closed and resets after native errors.

Independent source review identified default-paper sizing, misleading default-
printer disclosure and Windows/Linux native parser issues. Source dimensions now
set the print format; mixed sizes are refused; whole-document-only behavior and
OS confirmation are explicit. Windows/Linux printing is hidden, but their plugin
build graph still downloads PDFium 5200 without archive hash. DO NOT release those
builds until backend/version/integrity/notices are replaced or qualified. See README.

Eight new printing tests cover byte preservation/landscape format, restrictions,
missing/changed copies, size bounds, closure, repeat/cancel/retry and invalid/mixed
page dimensions. Full suite passes 48 Flutter tests (4 optional captures skipped),
9 tooling tests, source audit, formatting and analyzer. macOS release build succeeds
(67.3MB). Actual native print preview displays the synthetic 3-page sample correctly;
Cancel returns to the reader. No printer was selected and no job was sent. Physical
printer output, drivers, landscape/mixed-document fixtures and mobile devices remain
unqualified. This is not Adobe feature parity or a qualified binary release.

### PDF handler and mobile compilation pass (2026-11-17)

Read-only macOS LaunchServices inspection confirms the built app claims
`com.adobe.pdf` as Viewer/Alternate with `PaperPDF.icns`. No default handler was
set. Source plists lint successfully. Added Android intent/permission, iOS
Viewer/Alternate, Linux desktop-entry and Gradle checksum regression tests.
Full Flutter/analyzer/source checks pass; tooling suite now has 13 tests.

The iOS simulator debug build succeeds with no signing or installation. No iOS
Open In/file-provider/device acceptance is implied. Android debug compilation
was attempted but interrupted by execution-environment reconnection before an
APK/result was produced; it is not a passed Android build. The wrapper now uses
the smaller official Gradle 9.3.1 binary distribution rather than the unnecessary
source/docs archive. Its downloaded checksum was verified against the official
services.gradle.org SHA256 and pinned in wrapper properties.

Windows native argument forwarding exists but installer ProgID/OpenWith
registration is still NOT implemented. Linux has a desktop-entry template only.
No Windows/Linux machine was available. The updated FILE_ASSOCIATIONS matrix
separates manifest/source, native build and actual OS file-opening acceptance.


## Reader toolbar milestone (2026-11-18)

- Flutter analysis and formatting pass; unit/widget suite: 52 pass, 4 skipped.
- 25 Python packaging/tooling tests pass; source hygiene audit passes.
- `flutter test integration_test/reader_toolbar_test.dart -d macos` passes with
  HTTP forbidden and a temporary bundled sample PDF. Verifies cancel/no-write,
  save/reopen of favorite tools, real PDF search results, compact Arabic RTL,
  and unchanged original PDF bytes. Wide English is exercised at 1280 pixels,
  compact Arabic at 390 pixels. This is not native release qualification.
- The macOS test runner could not foreground the application (`open` returned 1),
  but the built application ran and its integration assertions passed.
- Existing native signing, installer/device acceptance and PDFium provenance
  gates remain unchanged. No Acrobat editing parity is claimed.

### Page arrow controls (2026-11-18)

Previous/next buttons use logical page numbers, boundary disabling, localized
labels and direction-aware icons. Compact readers use a two-row footer to keep
the controls usable. The isolated navigation widget passes English/Arabic tests
at 320 pixels with 2x text (actions, limits and RTL ordering). Final source static
analysis passes. Native whole-reader acceptance of this later footer change is
still pending; the owner's active preview was not interrupted for tests.

### Page-copy foundation (not exposed in the reader)

On macOS, the headless native test passed with HTTP blocked using the existing
local PDFium library (`PDFIUM_PATH=build/native_assets/macos/libpdfium.dylib`).
It selects pages 3, 1, 3 from the synthetic sample, saves a separate temporary PDF,
reopens it, verifies each page's text and render, rejects out-of-range page 4,
and verifies unchanged source bytes and library metadata. Unit tests cover
selection order/duplicates, immutable request capture, empty/invalid selections
and the 1,000-page bound. Protected-document fixtures, large-file stress, native
save dialogs, and other target platforms remain unqualified. No new dependency
or license was introduced; existing PDFium distribution gates still apply.

### Save selected pages candidate (macOS/Linux)

The reader offers a warned page-sequence dialog followed by Save As. Explicit
acknowledgement is required; invalid selections remain in the dialog with an
inline error. A complete PDF is flushed to a private staged file beside the
chosen destination, then POSIX link() atomically publishes the new filename
without replacement. The destination is never opened for writing. Existing
files and links are refused even if created concurrently. Library-directory
paths and non-PDF names are refused. Windows Save As remains hidden until an
equivalent no-replace implementation is qualified.

A failure before publication leaves no destination; cleanup never deletes the
chosen destination. A staging cleanup failure may leave a private temporary copy.
This is not a defense against a hostile same-user process modifying the private
staging directory or ancestor directories. Full power-loss durability is not
claimed. Regression tests cover concurrent destination-file/link creation and
failure before publication. The final candidate passes static analysis and 63 headless tests (4 skipped);
independent focused rerun is recorded separately below when completed.

Earlier headless tests passed real output reopen, both encrypted synthetic
fixtures, and EN/AR warning/acknowledgement/Cancel at 390px. An attempted
full-reader widget test stalled and was stopped; it was replaced by isolated
dialog and native service tests, not counted as a pass. Native save picker/full
reader acceptance remains pending. The owner's app was not interrupted.

Independent final Save As review reran 7 focused tests with no skips: destination
file/link races, failure before publication, invalid paths including NUL, native
copy reopen and encrypted fixtures, and EN/AR dialog invalid-retention/cancel/
accept. All passed. No remaining source blocker found; native picker/full reader
acceptance and Linux platform qualification remain separate pending gates.


### Reader focus and remembered side panel

Combined library/focus candidate passes static analysis and 72 headless tests
(4 preexisting skips, local PDFium configured). Focus restore is tested by visible
button and Escape in LTR/RTL. Child text input and scroll survive entering/leaving
focus; Escape on a modal dismisses only that modal. Panel preference defaults to
visible for old libraries, persists across reopen and is preserved by theme/pin
updates. A local action wins over a late preference load. Focus itself is deliberately
session-only, not a permanent hidden-controls default. Saving/activity feedback
remains visible and errors/modals are not hidden by the frame. No native full-reader
focus acceptance or preview rebuild was performed in this batch.
Independent focus/settings rerun: 8/8 passed without skips; no remaining source
blocker identified. Real PDF-viewer focus geometry remains manual acceptance.

### Local note editing and Undo candidate

Static analysis passes and the combined headless suite passes 75 tests (4 skips,
local PDFium configured). The note editor is tested in English/Arabic for cancel,
reopen, save and empty validation. Repository tests exercise edit/remove/restore,
conflict rejection, duplicate-ID refusal, highlight geometry retention, persisted
metadata and unchanged original PDF bytes. Undo is a last-removal action inside
the notes panel so mobile sheets do not obscure it; it is session-only and not
permanent history. Native notes-panel interaction/Undo has not been exercised in
the owner's app; no preview restart is included in this source batch.

Independent source review and focused note rerun passed 3/3; no blocking issue
identified within this scope. Native reader-panel acceptance remains pending.

### Mobile reader tools keyboard layout

The mobile tools sheet now stays above the keyboard and scrolls its complete
panel when short viewport space cannot fit fixed search controls. Static analysis
passes. Author and independent runs each pass 4 modal-route widget cases covering
LTR/RTL, portrait/landscape, 2x text, keyboard show/hide, query retention and
route dismissal. Fixtures reproduce the fixed-header structure, not a full native
PDF viewer; physical-device keyboard acceptance remains pending. No preview
restart is part of this source batch.

### Library rail and appearance discoverability

Library sidebar collapse is remembered locally using a narrow serialized setting
update. System/Light/Dark choices now have icons, a visible Appearance entry and
a dialog-only preview; Cancel leaves stored appearance unchanged. PDF content
is not recolored. Compact 2x-text dropdown constraints were corrected.
Independent integrated checks passed 26/26 without skips (appearance, library
listing, mobile panel, notes, toolbar settings and app layout), with clean static
analysis. A test-only braces lint was fixed before that rerun. No native preview
restart or physical-device theme acceptance is included.

### Reader Find shortcuts

Ctrl+F and Command+F invoke document search, reveal controls when needed, and
request search-field focus. Shortcut handlers are scoped below modal routes;
repeated mobile activation is guarded by a synchronous single-route latch with
finally-based dismissal/error recovery. Author static analysis is clean and 11
focused shortcut/focus/mobile tests pass. These cover modifier dispatch, modal
isolation, unchanged field input, latch repetition/reopening, and prior focus
and keyboard layouts. Native PDF search-field focus and real keyboard dismissal
animation remain manual acceptance; no running preview interaction occurred.

Independent final source review and the same 11 focused tests also pass; no
blocking issue identified within this tested scope.

### Contextual local annotations

The pinned pdfrx selection-menu extension now adds local Highlight and a page
Note prefilled from selected text while preserving Copy/Select All. Both actions
require selectable text with copy permission. Async text lookup is single-flight
and validates captured selection/viewer generations, liveness and permission
again before applying. Note prefill is bounded to 10,000 characters. Original
PDF bytes remain untouched; these are sidecar annotations, not embedded edits.
Author analysis is clean and 11 focused selection/note tests pass. Invalidations
are simulated state/generation tests plus source wiring review, not native
viewer journeys. Native context-menu presentation and selected-text geometry
acceptance remain pending; the owner's preview has not been restarted.

Independent final selection/note rerun also passed 11/11 with no source blocker;
native selection gesture/menu acceptance remains a separate gate.
