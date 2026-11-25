# Release checklist

Cave Paper source is public. A native binary is releasable only for the exact
platform and artifact qualified below; source tests do not establish installer
acceptance. See the [current review](RELEASE_READINESS.md) and
[historical evidence](VALIDATION.md). The owner accepts unsigned betas if the
functional, provenance and notice gates pass and the limitation is disclosed.
Signing/notarization must not be claimed when absent.

## Candidate and automated checks

- [ ] Select the exact source commit, version/build number and target platforms.
- [ ] Start from a clean checkout; inspect staged/untracked files for private
      documents, library folders, logs, personal paths, credentials and signing material.
- [ ] Use the recorded SDK (Flutter 3.47.6 / Dart 3.13.5) and resolve the committed
      lock with `flutter pub get --enforce-lockfile`.
- [ ] Run `python3 tool/check.py` and record pass/fail/skip counts. It discovers
      Python tests, audits source, verifies notices, checks formatting, analyzes
      Dart and runs unit/widget tests.
- [ ] Run both real PDFium integration tests with `tool/check.py --device <id>`.
      Headless page-copy/rotation tests require `PDFIUM_PATH`; qualify them on
      each platform where the feature is advertised.
- [ ] Review dependency/native advisories, exact archive/binary hashes, build
      hooks, SDK/engine notices and the installed offline license screen. Follow
      [Dependencies](DEPENDENCIES.md) and [Third-party notices](../THIRD_PARTY_NOTICES.md).

Hosted CI remains disabled under the recorded project preference. Run checks
locally and record scoped results in pull requests. Enabling hosted workflows
is a separate maintainer decision.

## Native platform gates

For Apple packaging, pass `--build-name=0.1.0` while the Dart candidate version
contains `-beta.1`; the default conversion otherwise produces `0.1.0.1`.
Use the numeric three-component marketing version in Apple bundles and record
the candidate/source commit separately. For example:

```sh
flutter build macos --release --no-pub --build-name=0.1.0
flutter build ios --simulator --debug --no-codesign --no-pub --build-name=0.1.0
```

The simulator command checks compilation; it does not produce a distributable iOS app.

| Target | Required before binary publication |
| --- | --- |
| macOS | Release build; cold/warm Open With and Save As; selection/thumbnails; sandbox permissions; packaged notices; runtime traffic check; disclose ad-hoc/unsigned status or qualify distribution signing/notarization |
| Android | APK/AAB build; inspect merged release permissions/signing identity; physical picker/content URI/chooser, sharing/printing; exact native provenance/notices |
| iOS | Appropriate native build; physical Files/Open In and provider permissions; security-scoped lifetime; sharing/printing/notices; provisioning for device distribution |
| Windows | Qualify/replace printing plugin PDFium download; native build; Inno compile/install/uninstall; per-user Open With/IPC, sharing and notices |
| Linux | Qualify/replace printing plugin PDFium download; native build; installed desktop entry/session bus and PDF opening; Save As/notices |

Windows/Linux printing UI is hidden, but the plugin remains in the build graph.
Its additional parser download has no archive hash enforcement and remains a
release blocker until replaced or qualified. The pdfrx Android/native hook also
requires exact target archive integrity and notices; Apple reconciliation alone
does not qualify Android. Do not treat a Dart UI restriction as a dependency fix.

### Android signing

Build through Flutter so it generates the proper release plugin metadata:

```sh
flutter pub get --enforce-lockfile
flutter build apk --release --target-platform=android-arm64
```

Omit `--no-pub` for the first release build after debug testing on the recorded
SDK; otherwise a stale integration-test registrant can remain. The smaller arm64
target is a build check, not a claim of support for every Android architecture.

Release builds never fall back to the public debug keystore. Without a local
`android/key.properties`, ordinary release builds stop with an actionable error. Copy
`android/key.properties.example` to the ignored `android/key.properties` to
configure your own key and all four values. `storeFile` is absolute or relative
to `android/`; use forward slashes in Windows paths. Incomplete configuration
fails instead of silently changing keys. Keep keys and passwords out of Git.

An explicitly requested unsigned audit can run Gradle with
`-Pcave.allowUnsignedRelease=true`; its output is not installable. This opt-in
does not configure signing and must not be used for a download handed to users.
Verify every downloadable APK with `apksigner verify --verbose --print-certs`
and confirm the intended signer before sharing it. See [Android installation](ANDROID_INSTALL.md).

Inspect the actual APK/AAB signer before publication. Unsigned APKs are not
normal installable betas: Android requires signing for installation and updates.
Use a deliberately managed distribution key with a safe backup and update plan,
even outside an app store. Never commit it.

See [Android's signing documentation](https://developer.android.com/studio/publish/app-signing)
for installation/update requirements and distribution key handling.

## Functional acceptance on each advertised target

- [ ] Clean install, upgrade/restart, removal and backup/restore using synthetic data.
- [ ] Low storage, missing/damaged copies and metadata recovery.
- [ ] Text, scanned, rotated, large, encrypted and malformed PDF fixtures.
- [ ] Cancelled picker, denied access, wrong password and repeated/concurrent import.
- [ ] Search, page restoration, multiline RTL highlights and note import/export.
- [ ] Sharing uses unchanged staged bytes; cancel/retry preserves originals.
- [ ] PDF/JSON Save As refuses existing files and links; cancellation writes nothing.
- [ ] Small screens, 200% text, RTL, keyboard/screen reader, light/dark modes.
- [ ] Byte-identical originals after every reader operation and export failure.
- [ ] No-network runtime capture of the exact packaged app, including missing fonts
      and external/malicious links. Dart HTTP tests do not cover native traffic.
- [ ] OS defaults remain user-controlled; verify installed icons and chooser behavior.

## Package and publish

- [ ] Build from the qualified commit and preserve those exact artifact bytes.
- [ ] Record OS/architecture, SDK, commit, hashes, licenses, signature status and
      supported/untested features. Include SHA-256 manifests and source access.
- [ ] Confirm app/engine/native notices ship and display offline after installation.
- [ ] Update CHANGELOG and the current review with final scoped results.
- [ ] Obtain explicit publication authorization for the concrete artifacts.
- [ ] Publish qualified targets and verify downloaded hashes/install behavior.

This review does not authorize deployment, a GitHub release, store submission,
changing OS defaults, paid CI or a claim of Acrobat feature parity.
