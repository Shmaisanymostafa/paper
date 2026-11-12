# First beta release gates

- [ ] Generate/review Android, iOS, macOS, Windows and Linux runners.
- [ ] Resolve dependencies; commit the genuine lockfile and exact SDK version.
- [ ] Format, analyze and run all Dart/widget tests with `tool/check.py`.
- [ ] Run real PDFium integration on each advertised target.
- [ ] Review all resolved and native licenses/notices, hashes and advisories.
- [ ] Test clean install, upgrade/restart, low storage and corrupt metadata recovery.
- [ ] Open text, scanned, rotated, large, encrypted and malformed PDFs.
- [ ] Test cancelled picker, wrong password, repeated import and missing files.
- [ ] Verify multiline RTL highlights, search, page restoration and note export/import.
- [ ] Check small screens, 200% text, keyboard, screen reader and light/dark mode.
- [ ] Verify originals remain byte-identical after every reader operation.
- [ ] Capture no-network behavior of the actual packaged app.
- [ ] Verify file removal, backup/restore and privacy copy against actual behavior.
- [ ] Choose app icon, public display name and store identifier before distribution.
- [ ] Produce packages, SHA256 manifests, source commit and explicit known limits.

No CI is enabled. Build/run locally first; free public CI can be proposed later,
but should not silently enable workflows contrary to the user's CI preference.
No binary release, deployment or store publication is authorized by this task.

## Public source handoff

The new source itself is intended to be public. Before publishing, inspect the
staged file list and exclude app-data directories, personal PDFs, credentials,
signing files, test logs and machine paths. Only the synthetic sample and
unmodified licensed fonts belong in this initial commit.

When GitHub creation access is available, create the new public repository under
the verified owner (`Shmaisanymostafa` in the current connector), upload main
without force-pushing, then verify commit and visibility via the connector. Do
not change or overwrite an existing repository with a similar name.
