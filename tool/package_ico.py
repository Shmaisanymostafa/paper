"""Wrap approved PNG size variants in ICO containers, without modifying pixels."""
from pathlib import Path
import struct
root = Path(__file__).resolve().parents[1]
for kind, output in [('app', 'app_icon.ico'), ('pdf', 'pdf_document.ico')]:
    images = [(size, (root / f'evidence/local/icon-packaging/{kind}-{size}.png').read_bytes())
              for size in [16, 32, 48, 64, 128, 256]]
    offset = 6 + 16 * len(images)
    entries = []
    for size, data in images:
        entries.append(struct.pack('<BBBBHHII', size % 256, size % 256, 0, 0, 1, 32, len(data), offset))
        offset += len(data)
    target = root / 'windows/runner/resources' / output
    target.write_bytes(struct.pack('<HHH', 0, 1, len(images)) + b''.join(entries) + b''.join(data for _, data in images))
