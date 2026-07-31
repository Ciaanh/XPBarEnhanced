#!/usr/bin/env python3
"""Generate every Sigil style texture.

    python assets/raw/generate_sigil.py            # writes into assets/
    python assets/raw/generate_sigil.py --preview  # also writes a PNG contact sheet

Produces 30 files, all greyscale-with-alpha and tinted at runtime by
ui/styles/sigil/SigilBarStyle.lua:

    sigil-casing-{1..4}.tga     256x256   the ring itself, one per tier
    sigil-runes-<class>.tga     512x512   2x2 atlas, one 256x256 quarter per tier
    sigil-crest-<class>.tga      64x64    the class mark at 6 o'clock

WHY THIS IS A SCRIPT AND NOT A .PDN
    The art is parametric: four tiers are the same ring with escalating
    ornament, and thirteen classes are six motif families with per-class marks.
    Expressing that as code means a change to the bevel or the tier pacing is
    one edit and one command, not thirty files reopened by hand. It is also the
    licensing answer -- everything here is drawn from primitives, so nothing is
    derived from Blizzard or ArtStation reference art.

FORMAT
    32-bit RLE TGA, power-of-two, greyscale in RGB and the real shape in alpha.
    That is byte-for-byte the same header shape as the already-shipped
    border.tga / glow.tga / center.tga, which the client loads today.

    Everything is drawn at SS x resolution and downsampled with LANCZOS. That
    is what buys clean circular edges without a vector renderer, and it matters
    most on the crests, which are only 64px.

    RGB carries luminance only. Never bake colour in: PaintFrame/PaintBand/
    PaintCrest call SetVertexColor with the class accent, which multiplies.

CONVENTIONS THE ADDON DEPENDS ON
    File names are lower-cased class tokens -- SigilSkins:GetBandTexture and
    GetCrestTexture format "sigil-runes-%s" / "sigil-crest-%s" with
    string.lower(classToken), so DEATHKNIGHT -> sigil-crest-deathknight.tga.

    The rune atlas is a 2x2 GRID (quarters 1,2 top row; 3,4 bottom row) to match
    SigilSkins:GetBandTexCoord. Not four stacked strips: SkinBand is drawn into
    the square ring region, so a non-square source rect squashes every glyph.
"""

from __future__ import annotations

import argparse
import math
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageChops
except ImportError:
    sys.exit("Pillow is required:  pip install Pillow")


# --------------------------------------------------------------------------
# OUTPUT GEOMETRY
# --------------------------------------------------------------------------

CASING_SIZE = 256
RUNE_QUARTER = 256          # one tier; the file is 2x2 of these
RUNE_SHEET = RUNE_QUARTER * 2
CREST_SIZE = 64

SS = 4                      # supersample factor for casings and runes
CREST_SS = 8                # crests are tiny, so they need more

CLASSES = [
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
    "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER",
]

# Mirrors SigilSkins.FAMILY_BY_CLASS. Families are the motif vocabulary: they
# exist so thirteen marks read as one designed set rather than thirteen
# unrelated doodles.
FAMILY_BY_CLASS = {
    "MAGE": "arcane", "WARLOCK": "arcane",
    "PRIEST": "sacred", "PALADIN": "sacred",
    "DRUID": "wild", "SHAMAN": "wild", "HUNTER": "wild",
    "WARRIOR": "martial", "DEATHKNIGHT": "martial", "MONK": "martial",
    "ROGUE": "umbral", "DEMONHUNTER": "umbral",
    "EVOKER": "draconic",
}


# --------------------------------------------------------------------------
# CANVAS
# --------------------------------------------------------------------------

