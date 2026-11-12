#!/usr/bin/env python3
"""Collect actual package LICENSE texts after pub get; fail on missing files."""
from pathlib import Path
import hashlib
import json
import urllib.parse

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    config = ROOT / '.dart_tool/package_config.json'
    lock = ROOT / 'pubspec.lock'
    if not config.exists() or not lock.exists():
        raise SystemExit('BLOCKED: resolve and lock dependencies before auditing their licenses.')
    packages = json.loads(config.read_text())['packages']
    entries, missing, combined = [], [], []
    for package in sorted(packages, key=lambda p: p['name']):
        if package['name'] == 'cave_paper':
            continue
        uri = urllib.parse.urljoin(config.as_uri(), package['rootUri'])
        if urllib.parse.urlparse(uri).scheme != 'file':
            missing.append(package['name'])
            continue
        directory = Path(urllib.parse.unquote(urllib.parse.urlparse(uri).path))
        candidates = [directory / n for n in ['LICENSE', 'LICENSE.txt', 'LICENSE.md', 'COPYING']]
        file = next((f for f in candidates if f.is_file()), None)
        if file is None:
            missing.append(package['name'])
            continue
        data = file.read_bytes()
        entries.append({'package': package['name'], 'licenseFile': file.name,
                        'licenseSha256': hashlib.sha256(data).hexdigest()})
        combined.append('\n' + '=' * 72 + '\n' + package['name'] + '\n' + '=' * 72 + '\n' + data.decode('utf-8'))
    report = {'lockSha256': hashlib.sha256(lock.read_bytes()).hexdigest(),
              'packages': entries, 'missing': missing,
              'status': 'needs-human-license-review',
              'nativePdfiumNotices': 'REQUIRED SEPARATELY: inspect exact downloaded native archives'}
    (ROOT / 'docs/dependencies-resolved.json').write_text(json.dumps(report, indent=2) + '\n')
    (ROOT / 'assets/notices/resolved-packages.txt').write_text('\n'.join(combined))
    if missing:
        raise SystemExit('Missing license texts: ' + ', '.join(missing))
    print('Collected package notices. Review compatibility and native PDFium notices before binary distribution.')


if __name__ == '__main__':
    main()
