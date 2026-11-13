#!/usr/bin/env python3
"""Tests the actual development tooling; these are not Flutter tests."""
import importlib.util
import json
import hashlib
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest

HERE = Path(__file__).resolve().parent


def load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


audit = load('audit_source')
bootstrap = load('bootstrap')
icns = load('package_icns')


class ToolingTests(unittest.TestCase):
    def test_apple_upstream_notice_inventory_matches_bundled_notices(self):
        root = HERE.parent
        report = json.loads((root / 'docs/apple-upstream-notices.json').read_text())
        self.assertEqual(len(report), 7)
        expected = report[0]['noticeHashes']
        self.assertEqual(len(expected), 19)
        for artifact in report:
            self.assertEqual(artifact['noticeHashes'], expected)
        for name, digest in expected.items():
            local = root / 'assets/notices/native-macos-arm64' / name.replace('/', '--')
            self.assertEqual(hashlib.sha256(local.read_bytes()).hexdigest(), digest)

    def test_icns_container_preserves_png_payload_and_rejects_bad_size(self):
        root = HERE.parent
        data = (root / 'macos/Runner/PaperPDF.icns').read_bytes()
        self.assertEqual(data[:4], b'icns')
        self.assertEqual(struct.unpack('>I', data[4:8])[0], len(data))
        offset = 8
        for size, kind in icns.TYPES.items():
            self.assertEqual(data[offset:offset+4], kind)
            length = struct.unpack('>I', data[offset+4:offset+8])[0]
            png = data[offset+8:offset+length]
            self.assertEqual(struct.unpack('>II', png[16:24]), (size, size))
            self.assertEqual(icns.package([(size, png)])[16:], png)
            with self.assertRaises(ValueError):
                icns.package([(size + 1, png)])
            offset += length
        self.assertEqual(offset, len(data))
        with self.assertRaises(ValueError):
            icns.package([])

    def test_macos_document_icon_is_bundled_without_default_override(self):
        root = HERE.parent
        plist = plistlib.loads((root / 'macos/Runner/Info.plist').read_bytes())
        document = plist['CFBundleDocumentTypes'][0]
        self.assertEqual(document['CFBundleTypeIconFile'], 'PaperPDF.icns')
        self.assertEqual(document['LSHandlerRank'], 'Alternate')
        self.assertEqual(document['CFBundleTypeRole'], 'Viewer')
        project = (root / 'macos/Runner.xcodeproj/project.pbxproj').read_text()
        self.assertEqual(project.count('PaperPDF.icns in Resources'), 2)

    def test_interpolation_and_raw_regex_do_not_confuse_structural_check(self):
        self.assertEqual(audit.delimiter_errors("Text('${s['page']} ${doc.page}'); final r=RegExp(r'[a-z]');"), [])

    def test_missing_delimiter_is_reported(self):
        self.assertTrue(audit.delimiter_errors('ListTile(trailing: IconButton(icon: Icon(x)]);'))

    def test_nested_comments_and_literal_delimiters(self):
        self.assertEqual(audit.delimiter_errors("/* [ /* } */ ] */ foo('('); // }\n"), [])

    def test_android_release_has_no_network_permission(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / 'android'
            main = root / 'app/src/main/AndroidManifest.xml'
            main.parent.mkdir(parents=True)
            main.write_text('<manifest><uses-permission android:name="android.permission.INTERNET"/><application android:label="cave_paper"/></manifest>')
            bootstrap.configure_platform(root)
            self.assertNotIn('android.permission.INTERNET', main.read_text())
            self.assertIn('Cave Paper', main.read_text())

    def test_macos_release_keeps_sandbox_without_network(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / 'macos'
            runner = root / 'Runner'; runner.mkdir(parents=True)
            release = runner / 'Release.entitlements'
            release.write_bytes(plistlib.dumps({'com.apple.security.network.client': True,
                                               'com.apple.security.network.server': True}))
            cfg = runner / 'AppInfo.xcconfig'
            cfg.write_text('PRODUCT_BUNDLE_IDENTIFIER = technology.cave.cave_paper\nPRODUCT_NAME = cave_paper')
            bootstrap.configure_platform(root)
            data = plistlib.loads(release.read_bytes())
            self.assertTrue(data['com.apple.security.app-sandbox'])
            self.assertTrue(data['com.apple.security.files.user-selected.read-write'])
            self.assertNotIn('com.apple.security.network.client', data)
            self.assertNotIn('com.apple.security.network.server', data)
            self.assertIn('technology.cave.paper', cfg.read_text())

    def test_apple_minimum_versions_and_id(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / 'ios'; root.mkdir()
            file = root / 'project.pbxproj'
            file.write_text('IPHONEOS_DEPLOYMENT_TARGET = 13.0;\nPRODUCT_BUNDLE_IDENTIFIER = technology.cave.cavePaper;')
            bootstrap.configure_platform(root)
            self.assertIn('IPHONEOS_DEPLOYMENT_TARGET = 15.0;', file.read_text())
            self.assertIn('technology.cave.paper', file.read_text())


if __name__ == '__main__':
    unittest.main()