class Canvas:
    """Paired luminance and alpha layers drawn at supersampled resolution.

    Two layers rather than one RGBA because the two are genuinely independent
    here: alpha is the silhouette the mask cuts, luminance is the metal shading
    that the runtime tint multiplies. Drawing them together would force a
    premultiplied compromise on every stroke.
    """

    def __init__(self, size: int, ss: int):
        self.size = size
        self.ss = ss
        self.w = size * ss
        self.lum = Image.new("L", (self.w, self.w), 0)
        self.alpha = Image.new("L", (self.w, self.w), 0)
        self.dl = ImageDraw.Draw(self.lum)
        self.da = ImageDraw.Draw(self.alpha)

    # -- primitives ------------------------------------------------------
    # Each takes UNIT coordinates (0..1 across the canvas) so the same call
    # produces the same picture at any output size.

    def _px(self, v: float) -> float:
        return v * self.w

    def disc(self, cx, cy, r, lum=None, alpha=None):
        box = [self._px(cx - r), self._px(cy - r), self._px(cx + r), self._px(cy + r)]
        if alpha is not None:
            self.da.ellipse(box, fill=alpha)
        if lum is not None:
            self.dl.ellipse(box, fill=lum)

    def ring(self, cx, cy, outer, inner, lum=None, alpha=None):
        """A true annulus, touching nothing inside `inner`.

        Deliberately NOT "filled disc, then punch a hole": that erases whatever
        is already inside the inner radius, so concentric detail drawn in
        sequence -- a body, then a bevel lip on each edge -- destroys itself and
        only the outermost band survives.
        """
        box = [self._px(cx - outer), self._px(cy - outer),
               self._px(cx + outer), self._px(cy + outer)]
        w = max(1, int(round(self._px(outer - inner))))
        if alpha is not None:
            self.da.ellipse(box, outline=alpha, width=w)
        if lum is not None:
            self.dl.ellipse(box, outline=lum, width=w)

    def arc(self, cx, cy, r, start_deg, end_deg, width, lum=None, alpha=None):
        box = [self._px(cx - r), self._px(cy - r), self._px(cx + r), self._px(cy + r)]
        w = max(1, int(self._px(width)))
        if alpha is not None:
            self.da.arc(box, start_deg, end_deg, fill=alpha, width=w)
        if lum is not None:
            self.dl.arc(box, start_deg, end_deg, fill=lum, width=w)

    def line(self, x0, y0, x1, y1, width, lum=None, alpha=None):
        pts = [self._px(x0), self._px(y0), self._px(x1), self._px(y1)]
        w = max(1, int(self._px(width)))
        if alpha is not None:
            self.da.line(pts, fill=alpha, width=w)
        if lum is not None:
            self.dl.line(pts, fill=lum, width=w)

    def poly(self, points, lum=None, alpha=None):
        pts = [(self._px(x), self._px(y)) for x, y in points]
        if alpha is not None:
            self.da.polygon(pts, fill=alpha)
        if lum is not None:
            self.dl.polygon(pts, fill=lum)

    # -- shading ---------------------------------------------------------

    def apply_light(self, strength=0.45, angle_deg=125.0):
        """Multiply a directional gradient over the luminance layer.

        One consistent light direction across all 30 files is most of what
        makes them read as one set; without it each mark invents its own and
        the ring looks assembled from spare parts.
        """
        grad = Image.new("L", (self.w, self.w))
        px = grad.load()
        rad = math.radians(angle_deg)
        dx, dy = math.cos(rad), math.sin(rad)
        for y in range(self.w):
            ny = y / self.w - 0.5
            row = ny * dy
            for x in range(self.w):
                nx = x / self.w - 0.5
                t = (nx * dx + row) + 0.5
                px[x, y] = max(0, min(255, int(255 * (1.0 - strength + strength * t))))
        self.lum = ImageChops.multiply(self.lum, grad)
        self.dl = ImageDraw.Draw(self.lum)

    def resolve(self, alpha_blur=0.5) -> Image.Image:
        lum = self.lum.resize((self.size, self.size), Image.LANCZOS)
        alpha = self.alpha.resize((self.size, self.size), Image.LANCZOS)
        if alpha_blur:
            alpha = alpha.filter(ImageFilter.GaussianBlur(alpha_blur))
        # Luminance only shows where there is shape; stray shading outside the
        # silhouette would light up when the tint multiplies it.
        lum = ImageChops.multiply(lum, alpha.point(lambda v: 255 if v > 8 else v * 31))
        return Image.merge("RGBA", (lum, lum, lum, alpha))


