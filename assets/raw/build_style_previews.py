"""Render the options panel's bar style previews into one premade texture.

Output: assets/style-previews.tga, a 2048x256 sheet of 224x104 cells (the
112x52 swatch canvas at 2x). Each style is split into up to three layers so the
gallery can still follow the configured XP color while drawing only a few
textures per swatch:

  under  drawn below the fill (tracks, empty segments, backgrounds)
  fill   the part tinted with the xpBar color; rendered untinted, since the
         gallery multiplies it by the color with SetVertexColor
  over   drawn above the fill (frames, rings, glass)

Every preview is composed from the addon's own textures, following the layout
the style draws, so re-run this after changing a style's art:

    python assets/raw/build_style_previews.py

The CELLS table printed at the end must match PREVIEW_CELLS in
ui/options/StyleGallery.lua.
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from build_classic_bar import REGIONS as CLASSIC_REGIONS, write_tga

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.dirname(HERE)
ADDON = os.path.dirname(ASSETS)

CANVAS_W, CANVAS_H = 112, 52  # ConfigStyleSwatchTemplate.Preview, in UI pixels
OUT_SCALE = 2                 # sheet pixels per UI pixel
SUPERSAMPLE = 4               # rendered this much finer, then box-filtered down
R = OUT_SCALE * SUPERSAMPLE
CELL_W, CELL_H = CANVAS_W * OUT_SCALE, CANVAS_H * OUT_SCALE
SHEET_W, SHEET_H = 2048, 256
COLUMNS = SHEET_W // CELL_W

# Every miniature shows the same progress so shape, not value, is what differs.
FILL_RATIO = 0.65

WHITE = (1.0, 1.0, 1.0, 1.0)
TRACK_COLOR = (0.10, 0.10, 0.11, 0.9)
EMPTY_SEGMENT_COLOR = (0.28, 0.28, 0.30, 0.7)
OUTLINE_COLOR = (0.42, 0.42, 0.45, 0.8)
DISABLED_TEXT = (0.5, 0.5, 0.5, 1.0)


def load(name):
    return Image.open(os.path.join(ASSETS, name)).convert("RGBA")


XP_BAR = load("xp-bar.tga")
RING_CENTER = load("center.tga")
RING_BORDER = load("border.tga")
ORB_RING = load("orb_ring.tga")
ORB_GLASS = load("orb_glass.tga")
CLASSIC_SHEET = load("classic-bar.tga")
CLASSIC_FILL = load("classic-bar-fill.tga")
TERMINAL_FONT = os.path.join(ADDON, "fonts", "DejaVuSansMono.ttf")


# ---------------------------------------------------------------------------
# Canvas: float RGBA, premultiplied, at R pixels per UI pixel. Coordinates are
# UI pixels relative to the canvas centre with y up, as SetPoint offsets are.
# ---------------------------------------------------------------------------

class Canvas:
    def __init__(self):
        self.px = np.zeros((CANVAS_H * R, CANVAS_W * R, 4))

    def to_image_xy(self, x, y):
        return (CANVAS_W / 2 + x) * R, (CANVAS_H / 2 - y) * R

    def composite(self, layer, left, top):
        """Premultiplied 'over' of `layer` (float RGBA) at image pixel left/top."""
        h, w = layer.shape[:2]
        x0, y0 = int(round(left)), int(round(top))
        cx0, cy0 = max(x0, 0), max(y0, 0)
        cx1, cy1 = min(x0 + w, self.px.shape[1]), min(y0 + h, self.px.shape[0])
        if cx1 <= cx0 or cy1 <= cy0:
            return
        src = layer[cy0 - y0:cy1 - y0, cx0 - x0:cx1 - x0]
        dst = self.px[cy0:cy1, cx0:cx1]
        dst[:] = src + dst * (1 - src[..., 3:4])

    def downsample(self):
        h, w = CELL_H, CELL_W
        blocks = self.px.reshape(h, SUPERSAMPLE, w, SUPERSAMPLE, 4).mean(axis=(1, 3))
        alpha = blocks[..., 3:4]
        rgb = np.where(alpha > 0, blocks[..., :3] / np.maximum(alpha, 1e-6), 0)
        out = np.concatenate([rgb, alpha], axis=-1)
        return np.clip(np.round(out * 255), 0, 255).astype(np.uint8)


def premultiplied(image, tint=WHITE):
    a = np.asarray(image, dtype=float) / 255
    a[..., :3] *= tint[:3]
    a[..., 3] *= tint[3]
    a[..., :3] *= a[..., 3:4]
    return a


def anchor_fractions(anchor):
    """How far across (0..1, from the left) and down (0..1, from the top) the
    anchor point lies on its region."""
    fx = 0.0 if "LEFT" in anchor else (1.0 if "RIGHT" in anchor else 0.5)
    fy = 0.0 if "TOP" in anchor else (1.0 if "BOTTOM" in anchor else 0.5)
    return fx, fy


def draw_image(canvas, image, x, y, w, h, tint=WHITE, rotation=0.0, anchor="CENTER", mask=None):
    """Draw `image` sized w x h UI pixels with its `anchor` point at (x, y)."""
    size = (max(1, int(round(w * R))), max(1, int(round(h * R))))
    img = image.resize(size, Image.BILINEAR)
    if rotation:
        img = img.rotate(math.degrees(rotation), resample=Image.BICUBIC, expand=True)
    layer = premultiplied(img, tint)
    fx, fy = anchor_fractions(anchor)
    if mask is not None:
        # UI coordinates of the region's top-left corner.
        layer = layer * mask(layer.shape, x - fx * w, y + fy * h)
    ix, iy = canvas.to_image_xy(x, y)
    canvas.composite(layer, ix - fx * layer.shape[1], iy - fy * layer.shape[0])


def solid(canvas, x, y, w, h, color, anchor="CENTER", mask=None):
    draw_image(canvas, Image.new("RGBA", (1, 1), (255, 255, 255, 255)), x, y, w, h, color, anchor=anchor, mask=mask)


def disc_mask(diameter):
    """A mask over the canvas: 1 inside a centred circle of `diameter` UI px."""
    def mask(shape, left, top):
        lh, lw = shape[:2]
        # Layer pixel centres in UI coordinates relative to the canvas centre.
        xs = left + (np.arange(lw) + 0.5) / R
        ys = top - (np.arange(lh) + 0.5) / R
        dist = np.sqrt(xs[None, :] ** 2 + ys[:, None] ** 2)
        return np.clip((diameter / 2 - dist) * R + 0.5, 0, 1)[..., None]
    return mask


def classic_region(name, x0=0, x1=None):
    x, y, w, h = CLASSIC_REGIONS[name]
    return CLASSIC_SHEET.crop((x + x0, y, x + (w if x1 is None else x1), y + h))


def segment_ring(under, fill, count, radius, seg_w, seg_h):
    """Mirror of CircularBarStyle:RepositionSegments: start at 6 o'clock, clockwise."""
    filled = math.floor(count * FILL_RATIO + 0.5)
    for i in range(1, count + 1):
        angle = math.pi / 2 + (i - 1) / count * 2 * math.pi
        x, y = math.cos(angle) * radius, -math.sin(angle) * radius
        rotation = -angle + math.pi / 2
        if i <= filled:
            draw_image(fill, XP_BAR, x, y, seg_w, seg_h, rotation=rotation)
        else:
            draw_image(under, XP_BAR, x, y, seg_w, seg_h, EMPTY_SEGMENT_COLOR, rotation=rotation)


