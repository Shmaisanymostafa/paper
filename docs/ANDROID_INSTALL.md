# Android installation

Install a **signed APK**. The filename `app-release.apk` only describes its
build/output name; it does not prove the file was signed. Android rejects
unsigned APKs before the app can request any permissions.

## Verified issue — 2026-11-19

The local `build/app/outputs/flutter-apk/app-release.apk` was identical to
`build/app/outputs/apk/release/app-release-unsigned.apk`. SDK signature verification
failed with `DOES NOT VERIFY` / `Missing META-INF/MANIFEST.MF`. This is a concrete
installation blocker, independent of PDF/storage access permissions.

A separate `cave-paper-0.1.0-beta.1-test.apk` has been signed with the existing
local **development certificate** for testing. It contains the same application
payload, package ID and version as the unsigned build. It is not a production
signing identity or a qualified public release. Keep the private keystore local.

On a fresh disposable Android 15 arm64 emulator, the unsigned original fails
with `INSTALL_PARSE_FAILED_NO_CERTIFICATES`. The signed copy installs, cold
launches and renders the bundled three-page PDF without a crash. All 112 original
ZIP payload entries remain byte-identical; signing adds only certificate metadata.
Samsung A50 hardware acceptance is still pending the owner's check.

The APK requires Android 7.0/API 24 or later and includes `arm64-v8a`,
`armeabi-v7a` and `x86_64` native libraries. Its manifest requests no network or
broad storage permissions. PDF access uses explicit system selection.

## Before sharing an APK

Use the installed Android SDK Build Tools, replacing the tool paths as needed:

```sh
apksigner verify --verbose --print-certs path/to/app.apk
zipalign -c -P 16 4 path/to/app.apk
```

Both commands must succeed. Check that the certificate matches the intended
distribution key. Preserve the APK bytes after signing; changing them invalidates
the signature. Record its SHA-256 and test installation on a disposable device or
emulator before describing it as installable.

Ordinary release builds require local signing configuration. Explicit unsigned
audit builds are for analysis and cannot be installed. See [Release](RELEASE.md).
For production, keep the same managed distribution key across updates and back it
up securely. Do not use the development certificate as the public release key.

## If a signed APK is still rejected

Keep the full installer error or obtain the exact `adb install` error on a test
device. A generic “App not installed” message alone does not distinguish an old
Android version, unsupported architecture, damaged download, insufficient space,
a lower version code or a conflicting installed signing certificate.

Do not uninstall an existing Cave Paper installation to troubleshoot an update
without first preserving its library/annotations; uninstalling can delete local
app data. Check the old and new certificate identities first.

Allow installation from the chosen file/browser source only if Android explicitly
asks for it. Broad PDF/storage permissions do not repair an invalid APK signature.

References: [Android app signing](https://developer.android.com/studio/publish/app-signing),
[apksigner](https://developer.android.com/tools/apksigner).
