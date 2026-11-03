#!/usr/bin/env python3
"""Generate Chaos's blank card back. Standard library only; no source artwork.

Run from any directory: python3 scripts/generate_chaos_back.py
Optional enlarged preview: --preview /path/to/preview.png
"""

import argparse
from pathlib import Path
import struct
import zlib

WIDTH, HEIGHT = 71, 95
ROOT = Path(__file__).resolve().parents[1]

TRANSPARENT = (0, 0, 0, 0)
OUTLINE = (95, 108, 107, 255)
PAPER = (229, 229, 216, 255)
PAPER_SHADOW = (183, 192, 181, 255)
INNER_EDGE = (88, 103, 103, 255)
INK = (45, 58, 61, 255)
INSET = (69, 84, 86, 255)


def inside(x, y, inset, radius):
    """Stepped corners, with no antialiasing or fractional pixels."""
    left, top = x - inset, y - inset
    right, bottom = WIDTH - 1 - inset - x, HEIGHT - 1 - inset - y
    if min(left, top, right, bottom) < 0:
        return False
    return min(left, right) + min(top, bottom) >= radius


def pixels():
    image = []
    for y in range(HEIGHT):
        row = []
        for x in range(WIDTH):
            colour = TRANSPARENT
            if inside(x, y, 0, 4):
                colour = OUTLINE
            if inside(x, y, 1, 3):
                colour = PAPER_SHADOW if y >= HEIGHT - 3 else PAPER
            if inside(x, y, 4, 2):
                colour = INNER_EDGE
            if inside(x, y, 5, 2):
                colour = INK
            if inside(x, y, 8, 1) and not inside(x, y, 9, 1):
                colour = INSET
            row.append(colour)
        image.append(row)
    return image


def chunk(kind, data):
    return (
        struct.pack(">I", len(data))
        + kind
        + data
        + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    )


def png(image, scale):
    """RGBA PNG; integer nearest-neighbour scaling preserves the pixel silhouette."""
    raw = bytearray()
    for row in image:
        expanded = b"".join(bytes(pixel) * scale for pixel in row)
        raw.extend((b"\x00" + expanded) * scale)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", WIDTH * scale, HEIGHT * scale, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()
    image = pixels()
    assert image[0][0] == TRANSPARENT
    assert image[HEIGHT // 2][WIDTH // 2] == INK
    assert all(row == list(reversed(row)) for row in image)
    for scale in (1, 2):
        target = ROOT / "assets" / f"{scale}x" / "chaos_back.png"
        target.write_bytes(png(image, scale))
        print(f"{target.relative_to(ROOT)}: {WIDTH * scale}x{HEIGHT * scale}")
    if args.preview:
        args.preview.write_bytes(png(image, 5))


if __name__ == "__main__":
    main()