def save_tga(img: Image.Image, path: str) -> None:
    img.save(path, format="TGA", compression="tga_rle")


# --------------------------------------------------------------------------
# CASINGS -- the ring, one per tier
# --------------------------------------------------------------------------

# Tier pacing. The escalation has to read at a glance and in silhouette, so it
# is carried by three stacking cues -- thickness, stud count, outer crown --
# rather than by one that just gets bigger.
CASING_TIERS = {
    1: dict(thickness=0.085, studs=0,  crown=0,  fillets=False, inner_line=False),
    2: dict(thickness=0.100, studs=8,  crown=0,  fillets=True,  inner_line=False),
    3: dict(thickness=0.115, studs=16, crown=0,  fillets=True,  inner_line=True),
    4: dict(thickness=0.130, studs=24, crown=12, fillets=True,  inner_line=True),
}


def build_casing(tier: int) -> Image.Image:
    cfg = CASING_TIERS[tier]
    c = Canvas(CASING_SIZE, SS)

    # Leaves room for tier 4's crown spokes, which reach outer + 0.040.
    outer = 0.435
    thickness = cfg["thickness"]
    inner = outer - thickness
    mid = (outer + inner) / 2

    # Crown spokes first so the band covers their inner ends.
    if cfg["crown"]:
        n = cfg["crown"]
        for i in range(n):
            a = (i / n) * 2 * math.pi - math.pi / 2
            x0, y0 = 0.5 + math.cos(a) * (outer - 0.005), 0.5 + math.sin(a) * (outer - 0.005)
            x1, y1 = 0.5 + math.cos(a) * (outer + 0.032), 0.5 + math.sin(a) * (outer + 0.032)
            c.line(x0, y0, x1, y1, 0.013, lum=205, alpha=255)
            tipr = 0.010
            c.disc(0.5 + math.cos(a) * (outer + 0.032), 0.5 + math.sin(a) * (outer + 0.032),
                   tipr, lum=225, alpha=255)

    # Main band
    c.ring(0.5, 0.5, outer, inner, lum=178, alpha=255)

    # Bevel. A bright lip outside and a dark lip inside is the cheapest thing
    # that reads as a rounded metal section rather than a flat annulus. Both
    # are kept narrow so the mid-tone body still dominates -- widen them and
    # the ring goes back to reading as a pair of hairlines.
    c.ring(0.5, 0.5, outer, outer - thickness * 0.16, lum=242, alpha=255)
    c.ring(0.5, 0.5, inner + thickness * 0.14, inner, lum=88, alpha=255)

    # A hairline channel down the middle catches the eye as a machined groove.
    if cfg["inner_line"]:
        c.ring(0.5, 0.5, mid + 0.004, mid - 0.004, lum=96, alpha=255)

    # Studs set into the band
    if cfg["studs"]:
        n = cfg["studs"]
        for i in range(n):
            a = (i / n) * 2 * math.pi - math.pi / 2
            x, y = 0.5 + math.cos(a) * mid, 0.5 + math.sin(a) * mid
            c.disc(x, y, thickness * 0.30, lum=70, alpha=255)      # seat
            c.disc(x, y, thickness * 0.22, lum=240, alpha=255)     # head
            c.disc(x - thickness * 0.05, y - thickness * 0.05,
                   thickness * 0.10, lum=255, alpha=255)           # highlight

    # Cardinal fillets: four larger mounts at the compass points give the ring
    # an orientation, so tier 2+ does not read as rotationally anonymous.
    if cfg["fillets"]:
        for k in range(4):
            a = k * (math.pi / 2) - math.pi / 2
            x, y = 0.5 + math.cos(a) * mid, 0.5 + math.sin(a) * mid
            c.disc(x, y, thickness * 0.55, lum=120, alpha=255)
            c.disc(x, y, thickness * 0.42, lum=200, alpha=255)
            c.disc(x, y, thickness * 0.20, lum=90, alpha=255)

    c.apply_light(strength=0.40)
    return c.resolve(alpha_blur=0.6)


