#!/usr/bin/env python3
# Copyright (c) 2026 Cave. See AUTHORS.md.
# SPDX-License-Identifier: MIT
"""License inventory regressions using synthetic packages and no SDK or network."""
import contextlib
import hashlib
import io
import json
import nturl2path
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import urllib.parse

import license_inventory


class LicenseInventoryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / '.dart_tool').mkdir()
        (self.root / 'docs').mkdir()
        (self.root / 'assets/notices').mkdir(parents=True)
        package = self.root / 'synthetic-package % كهف'
        package.mkdir()
        self.license = package / 'LICENSE'
        self.license.write_bytes('Copyright synthetic / اصطناعي\r\nPermission fixture\r\n'.encode('utf-8'))
        self.lock = self.root / 'pubspec.lock'
        self.lock.write_bytes(b'synthetic locked dependencies\n')
        config = {'packages': [{'name': 'synthetic', 'rootUri': package.as_uri()}]}
        (self.root / '.dart_tool/package_config.json').write_text(
            json.dumps(config), encoding='utf-8')
        self.outputs = [self.root / 'docs/dependencies-resolved.json',
                        self.root / 'assets/notices/resolved-packages.txt']

    def run_inventory(self, check=False):
        arguments = ['license_inventory.py', '--check'] if check else ['license_inventory.py']
        with patch.object(license_inventory, 'ROOT', self.root), \
                patch('sys.argv', arguments), contextlib.redirect_stdout(io.StringIO()):
            license_inventory.main()

    def test_crlf_notice_generates_and_checks_with_original_byte_hash(self):
        self.run_inventory()
        self.run_inventory(check=True)
        notices = self.outputs[1].read_bytes()
        self.assertNotIn(b'\r', notices)
        self.assertIn('اصطناعي'.encode('utf-8'), notices)
        report = json.loads(self.outputs[0].read_text(encoding='utf-8'))
        self.assertEqual(report['packages'][0]['licenseSha256'],
                         hashlib.sha256(self.license.read_bytes()).hexdigest())

    def test_local_uri_preserves_percent_spaces_and_unicode_in_native_path(self):
        uri = self.license.parent.as_uri()
        self.assertEqual(license_inventory.local_file_uri_path(uri), str(self.license.parent))
        parsed = urllib.parse.urlsplit(uri)
        localhost = urllib.parse.urlunsplit(('file', 'localhost', parsed.path, '', ''))
        self.assertEqual(license_inventory.local_file_uri_path(localhost), str(self.license.parent))

    def test_windows_drive_uri_uses_windows_conversion_without_leading_slash(self):
        # Exercise Windows's actual stdlib converter even on a POSIX test host.
        uri = 'file:///C:/Users/Test%20User/cache%25/%D9%83%D9%87%D9%81'
        with patch.object(license_inventory.urllib.request, 'url2pathname', nturl2path.url2pathname):
            self.assertEqual(license_inventory.local_file_uri_path(uri),
                             'C:\\Users\\Test User\\cache%\\كهف')
            self.assertEqual(license_inventory.local_file_uri_path(uri.replace('file:///', 'file://localhost/')),
                             'C:\\Users\\Test User\\cache%\\كهف')

    def test_remote_unc_uris_fail_clearly_instead_of_becoming_local_paths(self):
        for uri in ('file://server/share/package', 'file:////server/share/package'):
            with self.subTest(uri=uri):
                with self.assertRaisesRegex(ValueError, 'Remote/UNC file URIs are unsupported'):
                    license_inventory.local_file_uri_path(uri)

    def test_changed_license_or_lockfile_fails_without_rewriting_inventory(self):
        self.run_inventory()
        original_outputs = [path.read_bytes() for path in self.outputs]
        for changed in (self.license, self.lock):
            with self.subTest(changed=changed.name):
                before = changed.read_bytes()
                changed.write_bytes(before + b'changed\n')
                with self.assertRaisesRegex(SystemExit, 'Stale or missing license inventory'):
                    self.run_inventory(check=True)
                self.assertEqual([path.read_bytes() for path in self.outputs], original_outputs)
                changed.write_bytes(before)

    def test_missing_license_does_not_overwrite_existing_inventory(self):
        self.run_inventory()
        original_outputs = [path.read_bytes() for path in self.outputs]
        self.license.unlink()
        for check in (False, True):
            with self.subTest(check=check):
                with self.assertRaisesRegex(SystemExit, 'Missing license texts: synthetic'):
                    self.run_inventory(check=check)
                self.assertEqual([path.read_bytes() for path in self.outputs], original_outputs)


if __name__ == '__main__':
    unittest.main()
