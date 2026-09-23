"""Build the Classic bar textures from Blizzard's Forever (camelot) XP bar art.

Outputs, both shipped with the addon so the bar never depends on client art:

  assets/classic-bar.tga       2048x64 sheet: frame, background, divider, pip,
                               pip highlight. Regions are addressed with
                               SetTexCoord from ui/styles/classic/ClassicChrome.lua.
  assets/classic-bar-fill.tga  64x32 neutral fill, tinted at runtime. It lives in
                               its own file because a StatusBar rewrites its fill
                               texture's coordinates as the value changes, so the
                               fill cannot be a sub-rectangle of a shared sheet.

Source: the 2x camelot sheet exported from the Forever client
(Interface/HUD/UIExperienceBarCamelot2x.BLP), converted to PNG.

    python assets/raw/build_classic_bar.py [path/to/UIExperienceBarCamelot2x.PNG]

The region table printed at the end must match REGIONS in ClassicChrome.lua.
"""

import os
import struct
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.dirname(HERE)
DEFAULT_SOURCE = os.path.join(ASSETS, "refs", "xp bar", "UIExperienceBarCamelot2x.PNG")

SHEET_W, SHEET_H = 2048, 64
FILL_W, FILL_H = 64, 32

# Source rectangles in the camelot 2x sheet, (x, y, w, h), measured from the
# alpha channel.
SRC_FRAME = (0, 28, 2042, 28)
SRC_BACKGROUND_PIXEL = (1000, 10)  # flat translucent black, alpha 66
SRC_DIVIDER = (0, 424, 10, 16)
SRC_PIP = (0, 396, 22, 28)
SRC_PIP_HIGHLIGHT = (0, 364, 26, 30)

# Colored fills, top to bottom. Only their shading is used; the hue comes from
# the player's color at runtime. Tan and purple are left out of the average:
# their dark halves sit far off the others (70% and 6% of the bright half).
SRC_FILL_ROWS = {
    "red": 114, "blue": 142, "green": 170, "cyan": 198, "green2": 226,
    "orange": 254, "red2": 282, "gold": 310, "navy": 338,
}
FILL_ROWS = 23

# Where Blizzard's 14px bar sits inside its 17px frame, in frame source rows:
# the bar is inset 1px from the top and 2px from the bottom, at 28/17 source
# rows per UI pixel.
BLIZZARD_FILL_TOP = 28 / 17 * 1
BLIZZARD_FILL_ROW_HEIGHT = (28 / 17 * 14) / FILL_ROWS

# The fill rectangle, in frame source pixels (frame is 2042x28). Every corner
# of it lies under fully opaque rim, so a square-ended fill never shows outside
# the chamfered frame, while its edges still cover the rim's translucent inner
# shadow so nothing behind the bar shows through.
FILL_INSET_X = 7
FILL_INSET_Y = 6

# Destination rectangles in classic-bar.tga, (x, y, w, h).
REGIONS = {
    "frame": (0, 0, 2042, 28),
    "background": (2, 34, 32, 16),
    "divider": (48, 32, 10, 16),
    "pip": (64, 32, 22, 28),
    "pipHighlight": (96, 32, 26, 30),
}


def luminance(rgb):
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def fill_profile(src):
    """Average normalized vertical shading of Blizzard's colored fills."""
    profiles = []
    for top in SRC_FILL_ROWS.values():
        band = src[top:top + FILL_ROWS, 900:1100, :3].astype(float)
        profile = luminance(band).mean(axis=1)
        profiles.append(profile / profile.max())
    return np.mean(profiles, axis=0)