# --------------------------------------------------------------------------
# RUNE BANDS -- a ring of family glyphs, one quarter of the atlas per tier
# --------------------------------------------------------------------------

# How many glyphs are lit at each tier. Tier 1 is deliberately sparse: the band
# should feel like it is filling in as the character grows.
RUNE_COUNTS = {1: 4, 2: 8, 3: 12, 4: 16}


def _glyph(c: Canvas, family: str, x: float, y: float, r: float, angle: float):
    """One family glyph, centred at (x, y) and rotated to face outward."""
    def rot(px, py):
        ca, sa = math.cos(angle), math.sin(angle)
        return x + px * ca - py * sa, y + px * sa + py * ca

    if family == "arcane":
        # Four-point star
        pts = [rot(0, -r), rot(r * 0.30, 0), rot(0, r), rot(-r * 0.30, 0)]
        c.poly(pts, lum=235, alpha=255)
        pts = [rot(-r, 0), rot(0, -r * 0.30), rot(r, 0), rot(0, r * 0.30)]
        c.poly(pts, lum=235, alpha=255)
    elif family == "sacred":
        # Upright cross with a widened head
        c.poly([rot(-r * 0.22, -r), rot(r * 0.22, -r), rot(r * 0.22, r), rot(-r * 0.22, r)],
               lum=235, alpha=255)
        c.poly([rot(-r * 0.75, -r * 0.25), rot(r * 0.75, -r * 0.25),
                rot(r * 0.75, r * 0.15), rot(-r * 0.75, r * 0.15)], lum=235, alpha=255)
    elif family == "wild":
        # Leaf: two mirrored arcs closed at the tips
        c.poly([rot(0, -r), rot(r * 0.62, 0), rot(0, r), rot(-r * 0.62, 0)],
               lum=225, alpha=255)
        c.line(*rot(0, -r), *rot(0, r), 0.006, lum=90, alpha=255)
    elif family == "martial":
        # Chevron
        c.poly([rot(0, -r), rot(r * 0.70, r * 0.35), rot(r * 0.34, r * 0.35),
                rot(0, -r * 0.30), rot(-r * 0.34, r * 0.35), rot(-r * 0.70, r * 0.35)],
               lum=235, alpha=255)
    elif family == "umbral":
        # Crescent: a disc with a disc bitten out of it
        c.disc(x, y, r * 0.85, lum=225, alpha=255)
        ox, oy = rot(r * 0.45, -r * 0.20)
        c.disc(ox, oy, r * 0.70, lum=0, alpha=0)
    elif family == "draconic":
        # Scale
        c.poly([rot(0, -r), rot(r * 0.72, r * 0.10), rot(0, r), rot(-r * 0.72, r * 0.10)],
               lum=230, alpha=255)
        c.poly([rot(0, -r * 0.35), rot(r * 0.34, r * 0.18), rot(0, r * 0.52),
                rot(-r * 0.34, r * 0.18)], lum=120, alpha=255)


# Per-class variation WITHIN a family. Without this the thirteen strips would be
# six unique images copied out under thirteen names -- ~700 KB of pure
# duplication, and a Warlock band indistinguishable from a Mage one. The family
# still owns the glyph vocabulary; a class varies the rhythm it is laid out in.
#
#   phase   rotates the whole ring, so two classes never line up
#   pips    small studs set between the glyphs
#   alt     every second glyph drawn smaller, giving a two-beat rhythm
CLASS_VARIANT = {
    "MAGE":        dict(phase=0.00, pips=False, alt=False),
    "WARLOCK":     dict(phase=0.50, pips=True,  alt=True),
    "PRIEST":      dict(phase=0.00, pips=False, alt=False),
    "PALADIN":     dict(phase=0.50, pips=True,  alt=False),
    "DRUID":       dict(phase=0.00, pips=False, alt=False),
    "SHAMAN":      dict(phase=0.33, pips=True,  alt=False),
    "HUNTER":      dict(phase=0.66, pips=False, alt=True),
    "WARRIOR":     dict(phase=0.00, pips=False, alt=False),
    "DEATHKNIGHT": dict(phase=0.50, pips=True,  alt=True),
    "MONK":        dict(phase=0.25, pips=False, alt=True),
    "ROGUE":       dict(phase=0.00, pips=False, alt=True),
    "DEMONHUNTER": dict(phase=0.50, pips=True,  alt=False),
    "EVOKER":      dict(phase=0.00, pips=True,  alt=False),
}


