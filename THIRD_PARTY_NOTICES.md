# Third-party notices

The [MIT license](LICENSE) covers Cave Paper's own code. It does not replace
licenses for dependencies, fonts, generated platform code or native libraries.
The Cave name and logos identify the project owner; code licensing does not
grant trademark rights.

| Component | Included license information |
| --- | --- |
| Resolved Dart/Flutter packages | [Combined texts](assets/notices/resolved-packages.txt) and [inventory with hashes](docs/dependencies-resolved.json) |
| pdfrx | [MIT notice](assets/notices/pdfrx-LICENSE.txt) |
| IBM Plex Sans | [SIL OFL 1.1](assets/notices/plex-sans-LICENSE.txt) |
| IBM Plex Sans Arabic | [SIL OFL 1.1](assets/notices/plex-sans-arabic-LICENSE.txt) |
| Audited macOS arm64 PDFium and reconciled Apple upstream notices | [Combined notice](assets/notices/pdfium-macos-arm64-LICENSE.txt), [individual texts](assets/notices/native-macos-arm64), [macOS provenance](docs/native-pdfium-macos-arm64.json), [Apple provenance](docs/apple-upstream-notices.json) |

The application registers bundled notices in its offline license screen.
After resolving the committed lockfile, verify collected package texts with:

```sh
python3 tool/license_inventory.py --check
```

After an intentional dependency update, regenerate with
`python3 tool/license_inventory.py`, inspect the resulting changes and review
native dependencies separately. Generated inventories establish what was
collected; they do not establish compatibility or security of every binary.

Before distributing a binary, collect the exact target's native notices and
SDK/engine notices, confirm they ship in the package, and record binary/archive
hashes. Windows/Linux printing currently adds an unqualified PDFium download
even though its UI is hidden. See the [dependency review](docs/DEPENDENCIES.md)
and [release gates](docs/RELEASE.md). Source publication does not qualify an installer.
