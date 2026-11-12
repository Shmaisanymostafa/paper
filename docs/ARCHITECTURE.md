# Architecture and data integrity

## Boundaries

The native Flutter app is the entire product. There are no accounts, remote
APIs, telemetry or server. pdfrx/PDFium renders locally. No PDFium V8/scripting
variant is requested. The source uses `PdfViewer.file` only; no URL loading,
dynamic font resolver, automatic external navigation or network document open
is exposed. Runtime Dart HTTP is refused through `HttpOverrides`. Native-library
behavior still needs traffic measurement on every release target.

## Import

The user picks a PDF through the system picker. The app streams into a randomly
named temporary file, enforces a byte limit, checks for a header in the first
1024 bytes, flushes the file, and computes SHA-256. A header is not a complete PDF
validity check: PDFium may still reject a malformed document. The original path
is not stored and the original file is never written or removed.

The app-managed filename is the validated 64-character content hash. Same bytes
deduplicate even if renamed; different bytes remain distinct even if named the
same. A failed metadata commit can leave an orphan imported copy, but cannot
damage the original. A reimport can recover it. Damaged managed copies are kept
under a `.damaged-*` filename instead of being silently overwritten.

## Metadata transactions

Updates serialize through a per-directory in-isolate queue plus OS advisory file
locking for other processes. The current snapshot is reread inside the lock, so
notes/bookmarks are merged against current state. A checksummed JSON envelope is
flushed to a temporary file, then renamed to an unused generation filename.
Three generations are normally retained. Unsupported future versions stop the
reader instead of falling back and overwriting newer data. A damaged generation
can fall back to an older valid one with a visible warning; this can lose the
last mutation, so users should back up the data directory.

Filesystem renames and flushes improve crash tolerance but are not proof of
power-loss durability on every filesystem. OS locks are advisory, not a defense
against another app running as the same user. Network/shared-folder library
access and multiple Flutter isolates writing the same root are not supported.

Removal commits the new index before deleting only the managed PDF. It also
requests removal of previous metadata generations to avoid resurrecting removed
notes from the ordinary local history. A failed cleanup is visible. This is not
secure disk erasure; system backups, damaged-copy evidence and storage snapshots
can retain bytes. Original source files always stay untouched.

## Notes and highlights

Each note has a random-suffixed ID, creation time, page and optional PDF-space
rectangles. Selection highlights use text-fragment geometry, not one rectangle
covering multiple columns. Rendering converts those coordinates through pdfrx's
rotation-aware conversion. Export is JSON containing the exact PDF fingerprint,
bookmarks and annotations. Import rejects different PDFs, bad geometry,
out-of-range pages, oversized payloads and conflicting IDs, and merges identical
retries without duplicates. No annotation is embedded, flattened or written into
the source PDF. Highlights do not hide or redact underlying text.

## Responsive UI

Desktop has a library rail and a reader tool panel. Narrow screens use a drawer
and bottom-sheet tools. Material localization and app strings follow English or
Arabic; PDFs retain their own layout and text direction. System/light/dark UI
does not invert or change document colors. IBM Plex is locally bundled. PDF font
substitution may differ from the authoring app and requires document testing.

## Extension points

Form writing, standard embedded annotations and Save a Copy require a separate
document-editing adapter and genuine round-trip tests. Do not implement those by
painting a Flutter overlay and calling the PDF saved. OCR, signed-PDF handling,
content redaction, operating-system file associations and printing are separate
milestones. No account/backend is needed to add them.
