"""Wrap approved PNG variants in ICO containers without changing their pixels."""
from pathlib import Path
import struct
import zlib

SIZES = (16, 32, 48, 64, 128, 256)
MAX_PNG_BYTES = 4 * 1024 * 1024
SIGNATURE = b'\x89PNG\r\n\x1a\n'


def validate_png(data, size):
    """Check structure/integrity before packaging; this is not a PNG decoder."""
    if not isinstance(data, bytes) or not 45 <= len(data) <= MAX_PNG_BYTES:
        raise ValueError('Expected bounded PNG bytes')
    if data[:8] != SIGNATURE:
        raise ValueError('Expected PNG signature')
    offset, chunks, has_data = 8, 0, False
    while offset < len(data):
        if len(data) - offset < 12:
            raise ValueError('Truncated PNG chunk')
        length, = struct.unpack('>I', data[offset:offset + 4])
        end = offset + 12 + length
        if end > len(data):
            raise ValueError('Truncated PNG payload')
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:end - 4]
        crc, = struct.unpack('>I', data[end - 4:end])
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            raise ValueError('PNG checksum mismatch')
        if chunks == 0:
            if kind != b'IHDR' or length != 13:
                raise ValueError('Expected PNG header first')
            width, height, depth, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', payload)
            if (width, height) != (size, size):
                raise ValueError('PNG dimensions do not match variant')
            if depth != 8 or color not in (2, 6) or (compression, filtering, interlace) != (0, 0, 0):
                raise ValueError('Expected non-interlaced 8-bit RGB/RGBA PNG')
        elif kind == b'IHDR':
            raise ValueError('Duplicate PNG header')
        if kind == b'IDAT':
            has_data = True
        if kind == b'IEND':
            if length or end != len(data) or not has_data:
                raise ValueError('Invalid PNG ending')
            return
        chunks += 1
        offset = end
    raise ValueError('Missing PNG ending')


def package(images):
    images = list(images)
    if tuple(size for size, _ in images) != SIZES:
        raise ValueError('Expected the six ordered approved icon sizes')
    entries, payloads = [], []
    offset = 6 + 16 * len(images)
    for size, data in images:
        validate_png(data, size)
        entries.append(struct.pack('<BBBBHHII', size % 256, size % 256, 0, 0,
                                   1, 32, len(data), offset))
        payloads.append(data)
        offset += len(data)
    return struct.pack('<HHH', 0, 1, len(images)) + b''.join(entries) + b''.join(payloads)


def main():
    root = Path(__file__).resolve().parents[1]
    outputs = []
    for kind, output in [('app', 'app_icon.ico'), ('pdf', 'pdf_document.ico')]:
        images = [(size, (root / f'evidence/local/icon-packaging/{kind}-{size}.png').read_bytes())
                  for size in SIZES]
        outputs.append((root / 'windows/runner/resources' / output, package(images)))
    # Validate BOTH icon sets before replacing either existing output.
    for target, data in outputs:
        target.write_bytes(data)


if __name__ == '__main__':
    main()
