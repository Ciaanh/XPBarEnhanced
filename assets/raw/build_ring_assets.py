"""Render the Ring style's two textures.

  assets/ring-disc.tga  512 px, white, an anti-aliased disc of radius 254. The
                        source every ring layer is cut from: the client's radial
                        cut follows the source's texels, so it must be large.
  assets/ring-hole.tga  256 px, white, with a transparent anti-aliased disc of
                        radius 126. Used as a mask (CLAMPTOWHITE), it punches
                        the ring's hole and keeps everything outside it.
  assets/ring-cap.tga   128 px, white, the right half of an anti-aliased disc
                        of radius 62. A round arc end: its flat side, on the
                        texture's vertical centre line, sits on the arc's cut.

The discs stop short of the texture's edge to leave room for the rim. The
ratios texture size / disc diameter are DISC_TEXTURE_RATIO, HOLE_TEXTURE_RATIO
and CAP_TEXTURE_RATIO in ui/styles/ring/RingGeometry.lua: change them together.

    python assets/raw/build_ring_assets.py

Plain Python, no dependencies: uncompressed 32-bit TGA, top-left origin.
"""

import math
import os
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.dirname(HERE)


def write_disc(path, size, radius, hole=False, right_half=False):
    """White texture whose alpha is a disc (or, with hole, everything but one;
    with right_half, only the disc's half right of the vertical centre line)."""
    centre = size / 2.0
    out = bytearray(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28))
    for y in range(size):
        for x in range(size):
            distance = math.hypot(x + 0.5 - centre, y + 0.5 - centre)
            # Coverage of the pixel by the disc, over one pixel of rim.
            inside = max(0.0, min(1.0, radius - distance + 0.5))
            if right_half and x < centre:
                # The flat side is a texel boundary: a straight, hard cut.
                inside = 0.0
            alpha = 1.0 - inside if hole else inside
            out += bytes((255, 255, 255, int(round(alpha * 255))))
    with open(path, "wb") as handle:
        handle.write(out)


def main():
    write_disc(os.path.join(ASSETS, "ring-disc.tga"), 512, 254, hole=False)
    write_disc(os.path.join(ASSETS, "ring-hole.tga"), 256, 126, hole=True)
    write_disc(os.path.join(ASSETS, "ring-cap.tga"), 128, 62, right_half=True)


if __name__ == "__main__":
    main()
