# Contributing

Thank you for helping improve Cave Paper. Follow the [code of conduct](CODE_OF_CONDUCT.md).
For questions and issue routing, see [Support](SUPPORT.md). Discuss substantial
changes in an issue first so they fit the offline PDF-reader scope.

## Local setup

The verified development SDK is Flutter **3.47.6 stable** (Dart **3.13.5**).
See [README](README.md) for platform toolchains. Native runners are already
tracked; do not run `bootstrap.py` on a normal clone.

```sh
git clone https://github.com/Shmaisanymostafa/paper.git
cd paper
git switch -c fix/describe-the-change
flutter doctor -v
flutter pub get --enforce-lockfile
python3 tool/check.py
```

Keep `pubspec.lock` committed. Do not use `pub upgrade` for unrelated fixes.
Dependencies and native build hooks download code at build time; application
runtime remains offline. Hosted CI is currently disabled; record actual local
results in your pull request.

## Changes and verification

- Keep changes focused. Describe the problem, resulting behavior and limits.
- Format Dart with `dart format lib test integration_test`. Follow existing
  conventions and `.editorconfig`; avoid unrelated formatting changes.
- Keep domain rules in `lib/domain`, storage in `lib/data`, native operations
  in `lib/services` and presentation in `lib/ui`. Preserve dependency boundaries.
- Never overwrite picked originals. Use the repository for library mutations
  and the exclusive publisher for new exported files. Add meaningful fault and
  race tests for storage changes; use temporary directories and synthetic PDFs.
- Include English and Arabic strings together. Check RTL, compact layouts,
  keyboard access and enlarged text when changing UI.
- Add no runtime networking, accounts, telemetry or remote font loading.
  Do not commit customer documents, app-data folders, logs, secrets or signing
  material. Inspect `git status` and the full diff before submitting.
- For a dependency change, regenerate and review package notices, the lockfile
  and exact native artifacts. Read [Dependencies](docs/DEPENDENCIES.md).
- Run `python3 tool/check.py`; use `--device macos` (or another available target)
  for both real PDFium integration tests. These launch a test app; close or back
  up any preview you need to preserve first. Native tests in `test/` require
  `PDFIUM_PATH` pointing to the audited library; absent prerequisites are skips,
  not passes. Record test counts, skips, OS and SDK.
- Describe manual platform checks separately. Do not claim new PDF editing
  capabilities from widget tests alone. Follow [Release](docs/RELEASE.md) before
  proposing binary distribution.

## Pull requests and licensing

Open a pull request from your topic branch and complete the verification template.
Link the issue if one exists, explain any untested areas and update user-facing
documentation/changelog when behavior changes. Prefer small reviewable commits;
never force-push the shared default branch.

By submitting code, you agree it can be distributed under the project's existing
[MIT license](LICENSE). Preserve copyright and third-party notices. Use
`SPDX-License-Identifier: MIT` in new project-owned Dart/Python source; do not
relabel generated or third-party files. Git history records individual authors;
see [Authors](AUTHORS.md).

Report security issues privately to info@cave.technology, following
[Security](SECURITY.md), without attaching private documents to public issues.
