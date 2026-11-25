#!/usr/bin/env python3
# Copyright (c) 2026 Cave. See AUTHORS.md.
# SPDX-License-Identifier: MIT

"""Native release-policy source checks; not platform build/signing acceptance."""
from pathlib import Path
import plistlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NativeReleaseTests(unittest.TestCase):
    def test_macos_release_does_not_inject_debugger_entitlements(self):
        project = (ROOT / 'macos/Runner.xcodeproj/project.pbxproj').read_text()
        configurations = re.findall(
            r'isa = XCBuildConfiguration;\s*'
            r'(?:baseConfigurationReference = [^\n]*;\s*)?'
            r'buildSettings = \{(.*?)\};\s*name = (\w+);', project, re.S)
        release = [(settings, name) for settings, name in configurations
                   if 'CODE_SIGN_ENTITLEMENTS = Runner/Release.entitlements;' in settings]
        self.assertEqual(len(release), 1)
        self.assertEqual(release[0][1], 'Release')
        self.assertIn('CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO;', release[0][0])
        for settings, name in configurations:
            if name in ('Debug', 'Profile'):
                self.assertNotIn('CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO;', settings)
        entitlements = plistlib.loads((ROOT / 'macos/Runner/Release.entitlements').read_bytes())
        for name in ('com.apple.security.get-task-allow', 'com.apple.security.cs.allow-jit',
                     'com.apple.security.network.client', 'com.apple.security.network.server'):
            self.assertFalse(entitlements.get(name, False))
        self.assertTrue(entitlements['com.apple.security.app-sandbox'])

    def test_android_release_never_falls_back_to_debug_signing(self):
        source = (ROOT / 'android/app/build.gradle.kts').read_text()
        self.assertNotIn('signingConfigs.getByName("debug")', source)
        self.assertIn('signingConfigs.getByName("release")', source)
        self.assertIn('releaseSigningConfigured = releaseSigningFile.isFile', source)
        self.assertIn('storeFile = rootProject.file(', source)
        self.assertIn('} else {\n                null\n            }', source)

    def test_android_unsigned_builds_require_explicit_audit_opt_in(self):
        source = (ROOT / 'android/app/build.gradle.kts').read_text()
        self.assertIn('providers.gradleProperty("cave.allowUnsignedRelease").orNull == "true"', source)
        self.assertRegex(source, r'if \(name == "preReleaseBuild"\)\s*\{[\s\S]*?doFirst\s*\{')
        self.assertIn('if (!signingConfigured && !unsignedAuditRequested)', source)
        self.assertIn('Android release signing is not configured.', source)
        self.assertIn('UNSIGNED AUDIT ONLY:', source)

    def test_release_secrets_are_ignored_and_example_has_only_placeholders(self):
        ignored = (ROOT / '.gitignore').read_text().splitlines()
        android_ignored = (ROOT / 'android/.gitignore').read_text().splitlines()
        self.assertTrue('key.properties' in ignored or 'key.properties' in android_ignored)
        self.assertIn('*.jks', ignored)
        self.assertIn('*.keystore', ignored)
        sample = (ROOT / 'android/key.properties.example').read_text()
        self.assertIn('storePassword=REPLACE_LOCALLY', sample)
        self.assertIn('keyPassword=REPLACE_LOCALLY', sample)

if __name__ == '__main__':
    unittest.main()
