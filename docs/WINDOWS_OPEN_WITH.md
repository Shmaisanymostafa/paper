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

## Optional installer registration (not implemented or executed)

A reviewed installer can register a per-user ProgID such as
`Cave.Paper.PDF` under `HKCU\\Software\\Classes`, with:

- `shell\\open\\command`: a fully quoted absolute installed executable followed
  by a separately quoted `"%1"` argument.
- `DefaultIcon`: an approved packaged PDF icon resource and resource index.
- `.pdf\\OpenWithProgids`: add `Cave.Paper.PDF` without replacing the `.pdf`
  default value or editing the protected `UserChoice` key.

This makes Cave Paper an available candidate, **not the forced default**. Users
choose Windows Settings > Apps > Default apps or Open With > Choose another app.
The selected default application's ProgID controls the displayed PDF icon; Cave
Paper cannot promise its icon while another app remains default. Installer
ownership/uninstall behavior and approved icons remain future packaging work.

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