def build_rune_quarter(class_token: str, tier: int) -> Image.Image:
    family = FAMILY_BY_CLASS[class_token]
    var = CLASS_VARIANT[class_token]

    c = Canvas(RUNE_QUARTER, SS)
    count = RUNE_COUNTS[tier]
    radius = 0.375
    glyph_r = 0.045 if count <= 8 else 0.036
    step = 2 * math.pi / count
    phase = var["phase"] * step

    # Guide track: a hairline the glyphs sit on, so a sparse tier still reads as
    # a band rather than as scattered marks.
    c.ring(0.5, 0.5, radius + 0.0035, radius - 0.0035, lum=70, alpha=170)

    for i in range(count):
        a = i * step - math.pi / 2 + phase
        gx, gy = 0.5 + math.cos(a) * radius, 0.5 + math.sin(a) * radius
        r = glyph_r * (0.62 if (var["alt"] and i % 2) else 1.0)
        _glyph(c, family, gx, gy, r, a + math.pi / 2)

    if var["pips"]:
        for i in range(count):
            a = (i + 0.5) * step - math.pi / 2 + phase
            c.disc(0.5 + math.cos(a) * radius, 0.5 + math.sin(a) * radius,
                   glyph_r * 0.22, lum=200, alpha=255)

    c.apply_light(strength=0.30)
    return c.resolve(alpha_blur=0.45)


def build_rune_sheet(class_token: str) -> Image.Image:
    """2x2 atlas: quarters 1,2 on the top row and 3,4 on the bottom.

    Must match SigilSkins:GetBandTexCoord exactly.
    """
    sheet = Image.new("RGBA", (RUNE_SHEET, RUNE_SHEET), (0, 0, 0, 0))
    for tier in (1, 2, 3, 4):
        zero = tier - 1
        col, row = zero % 2, zero // 2
        sheet.paste(build_rune_quarter(class_token, tier),
                    (col * RUNE_QUARTER, row * RUNE_QUARTER))
    return sheet


# --------------------------------------------------------------------------
# CRESTS -- the class mark at 6 o'clock
# --------------------------------------------------------------------------

# Backing plate per family. The plate is what makes a family legible from
# across the screen; the motif is what tells two classes in it apart.
PLATE_BY_FAMILY = {
    "arcane": "lozenge",
    "sacred": "arch",
    "wild": "roundel",
    "martial": "shield",
    "umbral": "spike",
    "draconic": "scale",
}


def _plate(c: Canvas, kind: str):
    """Draw the family backing plate: bright rim, darker body.

    The rim follows the plate's OWN silhouette. Stamping a circular ring over
    every plate -- the obvious shortcut -- turns shield, lozenge, arch and spike
    all into roundels and throws away the family distinction the plate exists
    to carry. So each plate is described once as a shape function and drawn
    twice, the second time inset toward the centre.
    """
    cx, cy, r = 0.5, 0.52, 0.40

    def scaled(pts, k):
        return [(cx + (x - cx) * k, cy + (y - cy) * k) for x, y in pts]

    outlines = {
        "shield": [(cx - r, cy - r * 0.85), (cx + r, cy - r * 0.85),
                   (cx + r, cy + r * 0.15), (cx, cy + r), (cx - r, cy + r * 0.15)],
        "lozenge": [(cx, cy - r), (cx + r * 0.82, cy), (cx, cy + r), (cx - r * 0.82, cy)],
        "spike": [(cx, cy - r), (cx + r * 0.72, cy - r * 0.25), (cx + r * 0.44, cy + r),
                  (cx - r * 0.44, cy + r), (cx - r * 0.72, cy - r * 0.25)],
        "scale": [(cx, cy - r), (cx + r * 0.85, cy - r * 0.15), (cx, cy + r),
                  (cx - r * 0.85, cy - r * 0.15)],
        # Arch is a half-round over a tapered base, flattened into one outline
        # so it insets like the rest instead of needing its own special case.
        "arch": ([(cx + math.cos(math.pi + i / 12 * math.pi) * r * 0.88,
                   cy - r * 0.06 + math.sin(math.pi + i / 12 * math.pi) * r * 0.88)
                  for i in range(13)]
                 + [(cx + r * 0.70, cy + r * 0.92), (cx - r * 0.70, cy + r * 0.92)]),
    }

    RIM, BODY = 205, 96

    if kind == "roundel":
        c.disc(cx, cy, r * 0.97, lum=RIM, alpha=255)
        c.disc(cx, cy, r * 0.86, lum=BODY, alpha=255)
        return

    pts = outlines[kind]
    c.poly(pts, lum=RIM, alpha=255)
    c.poly(scaled(pts, 0.86), lum=BODY, alpha=255)


