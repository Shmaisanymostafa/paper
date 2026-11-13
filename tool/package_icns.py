"""Package approved square PNG variants without changing their pixels."""
from pathlib import Path
import struct

TYPES = {16: b'icp4', 32: b'icp5', 64: b'icp6', 128: b'ic07', 256: b'ic08'}


def package(images):
    chunks = []
    for size, data in images:
        if size not in TYPES or data[:8] != b'\x89PNG\r\n\x1a\n' or len(data) < 24:
            raise ValueError('Expected a supported PNG variant')
        if struct.unpack('>II', data[16:24]) != (size, size):
            raise ValueError('PNG dimensions do not match variant')
        chunks.append(TYPES[size] + struct.pack('>I', len(data) + 8) + data)
    if not chunks:
        raise ValueError('At least one PNG variant required')
    body = b''.join(chunks)
    return b'icns' + struct.pack('>I', len(body) + 8) + body


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    images = [(size, (root / f'evidence/local/icon-packaging/pdf-{size}.png').read_bytes())
              for size in TYPES]
    (root / 'macos/Runner/PaperPDF.icns').write_bytes(package(images))
