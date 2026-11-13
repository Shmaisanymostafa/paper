# Dependency and licensing review

Reviewed 2026-11-12 from primary package/upstream sources. This is an engineering
inventory, not a claim that every resolved binary has been qualified.

| Selected component | License | Review and remaining requirement |
| --- | --- | --- |
| Cave Paper source | MIT | Full license at repository root |
| Flutter/Dart SDK | BSD-style plus engine notices | Not bundled here; verify exact chosen SDK notices |
| material_ui 1.0.0 | BSD-3-Clause | Official Flutter standalone Material; use its own localizations |
| pdfrx 2.12.0 | MIT | Viewer/search/outline API inspected; notice included |
| pdfium_flutter / pdfium_dart | MIT wrappers | Resolve exact versions and platform hooks after pub get |
| pdfrx_engine | MIT | Transitive engine selected by pdfrx; not manually overridden |
| PDFium native builds | BSD-style + third-party licenses | Exact artifacts/notices must be collected and inspected |
| file_selector 1.0.4 | BSD-3-Clause | Open on all five targets; Save As unavailable on Android/iOS |
| path_provider 2.1.5 | BSD-3-Clause | Native app support directory, no web target |
| crypto 3.0.7 / path 1.9.1 | BSD-3-Clause | Hashing and safe managed paths |
| IBM Plex Sans / Sans Arabic | SIL OFL 1.1 | Four unmodified TTF files and both license notices included |

## Version and offline findings

The selected pdfrx release requires Flutter >=3.47/Dart >=3.13. Its source was
inspected at `b500740c3952af87502aa33dbc0bba900783f397`. It uses the
`material_ui` family, so this application uses that consistently, including its
localization delegates. No Syncfusion or proprietary/commercial-license PDF SDK
has been selected.

The inspected pdfium_dart hook downloads non-V8 PDFium from the third-party
`bblanchon/pdfium-binaries` project, with a pinned Chromium release in the hook.
It extracts the library member, **not all of the archive's notices**. Therefore
Flutter's Dart package license screen alone is insufficient. Apple uses the
wrapper's XCFramework packaging; it must be audited independently. Preserve the
exact package lock, archive URLs, SHA256s, build hooks, native binary versions and
all license texts for each target, and check native vulnerabilities before use.

Mac continuation resolved 93 packages and committed their lockfile and license inventory.
The hook's mac-arm64 PDFium archive and native binary were verified; provenance is in
`native-pdfium-macos-arm64.json`, full notices in `assets/notices/`. The Apple
XCFramework used by native platform builds still requires a separate audit.
No native binary is distributed in this repository. Do not publish installers until
platform-native license and security qualification is complete.

## Complete the audit

1. Run `flutter pub get` in an authorized environment. Review and commit the
   resulting `pubspec.lock`; do not fabricate a lock or use floating git refs.
2. Run `python3 tool/license_inventory.py`. It collects actual LICENSE files
   from the resolved package configuration and hashes the lockfile. Missing
   texts fail. Manually classify every package and plugin, including platform,
   build-time and native dependencies; collecting a license is not compatibility
   approval.
3. Inspect the exact downloaded PDFium archives and include their full notice
   sets in `assets/notices/native/`, adding that directory to pubspec assets and
   the in-app license view. Preserve the archive hashes and provenance report.
4. Verify the MIT/BSD/Apache/OFL or other discovered obligations are satisfied.
   Stop on unknown/proprietary or incompatible terms; select another engine if
   necessary rather than claiming the release is fully open source.
5. Bundle the notices in each installer and test the license screen offline.

## Primary sources

- https://pub.dev/packages/pdfrx/versions/2.12.0
- https://github.com/espresso3389/pdfrx/blob/b500740c3952af87502aa33dbc0bba900783f397/packages/pdfrx/pubspec.yaml
- https://github.com/espresso3389/pdfrx/blob/b500740c3952af87502aa33dbc0bba900783f397/packages/pdfium_dart/hook/build.dart
- https://github.com/bblanchon/pdfium-binaries
- https://pdfium.googlesource.com/pdfium/+/refs/heads/main/LICENSE
- https://pub.dev/packages/material_ui/versions/1.0.0/license
- https://pub.dev/packages/file_selector/versions/1.0.4
- https://pub.dev/packages/path_provider/versions/2.1.5/license
- https://pub.dev/packages/crypto/versions/3.0.7/license
- https://github.com/IBM/plex

## Apple archive inspection (2026-11-13)

The exact 24,313,448-byte XCFramework archive was downloaded without execution.
Its SHA256 matches both the installed SPM/podspec pin and GitHub release metadata.
The archive includes macOS arm64/x86_64, iOS arm64, simulator and Catalyst slices.
None of its 136 ZIP entries is a LICENSE, NOTICE or COPYING file. Therefore the
wrapper MIT notice alone does not establish native redistribution compliance.
The existing Chromium 8125 notices must be reconciled with this Apple build's
upstream provenance and bundled before installer publication. This is an
identified documentation gap, not a finding of incompatible licensing.
See `native-pdfium-apple.json`. The downloaded ZIP is ignored by Git; no binary
was executed, installed or committed, and no native build was started.

### Apple notice reconciliation completed

The release-tagged `espresso3389/pdfium-xcframework` build.sh repackages seven
non-V8 Chromium 8125 upstream archives (two macOS, five iOS/Catalyst/simulator).
All seven were verified against GitHub release asset SHA256 digests. Their 19
license files are byte-identical across architectures and match all 19 original
notices already bundled under `assets/notices/native-macos-arm64/`. The combined
notice is already registered in the offline license UI. See
`apple-upstream-notices.json` for each archive URL, size, digest and notice hash.
A regression test verifies this inventory against the bundled texts.

This closes the missing upstream-notice collection/reconciliation gap for Apple
source packaging. Final installed-app notice rendering, binary build provenance
and vulnerability review remain separate release gates; no native runtime test
or blanket legal/security clearance is implied. No downloaded code was run.