def _motif(c: Canvas, class_token: str):
    """An abstract heraldic mark per class.

    These are marks, not portraits. At 64px a recognisable weapon silhouette is
    not achievable and would turn to mud, so each class gets a bold, simple,
    distinguishable device instead -- the same discipline real heraldry uses at
    small sizes.
    """
    cx, cy = 0.5, 0.52
    W = 0.030   # standard stroke

    if class_token == "WARRIOR":                     # crossed blades
        c.line(cx - 0.20, cy + 0.22, cx + 0.20, cy - 0.24, W, lum=245, alpha=255)
        c.line(cx + 0.20, cy + 0.22, cx - 0.20, cy - 0.24, W, lum=245, alpha=255)
        c.line(cx - 0.22, cy - 0.06, cx + 0.22, cy - 0.06, W * 0.7, lum=200, alpha=255)
    elif class_token == "PALADIN":                   # hammer
        c.poly([(cx - 0.22, cy - 0.26), (cx + 0.22, cy - 0.26),
                (cx + 0.22, cy - 0.02), (cx - 0.22, cy - 0.02)], lum=245, alpha=255)
        c.line(cx, cy - 0.02, cx, cy + 0.28, W * 1.1, lum=225, alpha=255)
    elif class_token == "HUNTER":                    # drawn bow with nocked arrow
        c.arc(cx + 0.10, cy, 0.30, 118, 242, W * 0.95, lum=245, alpha=255)
        # Bowstring: straight chord between the limb tips, so the arc reads as
        # a bow rather than as an incomplete circle.
        tipy = 0.30 * math.sin(math.radians(118))
        c.line(cx + 0.10 - 0.30 * 0.47, cy - tipy,
               cx + 0.10 - 0.30 * 0.47, cy + tipy, W * 0.45, lum=200, alpha=255)
        c.line(cx - 0.20, cy, cx + 0.24, cy, W * 0.5, lum=235, alpha=255)
        c.poly([(cx + 0.30, cy), (cx + 0.16, cy - 0.08), (cx + 0.16, cy + 0.08)],
               lum=250, alpha=255)
    elif class_token == "ROGUE":                     # paired daggers
        c.poly([(cx - 0.16, cy - 0.26), (cx - 0.06, cy - 0.26), (cx - 0.11, cy + 0.26)],
               lum=245, alpha=255)
        c.poly([(cx + 0.06, cy - 0.26), (cx + 0.16, cy - 0.26), (cx + 0.11, cy + 0.26)],
               lum=245, alpha=255)
    elif class_token == "PRIEST":                    # radiant point
        c.disc(cx, cy - 0.04, 0.11, lum=250, alpha=255)
        for k in range(8):
            a = k * math.pi / 4
            c.line(cx + math.cos(a) * 0.14, cy - 0.04 + math.sin(a) * 0.14,
                   cx + math.cos(a) * 0.27, cy - 0.04 + math.sin(a) * 0.27,
                   W * 0.55, lum=225, alpha=255)
    elif class_token == "DEATHKNIGHT":               # runeblade
        c.poly([(cx - 0.09, cy - 0.28), (cx + 0.09, cy - 0.28),
                (cx + 0.09, cy + 0.14), (cx, cy + 0.29), (cx - 0.09, cy + 0.14)],
               lum=245, alpha=255)
        c.line(cx - 0.20, cy - 0.10, cx + 0.20, cy - 0.10, W * 0.7, lum=190, alpha=255)
        c.line(cx, cy - 0.22, cx, cy + 0.10, W * 0.5, lum=110, alpha=255)
    elif class_token == "SHAMAN":                    # lightning
        c.poly([(cx + 0.10, cy - 0.30), (cx - 0.16, cy + 0.04), (cx - 0.01, cy + 0.04),
                (cx - 0.10, cy + 0.30), (cx + 0.17, cy - 0.06), (cx + 0.01, cy - 0.06)],
               lum=250, alpha=255)
    elif class_token == "MAGE":                      # eight-point star
        for k in range(4):
            a = k * math.pi / 4
            c.poly([(cx + math.cos(a) * 0.30, cy + math.sin(a) * 0.30),
                    (cx + math.cos(a + math.pi / 2) * 0.07, cy + math.sin(a + math.pi / 2) * 0.07),
                    (cx - math.cos(a) * 0.30, cy - math.sin(a) * 0.30),
                    (cx - math.cos(a + math.pi / 2) * 0.07, cy - math.sin(a + math.pi / 2) * 0.07)],
                   lum=245, alpha=255)
    elif class_token == "WARLOCK":                   # horned circle
        c.ring(cx, cy + 0.02, 0.21, 0.13, lum=245, alpha=255)
        c.poly([(cx - 0.26, cy - 0.30), (cx - 0.12, cy - 0.08), (cx - 0.22, cy - 0.06)],
               lum=235, alpha=255)
        c.poly([(cx + 0.26, cy - 0.30), (cx + 0.12, cy - 0.08), (cx + 0.22, cy - 0.06)],
               lum=235, alpha=255)
    elif class_token == "MONK":                      # chi orb ringed by three motes
        c.ring(cx, cy, 0.16, 0.10, lum=240, alpha=255)
        c.disc(cx, cy, 0.05, lum=250, alpha=255)
        for k in range(3):
            a = -math.pi / 2 + k * (2 * math.pi / 3)
            c.disc(cx + math.cos(a) * 0.27, cy + math.sin(a) * 0.27, 0.062,
                   lum=235, alpha=255)
    elif class_token == "DRUID":                     # claw
        for k, off in enumerate((-0.17, 0.0, 0.17)):
            c.poly([(cx + off - 0.05, cy + 0.26), (cx + off + 0.05, cy + 0.26),
                    (cx + off + 0.02, cy - 0.26 + abs(off) * 0.5),
                    (cx + off - 0.02, cy - 0.26 + abs(off) * 0.5)],
                   lum=245 - k * 8, alpha=255)
    elif class_token == "DEMONHUNTER":               # swept horns over a blindfold
        # Solid tapered horns, not arcs: at 64px a stroked arc closes up into a
        # blob and the pair reads as a single lump.
        c.poly([(cx - 0.07, cy - 0.04), (cx - 0.17, cy - 0.30), (cx - 0.28, cy - 0.12),
                (cx - 0.18, cy - 0.02)], lum=245, alpha=255)
        c.poly([(cx + 0.07, cy - 0.04), (cx + 0.17, cy - 0.30), (cx + 0.28, cy - 0.12),
                (cx + 0.18, cy - 0.02)], lum=245, alpha=255)
        c.line(cx - 0.26, cy + 0.12, cx + 0.26, cy + 0.12, W * 1.0, lum=215, alpha=255)
    elif class_token == "EVOKER":                    # wing
        c.poly([(cx - 0.26, cy + 0.22), (cx - 0.02, cy - 0.28), (cx + 0.06, cy - 0.02),
                (cx + 0.24, cy - 0.16), (cx + 0.12, cy + 0.24)], lum=245, alpha=255)
        c.line(cx - 0.10, cy + 0.02, cx + 0.10, cy + 0.06, W * 0.5, lum=120, alpha=255)


