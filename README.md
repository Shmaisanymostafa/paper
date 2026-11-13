# Cave Paper

**A quiet, private PDF workspace. Open source. Offline. No account.**

Cave Paper is a Flutter PDF-reader implementation for Android, iOS, macOS,
Windows and Linux. The first version keeps original PDFs unchanged and stores
reading state and annotations locally. It has no Cave Accounts dependency,
backend, advertising, analytics, remote font loading or app update service.

> **Status: development source, not a qualified beta.** Mac validation now passes
> static analysis and 31 automated tests. Native runners and locked dependencies
> are included. Native installation, device acceptance and public repository
> publication remain blocked or pending. See [validation status](docs/VALIDATION.md).

## Implemented in source

- Native local-file picker; PDF import into an app-managed library (200 MiB limit).
- Content-addressed deduplication, SHA-256 integrity checks and recent reading.
- Scroll, pinch/zoom, page navigation and PDF contents/outline.
- Selectable-text search with progress and highlighted results; no OCR claim.
- Saved page bookmarks, page notes and text highlights.
- Annotation JSON import/export, bound to the exact PDF fingerprint.
- Password dialog for encrypted PDFs, without saving passwords.
- English/Arabic with RTL, locally bundled IBM Plex, light/dark/system themes.
- Checksummed metadata snapshots, serialized changes and previous-generation recovery.
- Explicit removal of the imported copy, never the selected original file.

Annotations are **app-local sidecars**, not standard annotations embedded in a
PDF. They are not redactions. Share the original PDF plus the exported annotation
JSON to carry them to another Cave Paper installation. On desktop, export uses
Save As. On mobile, the first implementation offers explicit copying of the JSON;
native share/export integration is not implemented.

Existing forms and annotations may render through PDFium. **Form filling/saving,
editing existing PDF text/images, OCR, digital signatures, redaction, printing,
and background syncing are not implemented. Native open-with adapters and
file-association metadata are implemented in source for all five targets, but
remain unqualified until native platform acceptance. See
[file associations](docs/FILE_ASSOCIATIONS.md). The app never changes your default
PDF viewer automatically.**

## Start development

Requirements are selected from pdfrx 2.12.0: **Flutter >=3.47, Dart >=3.13**.
Native PDFium requires a C toolchain. iOS needs Xcode on macOS; Windows needs
Visual Studio's desktop C++ tools and Developer Mode; Linux needs Flutter's GTK
build dependencies. Native code and engine binaries are downloaded at build time,
not app runtime. iOS targets 15+, macOS 12+.

```bash
python3 tool/bootstrap.py
flutter pub get
dart format lib test integration_test
python3 tool/license_inventory.py
python3 tool/check.py
flutter run -d macos   # or linux, windows, an Android/iOS device
```

`bootstrap.py` generates only the five native runners and refuses to overwrite
existing runners. It preserves all app source and tests, sets the native app ID
to `technology.cave.paper`, adds macOS user-selected-file entitlement and removes
release networking entitlements. Review and commit the generated runners and
resolved `pubspec.lock` after a successful build. No lockfile is fabricated here.

To exercise real PDFium rendering locally:

```bash
python3 tool/check.py --device macos
```

The integration test opens the bundled synthetic PDF, extracts known text,
renders a page, and verifies that the imported bytes remain unchanged while Dart
HTTP is forbidden. It does not establish behavior on other platforms.

## Reading workflow

1. Open a PDF, or try the bundled sample. Import makes a local copy.
2. Use search/contents, pinch or zoom controls and the page-number button.
3. Bookmark the current page. Select text, then choose **Highlight selected text**
   from the reading menu; add a page note from the same menu.
4. Reopen the app to resume. Export annotations before removing a library entry.
5. View **Settings** to see the exact data directory. Back up that whole directory
   with the app closed; it contains imported PDFs, notes and settings.

The app does not encrypt its data folder. OS permissions and device encryption
protect local files. Device backups may contain them; uninstalling can remove
app-managed copies. Passwords are memory-only. External links are never launched;
the reader offers a warning and an explicit copy action instead.

## Architecture

| Layer | Responsibility |
| --- | --- |
| `lib/domain` | Versioned document, note, geometry and annotation contracts |
| `lib/data` | Bounded import, checksums, local transactions and offline policy |
| `lib/ui` | Library, reader, settings and bilingual user-facing strings |
| `test` | Storage faults, concurrency, annotations, privacy and responsive UI |
| `integration_test` | Actual PDFium render/extract test on a native device |
| `tool` | Runner generation, one-command checks and license inventory |

See [architecture](docs/ARCHITECTURE.md), [privacy](docs/PRIVACY.md),
[license review](docs/DEPENDENCIES.md), and [release checklist](docs/RELEASE.md).

## Open-source license

Cave Paper code is MIT licensed. The IBM Plex fonts are unmodified SIL OFL 1.1
assets; their notices are included. pdfrx is MIT and PDFium is BSD-style with
additional third-party notices. The precise resolved package graph and downloaded
native binaries **still require a complete notice/compatibility audit before
binary publication**. No proprietary PDF SDK is selected and no native binaries
are included in this source tree.

The Cave name and logos identify their owner; the MIT code license does not
grant trademark rights. Forks may rename the app.

## Repository status

The intended destination is a **new public** repository, provisionally
`Shmaisanymostafa/cave-paper`. It has not been created: the connected GitHub tool
cannot create repositories, local `gh` is unauthenticated, and browser access
failed. The source is kept separately from all existing Cave products. No CI,
cloud project, hosting, payment or deployment has been enabled.
