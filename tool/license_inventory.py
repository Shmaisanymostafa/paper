#!/usr/bin/env python3
# Copyright (c) 2026 Cave. See AUTHORS.md.
# SPDX-License-Identifier: MIT

"""Collect actual package LICENSE texts after pub get; fail on missing files."""
from pathlib import Path
import argparse
import hashlib
import json
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def local_file_uri_path(uri: str) -> str:
    """Decode a local file URI using the host platform's path convention."""
    parsed = urllib.parse.urlsplit(uri)
    if parsed.scheme != 'file' or parsed.query or parsed.fragment:
        raise ValueError('Expected a local file URI without a query or fragment.')
    if parsed.netloc.lower() not in ('', 'localhost') or parsed.path.startswith('//'):
        raise ValueError('Remote/UNC file URIs are unsupported; use a local package cache.')
    return urllib.request.url2pathname(parsed.path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true',
                        help='Verify committed inventories without changing files.')
    args = parser.parse_args()
    config = ROOT / '.dart_tool/package_config.json'
    lock = ROOT / 'pubspec.lock'
    if not config.exists() or not lock.exists():
        raise SystemExit('BLOCKED: resolve and lock dependencies before auditing their licenses.')
    packages = json.loads(config.read_text(encoding='utf-8'))['packages']
    entries, missing, combined = [], [], []
    for package in sorted(packages, key=lambda p: p['name']):
        if package['name'] == 'cave_paper':
            continue
        uri = urllib.parse.urljoin(config.as_uri(), package['rootUri'])
        if urllib.parse.urlparse(uri).scheme != 'file':
            missing.append(package['name'])
            continue
        try:
            directory = Path(local_file_uri_path(uri))
        except (ValueError, OSError) as error:
            raise SystemExit(f'Cannot read license for {package["name"]}: {error}') from error
        candidates = [directory / n for n in ['LICENSE', 'LICENSE.txt', 'LICENSE.md', 'COPYING']]
        file = next((f for f in candidates if f.is_file()), None)
        if file is None and directory.parent.name == 'packages':
            # Flutter SDK packages inherit the SDK root's BSD license.
            sdk = directory.parent.parent
            version = sdk / 'bin/cache/flutter.version.json'
            inherited = sdk / 'LICENSE'
            if (sdk / 'bin/flutter').is_file() and version.is_file() and inherited.is_file():
                file = inherited
        if file is None:
            missing.append(package['name'])
            continue
        data = file.read_bytes()
        entries.append({'package': package['name'], 'licenseFile': file.relative_to(directory).as_posix() if file.is_relative_to(directory) else '../../LICENSE',
                        'licenseSha256': hashlib.sha256(data).hexdigest()})
        # Display text uses portable LF newlines; provenance hashes retain the
        # exact upstream bytes, including CRLF in a package's original notice.
        text = data.decode('utf-8').replace('\r\n', '\n').replace('\r', '\n')
        combined.append('\n' + '=' * 72 + '\n' + package['name'] + '\n' + '=' * 72 + '\n' + text)
    report = {'lockSha256': hashlib.sha256(lock.read_bytes()).hexdigest(),
              'packages': entries, 'missing': missing,
              'status': 'needs-human-license-review',
              'nativePdfiumNotices': 'REQUIRED SEPARATELY: inspect exact downloaded native archives'}
    if missing:
        raise SystemExit('Missing license texts: ' + ', '.join(missing))
    outputs = {
        ROOT / 'docs/dependencies-resolved.json': json.dumps(report, indent=2) + '\n',
        ROOT / 'assets/notices/resolved-packages.txt': '\n'.join(combined),
    }
    if args.check:
        stale = [str(path.relative_to(ROOT)) for path, content in outputs.items()
                 if not path.is_file() or path.read_text(encoding='utf-8') != content]
        if stale:
            raise SystemExit('Stale or missing license inventory: ' + ', '.join(stale) +
                             '. Run python3 tool/license_inventory.py and review the changes.')
        print(f'Verified {len(entries)} package license texts and the committed lockfile hash.')
        return
    for path, content in outputs.items():
        with path.open('w', encoding='utf-8', newline='\n') as output:
            output.write(content)
    print('Collected package notices. Review compatibility and native PDFium notices before binary distribution.')


if __name__ == '__main__':
    main()