def build_crest(class_token: str) -> Image.Image:
    c = Canvas(CREST_SIZE, CREST_SS)
    _plate(c, PLATE_BY_FAMILY[FAMILY_BY_CLASS[class_token]])
    _motif(c, class_token)
    c.apply_light(strength=0.32)
    return c.resolve(alpha_blur=0.35)


# --------------------------------------------------------------------------
# DRIVER
# --------------------------------------------------------------------------

def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    default_out = os.path.normpath(os.path.join(here, ".."))

    ap = argparse.ArgumentParser(description="Generate Sigil style textures.")
    ap.add_argument("--out", default=default_out,
                    help="output directory (default: the assets/ root)")
    ap.add_argument("--preview", action="store_true",
                    help="also write sigil-preview.png contact sheets into assets/raw/")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    written = 0

    print("casings")
    casings = {}
    for tier in (1, 2, 3, 4):
        img = build_casing(tier)
        casings[tier] = img
        save_tga(img, os.path.join(args.out, f"sigil-casing-{tier}.tga"))
        written += 1
        print(f"  tier {tier}")

    print("rune bands")
    sheets = {}
    for class_token in CLASSES:
        sheet = build_rune_sheet(class_token)
        sheets[class_token] = sheet
        save_tga(sheet, os.path.join(args.out, f"sigil-runes-{class_token.lower()}.tga"))
        written += 1
        print(f"  {class_token.lower()}")

    print("crests")
    crests = {}
    for class_token in CLASSES:
        img = build_crest(class_token)
        crests[class_token] = img
        save_tga(img, os.path.join(args.out, f"sigil-crest-{class_token.lower()}.tga"))
        written += 1
        print(f"  {class_token.lower()}")

    print(f"\n{written} TGA files written to {args.out}")

    if args.preview:
        _write_previews(here, casings, sheets, crests)

    return 0


