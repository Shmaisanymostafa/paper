"""Synthetic packaging regression tests. No OS registration or image rendering."""
import struct
import unittest
import zlib
from package_ico import SIZES, SIGNATURE, package, validate_png


def chunk(kind, payload):
    return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload) & 0xffffffff)


def png(size):
    header = struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)
    pixels = (b'\0' + b'\x00\x80\x80\xff' * size) * size
    return SIGNATURE + chunk(b'IHDR', header) + chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b'')


class IcoTests(unittest.TestCase):
    def test_container_offsets_and_unchanged_payloads(self):
        images = [(size, png(size)) for size in SIZES]
        result = package(images)
        self.assertEqual(struct.unpack('<HHH', result[:6]), (0, 1, 6))
        expected_offset = 102
        for index, (size, data) in enumerate(images):
            w, h, colors, reserved, planes, bits, length, offset = struct.unpack('<BBBBHHII', result[6+16*index:22+16*index])
            self.assertEqual((w, h, colors, reserved, planes, bits), (size % 256, size % 256, 0, 0, 1, 32))
            self.assertEqual(offset, expected_offset)
            self.assertEqual(result[offset:offset+length], data)
            expected_offset += length
        self.assertEqual(len(result), expected_offset)

    def test_requires_complete_ordered_unique_sizes(self):
        images = [(size, png(size)) for size in SIZES]
        for candidate in ([], images[:-1], images[::-1], images + images[:1]):
            with self.assertRaises(ValueError):
                package(candidate)

    def test_rejects_bad_dimensions_and_header(self):
        for data in (png(32), b'not png', SIGNATURE + chunk(b'IDAT', b'x') + chunk(b'IEND', b'')):
            with self.assertRaises(ValueError):
                validate_png(data, 16)

    def test_rejects_corruption_truncation_and_trailing_data(self):
        data = png(16)
        damaged = bytearray(data); damaged[25] ^= 1
        for candidate in (bytes(damaged), data[:-1], data + b'extra', data[:33]):
            with self.assertRaises(ValueError):
                validate_png(candidate, 16)

    def test_rejects_duplicate_header_and_missing_pixels(self):
        data = png(16)
        for candidate in (data[:33] + data[8:], data[:33] + chunk(b'IEND', b'')):
            with self.assertRaises(ValueError):
                validate_png(candidate, 16)

if __name__ == '__main__':
    unittest.main()
