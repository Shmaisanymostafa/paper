# Windows PDF Open With source

**Not Windows-built or release-verified.** This work adds runner source only.
No registry keys, system defaults, file associations or installed files were
changed, and no Windows toolchain/dependencies were downloaded.

## Routing and isolation

- Launch `cave_paper.exe "C:\\Documents\\example.pdf"`. Up to eight local absolute
  PDF paths are accepted, with a total UTF-16 argument payload capped at 64 KiB.
- Cold arguments enter the same bridge as warm opens. The method channel
  `technology.cave.paper/documents` implements `ready` (queued UTF-8 strings),
  native `open` (one UTF-8 string) and `release` (tracking only, never deletion).
- A user-SID-specific global mutex is held for the whole primary process. This
  prevents another instance, including one in another Windows session, from
  starting another writer for this user's library. Named-object ACL is limited
  to that user and SYSTEM. If mutex creation/acquisition or forwarding fails,
  the secondary does not start Flutter. An abandoned lock can be acquired after
  a crashed process. This lock is not a substitute for repository consistency.
- A secondary enumerates a marked HWND and checks the owning process's user SID
  and full executable path. It never routes solely by window title. A bounded
  `WM_COPYDATA` message carries a NUL-delimited UTF-16 list with a final empty
  terminator, not a command line to execute. The receiver checks identifier,
  byte count, encoding conversion, termination and count before import.
- Discovery retries briefly for startup races. An uncertain/timed-out send is
  not automatically retried, preventing duplicate imports. A different installed
  executable or another desktop session cannot be forwarded to; the user must
  close the other instance before reopening. Existing library state remains safe.
- IPC is **not an authentication boundary against same-user processes**. Another
  process at the user's integrity level can request an import or interfere with
  named objects; no elevated privileges are granted, no code is executed from
  IPC, and no arbitrary delete/write operation exists. Elevated and ordinary
  instances may not communicate because of Windows UIPI; failure is closed.

## File handling

Only absolute local drive PDF paths are allowed; remote drives, UNC/device
paths, alternate data streams, directories, reparse points (including directory
junctions), offline placeholders and invalid UTF-16 are rejected. Files must be
nonempty and at most 200 MiB. The bounded Dart repository revalidates PDF content,
streams its managed copy and preserves the original. Native size/attribute checks
are only an early filter, not a security guarantee against concurrent changes by
another process. The queue has at most eight outstanding paths plus one error
sentinel. Rejections show the existing localized import error, throttled to avoid
snackbar flooding. No source file is removed by `release`.

## Per-user installer registration source (not compiled or executed)

`windows/packaging/cave-paper.iss` adds a Windows x64 Inno Setup packaging source.
It requires Windows 10 or later and checks key Release bundle files at compile
time. It registers `Cave.Paper.PDF` under HKCU, adds only its own named value in
`.pdf\OpenWithProgids`, and lists PDF capabilities in RegisteredApplications.
The installed executable and `%1` are quoted separately; the approved packaged
`pdf_document.ico` is copied explicitly and referenced as the document icon.

The installer requests no elevation. One stable AppId upgrades the existing
per-user installation. Uninstall removes its named registration values and only
empty app-specific keys, never shared keys, another handler's values, the PDF
extension default, or the protected UserChoice setting. It contains no recursive
uninstall deletion, app-data deletion, post-install launch, or default-selection
command. Existing originals and the user's document library are not installer
payload. Install only in its dedicated application directory, not a data folder.

This makes Cave Paper a candidate, **not the forced default**. Users choose
Windows Settings > Apps > Default apps or Open With > Choose another app.
No registration was executed on any computer during this source implementation.

Packaging is deliberately compile-blocked unless `PaperNativeQualified` is
explicitly defined after dependency, notice, signing and native acceptance gates
are met. `PaperVersion` and `PaperBuildDir` must also be supplied, with the latter
pointing at a qualified Flutter Windows x64 Release bundle. The compile flag is
an operator acknowledgement, not automatic proof of qualification. Do not enable
it while the printing plugin's unverified PDFium dependency is unresolved.

Seven Python source-regression checks cover per-user scope, the exact registry
allowlist, command quoting, shared-key preservation and qualification guard.
They are not an Inno compile or Windows install/uninstall test. Before shipping,
compile with reviewed Inno Setup 6 tooling and test standard-user install,
upgrade, uninstall, another existing PDF default, Unicode/space-containing paths,
Open With discovery, default selection by user only, and preservation of foreign
values in shared registry keys. Test uninstall when Paper was manually selected
as default; the installer must not rewrite that user's choice to another app.

References: [Microsoft Open With registration](https://learn.microsoft.com/en-us/windows/win32/shell/how-to-include-an-application-on-the-open-with-dialog-box),
[Inno registry lifecycle](https://jrsoftware.org/ishelp/topic_registrysection.htm),
[association refresh](https://jrsoftware.org/ishelp/topic_setup_changesassociations.htm).

## Required Windows validation before shipping

Build with the supported Windows Flutter/C++ toolchain (warnings are errors),
then test cold/warm launches, rapid simultaneous launches, no-argument focus,
Arabic/Unicode/space-containing paths, invalid UTF-16 IPC, malformed terminators,
maximum/oversized payloads, more than eight files, nonexistent/oversized/bad PDFs,
UNC/device/ADS/junction paths, denied files, crash recovery, blocked/hung primary,
multiple installed versions, elevation mismatch and multiple Windows sessions.
Verify one writer only, unchanged original PDF hashes, correctly localized errors,
queue release, and no system-default changes. Installer association/icon testing
is separate and has not been completed.