def _write_previews(raw_dir, casings, sheets, crests):
    """Contact sheets on a dark slate, tinted like a class colour would tint
    them, so the output can be judged the way it will actually be seen."""
    def tinted(img, rgb):
        r, g, b, a = img.split()
        return Image.merge("RGBA", (
            r.point(lambda v: int(v * rgb[0])),
            g.point(lambda v: int(v * rgb[1])),
            b.point(lambda v: int(v * rgb[2])), a))

    gold = (1.0, 0.82, 0.42)

    sheet = Image.new("RGBA", (4 * 256, 256), (24, 24, 30, 255))
    for i, tier in enumerate((1, 2, 3, 4)):
        sheet.alpha_composite(tinted(casings[tier], gold), (i * 256, 0))
    sheet.convert("RGB").save(os.path.join(raw_dir, "sigil-preview-casings.png"))

    # One tier-4 quarter per class, so per-class variation inside a family is
    # visible side by side rather than having to be taken on trust.
    cols = 7
    rows = (len(CLASSES) + cols - 1) // cols
    band = Image.new("RGBA", (cols * 224, rows * 224), (24, 24, 30, 255))
    for i, ct in enumerate(CLASSES):
        q = sheets[ct].crop((RUNE_QUARTER, RUNE_QUARTER, RUNE_SHEET, RUNE_SHEET))
        q = tinted(q, gold).resize((224, 224), Image.LANCZOS)
        band.alpha_composite(q, ((i % cols) * 224, (i // cols) * 224))
    band.convert("RGB").save(os.path.join(raw_dir, "sigil-preview-runes.png"))

    cols, cell = 7, 96
    rows = (len(CLASSES) + cols - 1) // cols
    grid = Image.new("RGBA", (cols * cell, rows * cell), (24, 24, 30, 255))
    for i, ct in enumerate(CLASSES):
        big = tinted(crests[ct], gold).resize((cell - 8, cell - 8), Image.LANCZOS)
        grid.alpha_composite(big, ((i % cols) * cell + 4, (i // cols) * cell + 4))
    grid.convert("RGB").save(os.path.join(raw_dir, "sigil-preview-crests.png"))
    print("previews written to assets/raw/")


if __name__ == "__main__":
    raise SystemExit(main())
