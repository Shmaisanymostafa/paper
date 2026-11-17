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