def build_fill(src):
    profile = fill_profile(src)
    top = FILL_INSET_Y
    bottom = SRC_FRAME[3] - FILL_INSET_Y
    rows = np.zeros(FILL_H)
    for k in range(FILL_H):
        # Centre of output row k, in frame source rows, then in Blizzard fill
        # rows (pixel centres at i + 0.5).
        y = top + (k + 0.5) * (bottom - top) / FILL_H
        t = (y - BLIZZARD_FILL_TOP) / BLIZZARD_FILL_ROW_HEIGHT - 0.5
        rows[k] = np.interp(t, np.arange(FILL_ROWS), profile)
    value = np.clip(np.round(rows / rows.max() * 255), 0, 255).astype(np.uint8)
    out = np.zeros((FILL_H, FILL_W, 4), dtype=np.uint8)
    out[:, :, 0] = value[:, None]
    out[:, :, 1] = value[:, None]
    out[:, :, 2] = value[:, None]
    out[:, :, 3] = 255
    return out, profile


def blit(dst, src, src_rect, dst_xy):
    x, y, w, h = src_rect
    dx, dy = dst_xy
    dst[dy:dy + h, dx:dx + w] = src[y:y + h, x:x + w]


def build_sheet(src):
    sheet = np.zeros((SHEET_H, SHEET_W, 4), dtype=np.uint8)
    blit(sheet, src, SRC_FRAME, REGIONS["frame"][:2])
    blit(sheet, src, SRC_DIVIDER, REGIONS["divider"][:2])
    blit(sheet, src, SRC_PIP, REGIONS["pip"][:2])
    blit(sheet, src, SRC_PIP_HIGHLIGHT, REGIONS["pipHighlight"][:2])

    # The background is flat, so paint it with a 2px margin on every side:
    # bilinear sampling at the region's edge then reads more background rather
    # than the transparent gutter.
    bx, by = SRC_BACKGROUND_PIXEL
    x, y, w, h = REGIONS["background"]
    sheet[y - 2:y + h + 2, x - 2:x + w + 2] = src[by, bx]
    return sheet


def top_half_color(src, top):
    band = src[top + 2:top + 9, 900:1100, :3].astype(float)
    return band.reshape(-1, 3).mean(axis=0) / 255


def write_tga(path, rgba):
    """32bpp RLE TGA, bottom-left origin, 8 alpha bits (as the other assets)."""
    h, w = rgba.shape[:2]
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 10, 0, 0, 0, 0, 0, w, h, 32, 0x08)
    body = bytearray()
    for row in rgba[::-1]:
        bgra = [bytes((p[2], p[1], p[0], p[3])) for p in row]
        i = 0
        while i < w:
            run = 1
            while i + run < w and run < 128 and bgra[i + run] == bgra[i]:
                run += 1
            if run > 1:
                body.append(0x80 | (run - 1))
                body += bgra[i]
                i += run
                continue
            start = i
            i += 1
            while i < w and i - start < 128 and (i + 1 >= w or bgra[i + 1] != bgra[i]):
                i += 1
            body.append(i - start - 1)
            for px in bgra[start:i]:
                body += px
    with open(path, "wb") as f:
        f.write(header + bytes(body))


def main():
    source = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SOURCE
    src = np.array(Image.open(source).convert("RGBA"))

    sheet = build_sheet(src)
    fill, profile = build_fill(src)
    write_tga(os.path.join(ASSETS, "classic-bar.tga"), sheet)
    write_tga(os.path.join(ASSETS, "classic-bar-fill.tga"), fill)

    print("fill profile (bright = 1.0):", " ".join(f"{v:.2f}" for v in profile))
    print("fill rows:", " ".join(str(v) for v in fill[:, 0, 0]))
    print("REGIONS (x, y, w, h) in a %dx%d sheet:" % (SHEET_W, SHEET_H))
    for name, rect in REGIONS.items():
        print(f"  {name} = {rect}")
    print("tints sampled from the bright half of each fill:")
    for name, top in SRC_FILL_ROWS.items():
        r, g, b = top_half_color(src, top)
        print(f"  {name:7s} r = {r:.2f}, g = {g:.2f}, b = {b:.2f}")


if __name__ == "__main__":
    main()