def draw_text(cell, text_runs, size, y):
    """Monochrome text, as the Terminal style's MONOCHROME font flag draws it.
    Drawn straight onto a downsampled cell (sheet pixels), centred at UI y."""
    font = ImageFont.truetype(TERMINAL_FONT, size * OUT_SCALE)
    img = Image.fromarray(cell)
    draw = ImageDraw.Draw(img)
    draw.fontmode = "1"
    full = "".join(text for text, _ in text_runs)
    width = draw.textlength(full, font=font)
    ascent, descent = font.getmetrics()
    x = CELL_W / 2 - width / 2
    top = (CANVAS_H / 2 - y) * OUT_SCALE - (ascent + descent) / 2
    for text, color in text_runs:
        draw.text((x, top), text, font=font, fill=color)
        x += draw.textlength(text, font=font)
    return np.array(img)


# ---------------------------------------------------------------------------
# Styles. Each returns {"under": Canvas, "fill": Canvas, "over": Canvas} with
# only the layers it uses, plus optional post-processing on the final cells.
# ---------------------------------------------------------------------------

def preview_none():
    under = Canvas()
    width, height = 88, 16
    solid(under, 0, height / 2, width, 1, OUTLINE_COLOR, anchor="TOP")
    solid(under, 0, -height / 2, width, 1, OUTLINE_COLOR, anchor="BOTTOM")
    solid(under, -width / 2, 0, 1, height, OUTLINE_COLOR, anchor="LEFT")
    solid(under, width / 2, 0, 1, height, OUTLINE_COLOR, anchor="RIGHT")
    solid(under, 0, 0, 8, 1, DISABLED_TEXT)  # the em dash GameFontDisable draws
    return {"under": under}


