# iOS PDF Open In adapter

Source implementation, not a verified iOS release.

- Advertises `com.adobe.pdf`, Viewer/Alternate. No system default is changed.
- Cold scene connection and warm scene URL events feed the same adapter. An
  application-delegate open-URL fallback handles non-scene URL delivery. Minimum
  supported iOS is 15; pre-UIScene iOS versions are not supported.
- Flutter deep linking is disabled so an incoming file URL is not a router path.
- `technology.cave.paper/documents`: `ready` returns pending paths, native `open`
  delivers later paths, and `release(path)` deletes only that registered staging
  directory. No caller-supplied deletion path is accepted.
- File-provider access uses NSFileCoordinator and balanced security-scoped access.
  The original is read only; a private temporary copy is supplied to Dart, whose
  repository validates and imports its own permanent managed copy.
- Native reads stream in 64 KiB blocks, require a regular non-symlink PDF file,
  check the PDF header in the first 1024 bytes, cap each file at 200 MiB and cap
  outstanding imports at eight. Before each copy, free space must exceed 2 GiB
  plus 200 MiB. Space checks are best effort, not a filesystem reservation.
- Failed staged copies are removed. Acknowledged copies are removed on release.
  Leftovers from a crashed process are removed on the next bridge initialization.
  Original URLs, contents and file names are not logged.
- Unsupported/overflow URLs are rejected. Copy/provider/space failures currently
  send an empty-path event, which the existing Dart adapter rejects and displays
  as localized `importError`. At most one failure awaits acknowledgment, and a
  two-second monotonic throttle coalesces repeated failures to prevent queue spam.
  The source only supports PDF Open In,
  not a universal iOS default viewer setting or every share-extension surface.

Validation update 2026-11-17: plist lint, Swift source checks and an unsigned iOS simulator build pass. No provider download, Open In runtime/device test or signing operation was run. Before
shipping verify cold and warm Files > Open In, iCloud/file-provider download,
denied access, oversized/malformed PDF, repeated opens, multi-file order, disk
pressure, cleanup after import and crash, unchanged original hashes, and a
release build on a physical device. File providers may require networking to
materialize a user-selected cloud file; Cave Paper itself starts no upload or
network request, but cannot promise an external provider's cloud file is offline.
