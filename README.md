# Cave Paper

**A quiet, private PDF workspace. Open source. Offline. No account.**

Cave Paper is a Flutter PDF-reader implementation for Android, iOS, macOS,
Windows and Linux. The first version keeps original PDFs unchanged and stores
reading state and annotations locally. It has no Cave Accounts dependency,
backend, advertising, analytics, remote font loading or app update service.

> **Status: development source; binary release qualification is incomplete.**
> Native runners and locked dependencies are included. Source is published at
> [Shmaisanymostafa/paper](https://github.com/Shmaisanymostafa/paper).
> See the [current release review](docs/RELEASE_READINESS.md),
> [validation history](docs/VALIDATION.md) and [remaining gates](docs/RELEASE.md).
> The beta version in `pubspec.yaml` does not identify a published installer.

## Implemented in source

- Native local-file picker; PDF import into an app-managed library (200 MiB limit).
- Opt-in **On this device** list of PDFs already on the device (Android with All files
  access; Desktop/Documents/Downloads on Windows/Linux; picked folders on desktop).
  Files are copied only when opened. See [privacy](docs/PRIVACY.md).
- Share to Cave Paper on Android; first-page thumbnails and Continue reading;
  Ctrl/Cmd+O; Default PDF app help (never changes defaults itself).
- Content-addressed deduplication, SHA-256 integrity checks and recent reading.
- Scroll, pinch/zoom, page navigation and PDF contents/outline.
- Selectable-text search with progress and highlighted results; no OCR claim.
- Saved page bookmarks, page notes and text highlights.
- Grouped icon-and-label reading tools with local favorite pins (three wide, one compact).
- Remembered reader side panel and distraction-free mode with visible restore and Escape.
- Library title search, clear search, result counts and recent/title/import sorting.
- Explicit system print dialog on Apple/Android (whole document, uniform page sizes, unprotected PDFs up to 64 MiB; notes excluded).
- Annotation JSON import/export, bound to the exact PDF fingerprint.
- New-file-only annotation export on macOS/Linux; explicit clipboard export on Windows/mobile.
- Save selected/reordered/duplicated pages with optional rotation to a new PDF on macOS/Linux.
- **Edit pages** on every platform: reorder by dragging, rotate, delete, keep only
  selected pages (split), reverse, and merge pages from other PDFs, with undo. The
  result is saved as a **new** library document; originals never change. Forms,
  signatures, outlines and Cave Paper notes are not carried into the new PDF.
- Favourites filter, reading progress ("Page 12 of 40") on each document,
  folder quick filters for **On this device**.
- Night pages (inverted page colours, display only) and a two-page view on wide screens.
- Pen drawing and six highlight/pen colours; highlights, comments and drawings
  already inside a PDF are listed under **In this PDF**.
- Android: the Default PDF app help names the app that opens PDFs now and links
  to its settings, so Cave Paper can become the default (and its icon shown).
- Password dialog for encrypted PDFs, without saving passwords.
- English/Arabic with RTL, locally bundled IBM Plex, Cave light/dark/black/system themes.
- Checksummed metadata snapshots, serialized changes and previous-generation recovery.
- Explicit removal of the imported copy, never the selected original file.

Annotations are **app-local sidecars** while you work; the original PDF is never
changed. **Save copy with highlights** (reader menu) or **PDF with highlights**
(share dialog) writes them into a *new* copy as standard PDF highlight and
sticky-note annotations that other PDF apps show (unprotected PDFs only; saved
incrementally so the original content, forms and links are kept). They are not
redactions. Share the original PDF plus the exported annotation
JSON to carry them to another Cave Paper installation. On macOS/Linux, Save As
requires a new filename outside the library and refuses existing files or links.
Windows/mobile use explicit copying of the JSON; native sharing can also attach
it as a separate file. JSON is unencrypted and may contain text selected from
password-protected PDFs. Android, iOS, macOS
and Windows offer native Share PDF with optional annotation JSON; actual native
share-sheet acceptance on each target remains pending.

Existing forms and annotations may render through PDFium. **Form filling/saving,
editing existing PDF text/images (page-level editing is supported), OCR, digital signatures, redaction,
and background syncing are not implemented. Native open-with adapters and
file-association metadata are implemented in source for all five targets, but
remain unqualified until native platform acceptance. See
[file associations](docs/FILE_ASSOCIATIONS.md). The app never changes your default
PDF viewer automatically.**

## Start development

For an Android “App not installed” error, see [installation checks](docs/ANDROID_INSTALL.md).

Requirements are selected from pdfrx 2.12.0: **Flutter >=3.47, Dart >=3.13**.
The tested SDK is **Flutter 3.47.6 stable / Dart 3.13.5**.
Repository tooling requires Git and Python 3.9+; on Windows, use `py -3` in
place of `python3` if that is how Python is installed.
Native PDFium requires a C toolchain. iOS needs Xcode on macOS; Windows needs
Visual Studio's desktop C++ tools and Developer Mode; Linux needs Flutter's GTK
build dependencies. Native code and engine binaries are downloaded at build time,
not app runtime. iOS targets 15+, macOS 12+.

```bash
git clone https://github.com/Shmaisanymostafa/paper.git
cd paper
flutter doctor -v
flutter pub get --enforce-lockfile
python3 tool/check.py
flutter run -d macos   # or linux, windows, an Android/iOS device
```

Native runners are already tracked. `tool/bootstrap.py` is a historical generation
tool and deliberately refuses an existing checkout; it is not a normal setup
step. Do not regenerate runners over the custom file-opening adapters.
Keep the genuine `pubspec.lock` committed. The check command verifies its hash
against the collected package notices without rewriting them.

To exercise real PDFium rendering locally:

```bash
python3 tool/check.py --device macos
```

This launches both native integration tests. The offline test opens the bundled synthetic PDF, extracts known text,
renders a page, and verifies that the imported bytes remain unchanged while Dart
HTTP is forbidden. The toolbar test exercises real search and reader settings.
They do not establish behavior on other platforms or a traffic capture of the
packaged app. Optional headless native tests require `PDFIUM_PATH` pointing to an
audited local PDFium binary; see [Contributing](CONTRIBUTING.md).

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
Contributions follow [Contributing](CONTRIBUTING.md) and the
[code of conduct](CODE_OF_CONDUCT.md). See [Support](SUPPORT.md) for bug reports
and [Security](SECURITY.md) for private vulnerability reporting.

## Open-source license

Cave Paper code is MIT licensed. The IBM Plex fonts are unmodified SIL OFL 1.1
assets; their notices are included. pdfrx is MIT and PDFium is BSD-style with
additional third-party notices. The precise resolved package graph and downloaded
native binaries **still require a complete notice/compatibility audit before
binary publication**. No proprietary PDF SDK is selected and no native binaries
are included in this source tree.

See [LICENSE](LICENSE), [Authors](AUTHORS.md) and the
[third-party notice index](THIRD_PARTY_NOTICES.md). Project-owned Dart and Python
source includes SPDX identifiers; third-party notices remain intact.

The Cave name and logos identify their owner; the MIT code license does not
grant trademark rights. Forks may rename the app.

## Repository status

Source is published at https://github.com/Shmaisanymostafa/paper.
No qualified beta binaries are published. No CI, cloud project, hosting,
payment or deployment has been enabled.

## Explicit sharing

Reading remains offline. **Share PDF** is an explicit user action on Android,
iOS, macOS and Windows. It hands an unchanged PDF copy to the OS share sheet,
optionally with a separate, **unencrypted** annotation JSON file, or instead a new
copy with the highlights and notes written in (unprotected PDFs only). The JSON
can contain highlighted text from protected PDFs. PDF password protection is
retained on the plain copy. Users choose the recipient/destination in the system UI.
Recipients and the system cache may retain copies. A selected share action is not
proof of delivery. Linux keeps the existing annotation Save As flow.

## Printing limits and desktop dependency gate

Printing never chooses a destination or silently submits a job; the OS may
preselect its default printer, and the user must confirm. Cave Paper supplies the
unchanged PDF bytes. This initial implementation prints the entire document at its
original uniform page size. Protected/restricted PDFs, mixed page sizes and files
over 64 MiB are refused. Annotation JSON is not printed. Actual printers, driver
behavior and mobile devices remain unqualified.

The printing plugin's Windows/Linux builds introduce an additional PDFium parser
(default version 5200, download without archive hash). Those builds MUST NOT be
released until its version, integrity and notices are pinned/reviewed or that
backend is replaced. Printing UI is hidden on Windows/Linux for now; this does
not remove the plugin from their build graphs. Apple uses OS PDF rendering for
printing. This source change does not qualify any installer for distribution.
