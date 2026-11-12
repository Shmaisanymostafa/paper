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
