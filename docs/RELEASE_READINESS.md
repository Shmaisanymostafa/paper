# Release-readiness review — 2026-11-18

## Android installation follow-up — 2026-11-19

The later local APK was inspected after an installation failure on a Samsung A50
was reported. The default Flutter `app-release.apk` was identical to the unsigned
Gradle artifact (SHA-256 `35ece94e344fb6d367d5a3afbb32daeeecdab92a052282d9e489198440971151`).
SDK verification failed. A fresh install on a disposable Android 15 arm64
emulator reproduced `INSTALL_PARSE_FAILED_NO_CERTIFICATES` before runtime
permissions could be requested.

The same APK payload has been signed with the existing local development
certificate as `cave-paper-0.1.0-beta.1-test.apk`; its SHA-256 is
`f4e2f72e7fb3f8a5723becf8fc378f6f70538672fb9b12792ac5416aee348367`.
APK v2/v3 signatures and 16 KiB ZIP alignment verify, and a fresh emulator
installation succeeds. The default local Flutter download output now contains
that signed test copy; the original unsigned Gradle artifact is preserved.
Cold launch and real rendering of the bundled three-page PDF also pass on that
emulator with no crash log. All 112 original APK payload entries are byte-identical.
The final Python tooling discovery passes 36 tests after the signing-guard test.
This is a development-signed test artifact, not a production signing decision
or Samsung physical-device acceptance. Details: [Android installation](ANDROID_INSTALL.md).

Ordinary release builds now fail without configured signing; explicit unsigned
analysis requires `-Pcave.allowUnsignedRelease=true`. Actual Gradle checks verify
default rejection, explicit audit opt-in, unaffected debug configuration and
signing-report access. No new signing key, remote release or deployment was created.
The dated November 18 results below remain historical; this follow-up supersedes
their Android artifact-availability/signing status.

## Decision

Source hardening and open-source preparation are implemented on the local
`release/readiness-review` branch. Binary distribution remains gated by exact
native dependency qualification and target-specific acceptance. No artifacts,
GitHub release, store submission or remote settings were published/changed.

## Starting state and scope

Before implementation, this review read the Obsidian vault guide, Cave Paper
product checkpoint and shared repository rules, and inspected Git status,
branches, remote and recent history. The initial branch was `main` at
`a46b414a49ee3579583ad78f57129b11a1191a2e`, matching `origin/main`; the only
untracked file was `.vscode/settings.json`. Its contents are preserved and
`.vscode/` is now ignored. Changes remain local for review.

Live GitHub read-only checks confirmed a public repository, only the `main`
remote branch at that same commit, no published releases, and no branch
protection on `main`. Main and remote refs were not moved.

## Fixed issues

1. Annotation JSON export previously wrote through the selected path and could
   follow a link to truncate a PDF. PDF/JSON publication now shares an atomic
   no-replace POSIX publisher. File, symlink and hardlink destinations, including
   concurrent creation, are refused. macOS/Linux use this publisher; Windows
   and mobile retain explicit JSON clipboard export and optional native sharing.
2. Sharing verified the source before asynchronous preparation, allowing later
   source changes to reach the native share sheet. The staged copy is now bounded
   and fingerprint-verified; preparation failures clean only their own files.
3. Late native document callbacks could orphan security-scoped access after the
   library screen closed. Late grants are released, bridge failures are handled,
   and asynchronous picker/dialog/viewer work checks widget lifetime.
4. Android release builds inherited the debug signing key. Release configuration
   now uses validated local credentials or remains explicitly unsigned. Actual
   Gradle signing-report output confirms release config/store/alias are null
   without credentials; debug/profile retain their development identity.
5. macOS Release signing injected `get-task-allow` even though the source
   entitlement file omitted it. Release now disables base entitlement injection;
   rebuilt signature inspection confirms debugger/network entitlements are absent
   while sandbox, selected-file and print permissions remain.
6. Normal clone instructions called a runner-generation tool that deliberately
   refused existing runners. Setup now resolves the committed lock directly.

## Open-source preparation

- Preserved the existing MIT license and all third-party notices.
- Added author attribution and MIT SPDX headers to project-owned Dart/Python
  source without relabeling third-party/generated native code.
- Expanded contributor/security guidance; added conduct/support documents,
  feature-request routing, a notice index, EditorConfig and line-ending rules.
- Ignored local editor, environment, signing and build-distribution artifacts.
- Updated changelog, architecture and release gates to describe current scope.
- The local check command discovers every Python test and verifies the committed
  lockfile and collected license texts without rewriting them. CRLF/Unicode
  license handling is regression-tested; upstream byte hashes are preserved.
- Hosted CI stays disabled in line with the recorded project preference.

## Verification

SDK: Flutter 3.47.6 stable (`5fc346839b`) / Dart 3.13.5 on macOS arm64.

