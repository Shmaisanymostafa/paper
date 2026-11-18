#!/usr/bin/env python3
"""One command for actual Flutter validation. Never substitutes a mock pass."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--device', help='Also run the real PDFium integration test on this device.')
    args = parser.parse_args()
    if not shutil.which('flutter') or not shutil.which('dart'):
        sys.exit('BLOCKED: Flutter/Dart SDK unavailable. No Flutter tests were run.')
    commands = [
        [sys.executable, 'tool/test_tooling.py'],
        [sys.executable, 'tool/test_windows_packaging.py'],
        [sys.executable, 'tool/audit_source.py'],
        ['dart', 'format', '--output=none', '--set-exit-if-changed', 'lib', 'test', 'integration_test'],
        ['flutter', 'analyze', '--no-pub', '--fatal-infos'],
        ['flutter', 'test', '--no-pub'],
    ]
    if args.device:
        commands.append(['flutter', 'test', 'integration_test/offline_reader_test.dart', '-d', args.device])
    for command in commands:
        subprocess.run(command, cwd=ROOT, check=True)
    print('Requested checks completed. Platform builds, devices and release notices remain separate gates.')


if __name__ == '__main__':
    main()

