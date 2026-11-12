#!/usr/bin/env python3
"""Dependency-free source hygiene checks. NOT a Dart analyzer or Flutter test."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]


def delimiter_errors(text: str) -> list[str]:
    stack, contexts, errors = [], [('code', None)], []
    i = 0
    pairs = {'(': ')', '[': ']', '{': '}'}
    def line(at):
        return text.count('\n', 0, at) + 1
    while i < len(text):
        kind, details = contexts[-1]
        if kind == 'string':
            quote, raw = details
            if not raw and text[i] == '\\':
                i += 2
                continue
            if text.startswith(quote, i):
                contexts.pop(); i += len(quote); continue
            if not raw and text.startswith('${', i):
                stack.append(('{', i + 1))
                contexts.append(('code', len(stack)))
                i += 2
                continue
            i += 1
            continue
        if text.startswith('//', i):
            end = text.find('\n', i)
            i = len(text) if end < 0 else end
            continue
        if text.startswith('/*', i):
            depth = 1; i += 2
            while i < len(text) and depth:
                if text.startswith('/*', i): depth += 1; i += 2
                elif text.startswith('*/', i): depth -= 1; i += 2
                else: i += 1
            if depth: errors.append('unclosed comment')
            continue
        if text[i] in "\"'":
            quote = text[i] * (3 if text.startswith(text[i] * 3, i) else 1)
            raw = i > 0 and text[i-1] == 'r' and (i < 2 or not text[i-2].isalnum())
            contexts.append(('string', (quote, raw))); i += len(quote); continue
        char = text[i]
        if char in pairs:
            stack.append((char, i))
        elif char in pairs.values():
            if not stack or pairs[stack[-1][0]] != char:
                errors.append(f'mismatched {char!r} on line {line(i)}')
                break
            depth = len(stack); stack.pop()
            if details == depth and char == '}': contexts.pop()
        i += 1
    errors += [f'unclosed {char!r} on line {line(at)}' for char, at in stack]
    if len(contexts) != 1: errors.append('unclosed string/interpolation')
    return errors


def main() -> None:
    errors = []
    files = sorted(ROOT.glob('lib/**/*.dart')) + sorted(ROOT.glob('test/**/*.dart')) + sorted(ROOT.glob('integration_test/**/*.dart'))
    for file in files:
        errors += [f'{file.relative_to(ROOT)}: {e}' for e in delimiter_errors(file.read_text())]
    lib = '\n'.join(file.read_text() for file in ROOT.glob('lib/**/*.dart'))
    for pattern in [r'PdfViewer\.uri\(', r'PdfDocument\.openUri\(', r'launchUrl\(', r'Firebase', r'GoogleFonts\.']:
        if re.search(pattern, lib): errors.append('Unexpected runtime dependency: ' + pattern)
    for file in ROOT.rglob('*'):
        if not file.is_file() or '.git' in file.parts or file.suffix not in {'.dart', '.py', '.md', '.yaml'}:
            continue
        if re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|AIza[0-9A-Za-z_-]{30,}', file.read_text()):
            errors.append('Possible secret: ' + str(file.relative_to(ROOT)))
    required = ['assets/sample.pdf', 'LICENSE', 'docs/DEPENDENCIES.md', 'assets/notices/pdfrx-LICENSE.txt']
    errors += [f'Missing {name}' for name in required if not (ROOT / name).is_file()]
    report = {'kind': 'source-hygiene-not-flutter-validation', 'dartFiles': len(files),
              'errors': errors, 'sampleSha256': hashlib.sha256((ROOT / 'assets/sample.pdf').read_bytes()).hexdigest()}
    print(json.dumps(report, indent=2))
    if errors: raise SystemExit(1)


if __name__ == '__main__':
    main()