| Check | Result |
| --- | --- |
| Dependency resolution | Committed lock enforced, no dependency changes |
| Full `tool/check.py` | Passed: 121 Flutter tests, 4 optional image captures skipped; 31 Python tests at that point; formatter, source audit, notice verification and fatal-info analysis clean |
| Final Python discovery after entitlement/portability regressions | 35 passed |
| Real headless PDFium | Page-copy/protected-fixture and rotation tests passed within the 121; source originals remain unchanged |
| Package notices | 109 upstream license texts and lockfile hash verified; CRLF/Unicode and stale/missing inventory regressions pass |
| macOS release compilation | Universal arm64/x86_64 build succeeds with `--build-name=0.1.0` (70.7 MB as reported by Flutter) |
| macOS signature | `codesign --verify --deep --strict` passes; ad-hoc with no team/notarization; effective entitlements are sandbox, selected-file read/write and print only |
| Packaged notices | All 25 bundled notice assets match source bytes; generated `NOTICES.Z` contains the project's complete MIT text |
| Android signing configuration | Actual Gradle signing report passes: release identity unset without local credentials; debug/profile unchanged |
| Android Release source/manifest | Actual Gradle Kotlin + Java compilation and merged Release manifest checks pass for arm64; `debuggable=false`, no INTERNET or broad storage permission |
| Android APK packaging | Not completed: two uncached Android annotation-tool JARs block assembly; no APK, installation or device acceptance |
| iOS simulator compilation | Passed with `--debug --simulator --no-codesign --build-name=0.1.0`; no installation or physical-device acceptance |
| Windows/Linux native builds | Unavailable on this host; unqualified |
| Source/secret hygiene | Source audit and diff whitespace check pass; selected common-key history scan finds no matches; this is not an exhaustive secret/security audit |

The raw macOS arm64 hook library matches the recorded upstream binary SHA-256
`a45c44645523968525c710462691dd974f4efb1013ce1c249919a0939cfb373a`.
Flutter wrapping/signing changes the packaged binary hash; raw and packaged
provenance remain distinct. The local aggregate log is ignored at
`evidence/local/release-check.log`.

Android validation used a temporary local Maven repository containing the
unchanged official engine POM/JAR for the exact pinned module/version after
slow downloads prevented normal resolution. The official 42,168,276-byte JAR's
transport MD5 matched; its SHA-256 was
`f8876bea998ef5ac94d0af415dce3cc0896258968397eec821a8f7d45c5ebe6b`.
Repository configuration, dependencies and lockfile were not changed. The
remaining assembly downloads are `com.android.tools.external.com-intellij:intellij-core:32.1.0`
and `com.android.tools.external.com-intellij:kotlin-compiler:32.1.0`. Exact local
commands/results are ignored at `evidence/local/android-release-build.json`.
All review build/download processes were stopped after the scoped checks.

Normal Flutter release config generation was required before focused Android
compilation: invoking Gradle directly with old debug metadata retained a stale
integration-test registrant. `flutter build apk --release --config-only` with pub
enabled regenerated it correctly. This is tooling state, not a committed source
fix. The final merged manifest requests only the app's non-exported receiver
permission; it contains no network or broad storage permissions.

An initial aggregate run was stopped on a new lifecycle test's fake-async I/O
queue deadlock. The test was corrected to await initial loading before disposal;
its focused 7-test UI run and the final full suite passed. No failed/incomplete
run is counted as a pass. Native application integration journeys were not
rerun in this review, and the owner's existing preview was not launched/replaced.

## Remaining release gates and recommendations

- Qualify exact packaged native libraries, archive integrity, advisories and
  target notice sets. The pdfrx build hook does not enforce archive hashes;
  Apple upstream-notice reconciliation does not qualify Android or other targets.
- Resolve the Windows/Linux printing plugin's extra unpinned native parser
  download before distributing either build, even with printing UI hidden.
- Exercise installed Open With, Save As, real selection/thumbnails, sharing,
  printing, screen readers, mobile file-provider permissions and clean
  install/upgrade/backup flows using synthetic documents on advertised targets.
  Verify native macOS Save As can create its private sibling staging directory
  under the actual sandbox grant; filesystem tests do not establish picker access.
- Capture runtime traffic for the exact packaged app. HTTP-forbidden Dart tests
  are narrower than native-process network measurement.
- Keep a managed Android distribution key for installable/updateable releases.
  Disclose unsigned/ad-hoc Apple status or qualify proper signing/notarization.
- As a separate maintainer decision, protect `main` against deletion/force-push
  and adopt reviewed pull requests. Add required status checks if hosted CI is
  explicitly enabled; avoid requiring a check that never runs.

Follow [Release](RELEASE.md) for acceptance and publication. Full PDF text/image
editing, OCR, secure redaction, form saving and digital signatures are outside
this candidate; local annotations are sidecars rather than embedded PDF edits.
