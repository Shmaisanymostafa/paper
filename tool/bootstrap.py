#!/usr/bin/env python3
"""Generate native runners without replacing Cave Paper's source or tests."""
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PLATFORMS = ('android', 'ios', 'linux', 'macos', 'windows')


def configure_platform(path: Path) -> None:
    for file in path.rglob('*'):
        if not file.is_file() or file.suffix not in {'.plist', '.pbxproj', '.xcconfig', '.swift', '.kt', '.cpp', '.cc', '.rc', '.cmake', '.txt', '.xml', '.kts'}:
            continue
        try:
            original = file.read_text()
        except UnicodeDecodeError:
            continue
        text = original.replace('technology.cave.cave_paper', 'technology.cave.paper')
        text = text.replace('technology.cave.cavePaper', 'technology.cave.paper')
        if file.name == 'AndroidManifest.xml':
            text = text.replace('android:label="cave_paper"', 'android:label="Cave Paper"')
            if 'src/main/' in file.as_posix():
                text = re.sub(r'\s*<uses-permission[^>]*android.permission.INTERNET[^>]*/>', '', text)
        if file.suffix == '.pbxproj':
            text = re.sub(r'MACOSX_DEPLOYMENT_TARGET = [0-9.]+;', 'MACOSX_DEPLOYMENT_TARGET = 12.0;', text)
            text = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;', text)
        if file.suffix == '.plist':
            text = text.replace('<string>cave_paper</string>', '<string>Cave Paper</string>')
        if file.suffix == '.xcconfig':
            text = text.replace('PRODUCT_NAME = cave_paper', 'PRODUCT_NAME = Cave Paper')
        if file.name in {'my_application.cc', 'main.cpp', 'Runner.rc'}:
            text = text.replace('L"cave_paper"', 'L"Cave Paper"')
            text = text.replace('"FileDescription", "cave_paper"', '"FileDescription", "Cave Paper"')
        if text != original:
            file.write_text(text)
    if path.name == 'macos':
        for name in ('Release.entitlements', 'DebugProfile.entitlements'):
            file = path / 'Runner' / name
            if not file.exists():
                continue
            data = plistlib.loads(file.read_bytes())
            data['com.apple.security.app-sandbox'] = True
            data['com.apple.security.files.user-selected.read-write'] = True
            data.pop('com.apple.security.network.client', None)
            if name == 'Release.entitlements':
                data.pop('com.apple.security.network.server', None)
            file.write_bytes(plistlib.dumps(data))
    podfile = path / 'Podfile'
    if podfile.exists():
        text = podfile.read_text()
        text = re.sub(r"platform :osx, '[0-9.]+'", "platform :osx, '12.0'", text)
        text = re.sub(r"platform :ios, '[0-9.]+'", "platform :ios, '15.0'", text)
        podfile.write_text(text)


def main() -> None:
    if shutil.which('flutter') is None:
        raise SystemExit('Flutter >=3.47 (Dart >=3.13) is required. No files changed.')
    if any((ROOT / p).exists() for p in PLATFORMS):
        raise SystemExit('Native folders already exist; refusing to overwrite them. Review changes manually.')
    with tempfile.TemporaryDirectory(prefix='paper-runners-') as temporary:
        generated = Path(temporary) / 'cave_paper'
        subprocess.run(['flutter', 'create', '--empty', '--no-pub', '--org', 'technology.cave',
                        '--project-name', 'cave_paper', '--platforms', ','.join(PLATFORMS),
                        str(generated)], check=True)
        for platform in PLATFORMS:
            configure_platform(generated / platform)
        for platform in PLATFORMS:
            shutil.copytree(generated / platform, ROOT / platform)
        if (generated / '.metadata').exists():
            shutil.copy2(generated / '.metadata', ROOT / '.metadata')
    print('Native runners generated. App source, tests and pubspec were preserved.')
    print('Run flutter pub get, then python3 tool/check.py. Commit the resolved lockfile and runners only after checking them.')


if __name__ == '__main__':
    main()
