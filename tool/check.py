#!/usr/bin/env python3
# Copyright (c) 2026 Cave. See AUTHORS.md.
# SPDX-License-Identifier: MIT

"""One command for actual Flutter validation. Never substitutes a mock pass."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--device', help='Also run both native PDFium integration tests on this device.')
    args = parser.parse_args()
    if not shutil.which('flutter') or not shutil.which('dart'):
        sys.exit('BLOCKED: Flutter/Dart SDK unavailable. No Flutter tests were run.')
    commands = [
        [sys.executable, '-m', 'unittest', 'discover', '-s', 'tool', '-p', 'test_*.py'],
        [sys.executable, 'tool/audit_source.py'],
        [sys.executable, 'tool/license_inventory.py', '--check'],
        ['dart', 'format', '--output=none', '--set-exit-if-changed', 'lib', 'test', 'integration_test'],
        ['flutter', 'analyze', '--no-pub', '--fatal-infos'],
        ['flutter', 'test', '--no-pub'],
    ]
    if args.device:
        for test in ('offline_reader_test.dart', 'reader_toolbar_test.dart'):
            commands.append(['flutter', 'test', '--no-pub', f'integration_test/{test}', '-d', args.device])
    for command in commands:
        print('+ ' + ' '.join(command), flush=True)
        subprocess.run(command, cwd=ROOT, check=True)
    print('Requested checks completed. Platform builds, devices and release notices remain separate gates.')


if __name__ == '__main__':
    main()


