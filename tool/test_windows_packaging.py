#!/usr/bin/env python3
"""Source regression checks, not an Inno compiler or Windows acceptance test."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'windows/packaging/cave-paper.iss').read_text()
LINES = [line.strip() for line in SOURCE.splitlines() if line.strip() and not line.lstrip().startswith(';')]
REGISTRY = [line for line in LINES if line.startswith('Root:')]

class PackagingSourceTests(unittest.TestCase):
    def test_requires_explicit_qualification_and_inputs(self):
        for name in ('PaperNativeQualified', 'PaperVersion', 'PaperBuildDir'):
            self.assertRegex(SOURCE, rf'#ifndef {name}\s+#error ')

    def test_windows_ten_and_complete_release_bundle(self):
        self.assertIn('MinVersion=10.0', LINES)
        for file in ('cave_paper.exe', 'flutter_windows.dll', 'data\\app.so', 'data\\icudtl.dat'):
            self.assertIn('FileExists(PaperBuildDir + "\\' + file + '")', SOURCE)
        self.assertIn('#error PaperBuildDir must contain the complete qualified Flutter Release bundle.', LINES)

    def test_per_user_non_elevated(self):
        self.assertIn('PrivilegesRequired=lowest', LINES)
        self.assertTrue(all(line.startswith('Root: HKCU;') for line in REGISTRY))
        self.assertFalse(any('PrivilegesRequiredOverridesAllowed' in line for line in LINES))

    def test_only_expected_registry_writes(self):
        actual = set()
        for line in REGISTRY:
            key = re.search(r'Subkey: "([^"]+)"', line).group(1)
            value = re.search(r'ValueName: "([^"]*)"', line).group(1)
            actual.add((key, value))
        self.assertEqual(actual, {
            ('Software\\Classes\\Cave.Paper.PDF', ''),
            ('Software\\Classes\\Cave.Paper.PDF\\DefaultIcon', ''),
            ('Software\\Classes\\Cave.Paper.PDF\\shell\\open\\command', ''),
            ('Software\\Classes\\.pdf\\OpenWithProgids', 'Cave.Paper.PDF'),
            ('Software\\Cave\\Paper\\Capabilities', 'ApplicationName'),
            ('Software\\Cave\\Paper\\Capabilities', 'ApplicationDescription'),
            ('Software\\Cave\\Paper\\Capabilities\\FileAssociations', '.pdf'),
            ('Software\\RegisteredApplications', 'Cave Paper'),
        })
        self.assertEqual(len(REGISTRY), len(actual))

    def test_quoted_executable_and_file_argument(self):
        line = next(line for line in REGISTRY if '\\command"' in line)
        self.assertIn('ValueData: """{app}\\cave_paper.exe"" ""%1""";', line)

    def test_uninstall_is_value_scoped(self):
        for line in REGISTRY:
            flags = line.split('Flags: ')[1].split()
            self.assertIn('uninsdeletevalue', flags)
            self.assertNotIn('uninsdeletekey', flags)
            if 'OpenWithProgids' in line or 'RegisteredApplications' in line:
                self.assertEqual(flags, ['uninsdeletevalue'])
        self.assertNotIn('[UninstallDelete]', LINES)
        self.assertNotIn('[Run]', LINES)
        self.assertNotIn('[Code]', LINES)

    def test_document_icon_and_shell_refresh(self):
        self.assertIn('ChangesAssociations=yes', LINES)
        self.assertIn('pdf_document.ico', SOURCE)
        self.assertIn('AppId=technology.cave.paper', LINES)
        self.assertIn('DisableDirPage=yes', LINES)

if __name__ == '__main__':
    unittest.main()