def preview_classic():
    # ClassicChrome geometry at the real bar height, on a shortened bar.
    width, height = 100, 17
    scale = height / CLASSIC_REGIONS["frame"][3]
    cap, inset_x, inset_y = 16 * scale, 7 * scale, 6 * scale
    fill_w, fill_h = width - 2 * inset_x, height - 2 * inset_y
    left = -width / 2

    under, fill, over = Canvas(), Canvas(), Canvas()
    draw_image(under, classic_region("background"), left + inset_x, 0, fill_w, fill_h, anchor="LEFT")
    draw_image(fill, CLASSIC_FILL, left + inset_x, 0, fill_w * FILL_RATIO, fill_h, anchor="LEFT")

    # Fewer than the default 10: on a bar a sixth of the real width, ten
    # segments turn the preview into a row of dividers.
    segments = 4
    for i in range(1, segments):
        x = left + inset_x + fill_w * i / segments
        draw_image(over, classic_region("divider"), x, 0, 10 * scale, 16 * scale)
    frame_w = CLASSIC_REGIONS["frame"][2]
    draw_image(over, classic_region("frame", 0, 16), left, 0, cap, height, anchor="LEFT")
    draw_image(over, classic_region("frame", 16, frame_w - 16), left + cap, 0, width - 2 * cap, height, anchor="LEFT")
    draw_image(over, classic_region("frame", frame_w - 16, frame_w), -left, 0, cap, height, anchor="RIGHT")
    return {"under": under, "fill": fill, "over": over}


def preview_flat():
    under, fill = Canvas(), Canvas()
    width, height = 88, 12
    solid(under, 0, 0, width, height, TRACK_COLOR)
    solid(fill, -width / 2, 0, width * FILL_RATIO, height, WHITE, anchor="LEFT")
    return {"under": under, "fill": fill}


def preview_vertical():
    under, fill = Canvas(), Canvas()
    width, height = 14, 42
    solid(under, 0, 0, width, height, TRACK_COLOR)
    solid(fill, 0, -height / 2, width, height * FILL_RATIO, WHITE, anchor="BOTTOM")
    return {"under": under, "fill": fill}


def preview_circular():
    under, fill, over = Canvas(), Canvas(), Canvas()
    draw_image(under, RING_CENTER, 0, 0, 20, 20)
    segment_ring(under, fill, 16, 17, 4, 7)
    draw_image(over, RING_BORDER, 0, 0, 46, 46)
    return {"under": under, "fill": fill, "over": over}


def preview_minimap_ring():
    under, fill = Canvas(), Canvas()
    # The minimap itself: Blizzard's minimap background is a flat near-black
    # disc, drawn here directly so the preview needs no client art.
    solid(under, 0, 0, 30, 30, (0.02, 0.02, 0.02, 1.0), mask=disc_mask(30))
    segment_ring(under, fill, 18, 19, 4, 5)
    return {"under": under, "fill": fill}


def preview_terminal():
    under = Canvas()
    solid(under, 0, 0, 104, 34, (0.02, 0.02, 0.02, 0.95))

    cells = 13
    filled = math.floor(cells * FILL_RATIO + 0.5)
    blocks = "█" * filled + "░" * (cells - filled)

    def post(cell):
        cell = draw_text(cell, [("[", (0, 166, 0, 255)), (blocks, (0, 255, 0, 255)), ("]", (0, 166, 0, 255))], 10, 5)
        return draw_text(cell, [("65.0%  Lv.23", (0, 122, 0, 255))], 9, -7)

    return {"under": under, "post": {"under": post}}


def preview_orb():
    under, fill, over = Canvas(), Canvas(), Canvas()
    size = 38
    mask = disc_mask(size)
    solid(under, 0, 0, size, size, (0.08, 0.08, 0.10, 0.9), mask=mask)
    solid(fill, 0, -size / 2, size, size * FILL_RATIO, WHITE, anchor="BOTTOM", mask=mask)
    draw_image(over, ORB_GLASS, 0, 0, size, size)
    draw_image(over, ORB_RING, 0, 0, size + 6, size + 6)
    return {"under": under, "fill": fill, "over": over}


# Same order as the barStyle options, which is the gallery order.
STYLES = [
    ("none", preview_none),
    ("classic", preview_classic),
    ("flat", preview_flat),
    ("vertical", preview_vertical),
    ("circular", preview_circular),
    ("minimap_ring", preview_minimap_ring),
    ("terminal", preview_terminal),
    ("orb", preview_orb),
]
LAYERS = ("under", "fill", "over")


def main():
    sheet = np.zeros((SHEET_H, SHEET_W, 4), dtype=np.uint8)
    cells = {}
    index = 0
    for style, build in STYLES:
        layers = build()
        post = layers.get("post", {})
        cells[style] = {}
        for layer in LAYERS:
            if layer not in layers:
                continue
            cell = layers[layer].downsample()
            if layer in post:
                cell = post[layer](cell)
            col, row = index % COLUMNS, index // COLUMNS
            assert row < SHEET_H // CELL_H, "sheet is full"
            sheet[row * CELL_H:(row + 1) * CELL_H, col * CELL_W:(col + 1) * CELL_W] = cell
            cells[style][layer] = index
            index += 1

    write_tga(os.path.join(ASSETS, "style-previews.tga"), sheet)

    print("PREVIEW_CELLS (index = row * %d + column, %dx%d cells):" % (COLUMNS, CELL_W, CELL_H))
    for style, layers in cells.items():
        body = ", ".join(f"{name} = {i}" for name, i in layers.items())
        print(f"    {style} = {{{body}}},")


if __name__ == "__main__":
    main()
