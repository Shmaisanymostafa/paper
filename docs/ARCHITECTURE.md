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

On macOS/Linux, annotation JSON and page-copy PDFs use the same exclusive
publisher: it resolves the destination parent, rejects library paths, fully
writes a private staged file, then uses POSIX `link()` to publish a new name
without replacing files, symlinks or hardlinks. The destination is never opened
for writing. Windows/mobile annotation export uses an explicit clipboard dialog
until no-replace native publication is qualified there. Private staging and
ancestor directories are not a boundary against a hostile same-user process;
full power-loss durability is not claimed.

Sharing bounds and verifies the completed staged PDF against its fingerprint
before OS handoff. Preparation failures remove that operation's staging directory;
already handed-off files remain for OS consumers.

## Responsive UI

Desktop has a library rail and a reader tool panel. Narrow screens use a drawer
and bottom-sheet tools. Material localization and app strings follow English or
Arabic; PDFs retain their own layout and text direction. System/light/dark UI
does not invert or change document colors. IBM Plex is locally bundled. PDF font
substitution may differ from the authoring app and requires document testing.

## Extension points

Form writing and standard embedded annotations require a separate
document-editing adapter and genuine round-trip tests. Do not implement those by
painting a Flutter overlay and calling the PDF saved. OCR, signed-PDF handling,
content redaction and digital signatures remain separate milestones. Native
file-opening adapters and limited system printing exist in source and require
platform acceptance. No account/backend is needed for these capabilities.

## Page-copy editing foundation

`PageCopy` selects/reorders/duplicates pages into
new PDF bytes using the existing pinned pdfrx/PDFium dependency. It never writes
the source or library index. The reader's macOS/Linux Save As workflow requires a new
output destination and discloses that document-level forms, signatures, outlines
and app-local sidecar annotations are not preserved by this operation. This is
not text editing, form editing, redaction, OCR or signature support.

Requests are snapshotted and bounded to 1,000 output pages. Inputs and encoded
outputs are limited to 64 MiB; encoding itself can transiently allocate more,
so this byte limit is not an operating-system memory cap. Encrypted or
assembly-restricted documents are rejected, not decrypted into unsecured output.
The original fingerprint is verified before and after copying; output is opened
again and its page count checked before return. Source/output handles are disposed
on failures. Native libraries and platform release gates are unchanged.
