#!/usr/bin/env python3
"""Generate every Sigil style texture.

    python assets/raw/generate_sigil.py            # writes into assets/
    python assets/raw/generate_sigil.py --preview  # also writes a PNG contact sheet

Produces 43 files, all greyscale-with-alpha and tinted at runtime by
ui/styles/sigil/SigilBarStyle.lua:

    sigil-casing-{1..4}.tga            256x256  neutral frame (fallback for
                                                unknown class tokens + gallery)
    sigil-casing-<family>-{1..4}.tga   256x256  themed frame, six families:
                                                arcane / sacred / wild /
                                                martial / umbral / draconic
    sigil-crest-<class>.tga             64x64   the class mark at 6 o'clock,
                                                a round medallion (the official
                                                crests' format) with the class's
                                                iconic motif drawn from
                                                primitives
    sigil-fill.tga              256x256   the XP arc annulus, revealed by a
                                          Cooldown swipe (Amendment A: the fill
                                          is an arc, not a liquid)
    sigil-track.tga             256x256   the recessed groove the arc runs in,
                                          so an empty channel is still legible

The per-class rune bands were removed 2026-08-16: two concentric rings of
repeated marks read as noise, not ornament, and the tier signal belongs to the
casing alone -- the reference (League level borders) carries escalation with
pointed metalwork and layered rims, never with dots. The XP channel moved
outward in the same pass, to sit directly against the casing's inner edge,
because a progress arc at centre-adjacent radii read as text decoration rather
than as THE bar.

Later the same day the casings became PER-FAMILY THEMED (the reference sets are
themed borders, not recolours): each of the six class families gets its own
ornament vocabulary -- fitting shape, finial shape, filigree style -- on the
shared two-rim skeleton, so a Mage's frame and a Warrior's frame differ in
metalwork, not just tint. The crests moved to a uniform round-medallion format
in the same pass, which is the official class crests' construction; each
carries the class's ICONIC MOTIF (crossed swords, warhammer, drawn bow, ...)
drawn fresh from primitives. Concepts and motifs, never Blizzard's artwork:
nothing is traced, copied, or derived from shipped art.

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
    File names are lower-cased class tokens -- SigilSkins:GetCrestTexture
    formats "sigil-crest-%s" with string.lower(classToken), so
    DEATHKNIGHT -> sigil-crest-deathknight.tga.

    The fill/track annuli (FILL_OUTER / FILL_INNER below) must stay just inside
    the casing's inner edge across all four tiers -- the channel hugging the
    frame is the League read the whole style is modelled on.
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
CREST_SIZE = 64

SS = 4                      # supersample factor for casings and the channel
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

        One consistent light direction across every file is most of what
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
# CASINGS -- the frame, one per tier
# --------------------------------------------------------------------------

# Tier pacing, reworked 2026-08-16 toward the League level-border vocabulary:
# layered thin rims, pointed diamond fittings, outer points and crown finials.
# No studs and no dots -- repeated circles read as rivets, and rivets read as
# machinery, not regalia.
#
# The casing is a TWO-RIM assembly: an outer ornamental band and a fixed inner
# border ring, with the XP arc channel running in the gap between them -- the
# reference's construction. The band's INNER edge is fixed (BAND_INNER) and
# tier escalation grows OUTWARD, so the channel-to-frame relationship is
# identical at every tier and one fill/track annulus serves all four casings.
BAND_INNER = 0.345          # fixed inner edge of the outer band, all tiers
INNER_RIM_OUTER = 0.264     # the inner border ring enclosing the channel
INNER_RIM_INNER = 0.230     # grew 0.240 -> 0.230 (2026-08-16): 3px read too
                            # thin beside the band; the rim grows INWARD so the
                            # channel geometry never moves

CASING_TIERS = {
    1: dict(band=0.050, diamonds=0, points=0, finials=0,  filigree=False),
    2: dict(band=0.058, diamonds=4, points=4, finials=0,  filigree=False),
    3: dict(band=0.066, diamonds=4, points=8, finials=8,  filigree=True),
    4: dict(band=0.074, diamonds=8, points=8, finials=16, filigree=True),
}


def _radial_diamond(c: Canvas, angle: float, r: float, half_len: float, half_wid: float,
                    lum: int, alpha: int = 255):
    """A four-point diamond at radius r, its long axis pointing outward --
    the pointed fitting the reference borders seat at their compass points."""
    ca, sa = math.cos(angle), math.sin(angle)
    cx, cy = 0.5 + ca * r, 0.5 + sa * r
    # Local axes: u = radial (outward), v = tangential.
    pts = [(half_len, 0.0), (0.0, half_wid), (-half_len, 0.0), (0.0, -half_wid)]
    c.poly([(cx + u * ca - v * sa, cy + u * sa + v * ca) for u, v in pts], lum=lum, alpha=alpha)


def _spike(c: Canvas, angle: float, base_r: float, length: float, half_wid: float,
           lum: int, alpha: int = 255):
    """A thin triangle pointing outward from base_r -- a crown finial."""
    ca, sa = math.cos(angle), math.sin(angle)
    tip = (0.5 + ca * (base_r + length), 0.5 + sa * (base_r + length))
    left = (0.5 + math.cos(angle + math.pi / 2) * half_wid + ca * base_r,
            0.5 + math.sin(angle + math.pi / 2) * half_wid + sa * base_r)
    right = (0.5 + math.cos(angle - math.pi / 2) * half_wid + ca * base_r,
             0.5 + math.sin(angle - math.pi / 2) * half_wid + sa * base_r)
    c.poly([tip, left, right], lum=lum, alpha=alpha)


# Per-family ornament vocabulary (2026-08-16): fitting = the mount at the
# compass points, finial = the crown spike shape, filigree = the detached
# outer-arc style. Same two-rim skeleton, same tier pacing, different metalwork.
FAMILY_STYLE = {
    "arcane":   dict(fit="crescent", fin="spire",  fil="orbit"),
    "sacred":   dict(fit="cross",    fin="ray",    fil="halo"),
    "wild":     dict(fit="leaf",     fin="antler", fil="vine"),
    "martial":  dict(fit="plate",    fin="blade",  fil="chevron"),
    "umbral":   dict(fit="barb",     fin="hook",   fil="thin"),
    "draconic": dict(fit="scale",    fin="horn",   fil="wing"),
}


def _tapered_spike(c: Canvas, angle: float, base_r: float, length: float,
                   half_wid: float, sweep: float = 0.0, lum: int = 210):
    """A tapered triangle from base_r outward; `sweep` (radians) displaces the
    tip tangentially, which is what turns a spike into a hook or a horn."""
    tip_a = angle + sweep
    tip = (0.5 + math.cos(tip_a) * (base_r + length), 0.5 + math.sin(tip_a) * (base_r + length))
    left = (0.5 + math.cos(angle + math.pi / 2) * half_wid + math.cos(angle) * base_r,
            0.5 + math.sin(angle + math.pi / 2) * half_wid + math.sin(angle) * base_r)
    right = (0.5 + math.cos(angle - math.pi / 2) * half_wid + math.cos(angle) * base_r,
             0.5 + math.sin(angle - math.pi / 2) * half_wid + math.sin(angle) * base_r)
    c.poly([tip, left, right], lum=lum, alpha=255)


def _fitting(c: Canvas, style: str, angle: float, r: float, band: float):
    """The mount seated on the band at a compass point, per family."""
    deg = math.degrees(angle)
    ca, sa = math.cos(angle), math.sin(angle)
    cx, cy = 0.5 + ca * r, 0.5 + sa * r

    def pt(u, v):
        return (cx + u * ca - v * sa, cy + u * sa + v * ca)

    if style == "crescent":
        # A thick arc segment hugging the band, horns following the ring.
        c.arc(0.5, 0.5, r, deg - 20, deg + 20, band * 0.62, lum=70, alpha=255)
        c.arc(0.5, 0.5, r, deg - 16, deg + 16, band * 0.42, lum=235, alpha=255)
        _radial_diamond(c, angle, r, band * 0.30, band * 0.13, lum=120)
    elif style == "cross":
        _radial_diamond(c, angle, r, band * 0.95, band * 0.42, lum=70)
        c.line(cx - ca * band * 0.75, cy - sa * band * 0.75,
               cx + ca * band * 0.75, cy + sa * band * 0.75, band * 0.24, lum=238, alpha=255)
        c.line(cx + sa * band * 0.55, cy - ca * band * 0.55,
               cx - sa * band * 0.55, cy + ca * band * 0.55, band * 0.24, lum=238, alpha=255)
    elif style == "leaf":
        # Pointed oval with shoulders, midrib darker: reads as a leaf, not a gem.
        L, Wd = band * 1.15, band * 0.44
        c.poly([pt(L, 0), pt(L * 0.30, Wd), pt(-L * 0.62, Wd * 0.55),
                pt(-L, 0), pt(-L * 0.62, -Wd * 0.55), pt(L * 0.30, -Wd)], lum=70, alpha=255)
        c.poly([pt(L * 0.85, 0), pt(L * 0.24, Wd * 0.72), pt(-L * 0.52, Wd * 0.40),
                pt(-L * 0.85, 0), pt(-L * 0.52, -Wd * 0.40), pt(L * 0.24, -Wd * 0.72)],
               lum=228, alpha=255)
        rib_a, rib_b = pt(L * 0.75, 0), pt(-L * 0.75, 0)
        c.line(rib_a[0], rib_a[1], rib_b[0], rib_b[1], band * 0.09, lum=110, alpha=255)
    elif style == "plate":
        L, Wd = band * 0.95, band * 0.52
        c.poly([pt(L, Wd * 0.55), pt(L, -Wd * 0.55), pt(-L, -Wd), pt(-L, Wd)], lum=70, alpha=255)
        c.poly([pt(L * 0.82, Wd * 0.42), pt(L * 0.82, -Wd * 0.42),
                pt(-L * 0.82, -Wd * 0.82), pt(-L * 0.82, Wd * 0.82)], lum=225, alpha=255)
        n_a, n_b = pt(0, Wd * 0.7), pt(0, -Wd * 0.7)
        c.line(n_a[0], n_a[1], n_b[0], n_b[1], band * 0.10, lum=95, alpha=255)
    elif style == "barb":
        # Two swept blades leaning the same way: the umbral cue, while the ring
        # as a whole stays radially repeated.
        _tapered_spike(c, angle, r - band * 0.55, band * 1.35, band * 0.30, sweep=0.16, lum=70)
        _tapered_spike(c, angle, r - band * 0.45, band * 1.15, band * 0.22, sweep=0.16, lum=232)
    elif style == "scale":
        c.arc(0.5, 0.5, r + band * 0.10, deg - 16, deg + 16, band * 0.50, lum=70, alpha=255)
        c.arc(0.5, 0.5, r - band * 0.12, deg - 11, deg + 11, band * 0.38, lum=225, alpha=255)
        _tapered_spike(c, angle, r + band * 0.30, band * 0.55, band * 0.16, lum=235)
    else:  # neutral: the pointed diamond
        _radial_diamond(c, angle, r, band * 1.05, band * 0.48, lum=70)
        _radial_diamond(c, angle, r, band * 0.88, band * 0.36, lum=230)
        _radial_diamond(c, angle, r, band * 0.34, band * 0.14, lum=120)


def _finial(c: Canvas, style: str, angle: float, base_r: float, is_long: bool):
    """The crown spike growing outward from the band, per family."""
    L = 0.055 if is_long else 0.030
    Wd = 0.011 if is_long else 0.008
    lum = 215 if is_long else 190
    if style == "spire":
        _tapered_spike(c, angle, base_r, L * 1.15, Wd * 0.72, lum=lum)
    elif style == "ray":
        _tapered_spike(c, angle, base_r, L * 0.92, Wd * 1.55, lum=lum)
    elif style == "antler":
        _tapered_spike(c, angle, base_r, L, Wd, sweep=0.10, lum=lum)
        if is_long:
            _tapered_spike(c, angle + 0.045, base_r + L * 0.35, L * 0.45, Wd * 0.6,
                           sweep=-0.22, lum=lum - 15)
    elif style == "blade":
        _tapered_spike(c, angle, base_r, L, Wd * 1.2, lum=lum)
        bx, by = 0.5 + math.cos(angle) * (base_r + 0.004), 0.5 + math.sin(angle) * (base_r + 0.004)
        c.line(bx + math.cos(angle + math.pi / 2) * Wd * 1.7,
               by + math.sin(angle + math.pi / 2) * Wd * 1.7,
               bx + math.cos(angle - math.pi / 2) * Wd * 1.7,
               by + math.sin(angle - math.pi / 2) * Wd * 1.7, 0.006, lum=lum + 20, alpha=255)
    elif style == "hook":
        _tapered_spike(c, angle, base_r, L, Wd, sweep=0.20, lum=lum)
    elif style == "horn":
        _tapered_spike(c, angle, base_r, L * 0.7, Wd * 1.35, sweep=0.10, lum=lum - 20)
        _tapered_spike(c, angle + 0.06, base_r + L * 0.30, L * 0.55, Wd * 0.85,
                       sweep=0.18, lum=lum)
    else:  # neutral
        _spike(c, angle, base_r, L, Wd, lum=lum)


def _filigree(c: Canvas, style: str, outer: float):
    """Detached outer arc-work on the diagonals, per family."""
    for k in range(4):
        deg = k * 90.0 + 45.0
        if style == "orbit":
            c.arc(0.5, 0.5, outer + 0.016, deg - 24, deg + 24, 0.006, lum=200, alpha=255)
            c.arc(0.5, 0.5, outer + 0.030, deg - 14, deg + 14, 0.005, lum=170, alpha=255)
        elif style == "halo":
            c.arc(0.5, 0.5, outer + 0.020, deg - 38, deg + 38, 0.007, lum=205, alpha=255)
        elif style == "vine":
            c.arc(0.5, 0.5, outer + 0.014, deg - 24, deg - 4, 0.006, lum=200, alpha=255)
            c.arc(0.5, 0.5, outer + 0.026, deg + 4, deg + 24, 0.006, lum=180, alpha=255)
        elif style == "chevron":
            a = math.radians(deg)
            mx, my = 0.5 + math.cos(a) * (outer + 0.026), 0.5 + math.sin(a) * (outer + 0.026)
            for side in (1, -1):
                ex = 0.5 + math.cos(a + side * 0.16) * (outer + 0.008)
                ey = 0.5 + math.sin(a + side * 0.16) * (outer + 0.008)
                c.line(mx, my, ex, ey, 0.007, lum=205, alpha=255)
        elif style == "thin":
            c.arc(0.5, 0.5, outer + 0.014, deg - 15, deg + 15, 0.004, lum=190, alpha=255)
        elif style == "wing":
            c.arc(0.5, 0.5, outer + 0.016, deg - 26, deg + 26, 0.007, lum=205, alpha=255)
            c.arc(0.5, 0.5, outer + 0.028, deg - 15, deg + 15, 0.005, lum=175, alpha=255)
        else:  # neutral
            c.arc(0.5, 0.5, outer + 0.020, deg - 26, deg + 26, 0.007, lum=200, alpha=255)


def build_casing(tier: int, family: str = None) -> Image.Image:
    cfg = CASING_TIERS[tier]
    style = FAMILY_STYLE.get(family or "", {})
    c = Canvas(CASING_SIZE, SS)

    inner = BAND_INNER
    outer = inner + cfg["band"]     # escalation grows outward
    mid = (outer + inner) / 2
    band = cfg["band"]

    # Filigree first, so every ornament overlaps its ends.
    if cfg["filigree"]:
        _filigree(c, style.get("fil", "neutral"), outer)

    # Crown finials next, so the band covers their inner ends.
    if cfg["finials"]:
        n = cfg["finials"]
        for i in range(n):
            a = (i / n) * 2 * math.pi - math.pi / 2
            _finial(c, style.get("fin", "neutral"), a, outer - 0.004, i % 2 == 0)

    # Outer band with the bevel lips: a bright lip outside and a dark lip inside
    # is the cheapest thing that reads as a rounded metal section.
    c.ring(0.5, 0.5, outer, inner, lum=178, alpha=255)
    c.ring(0.5, 0.5, outer, outer - band * 0.18, lum=242, alpha=255)
    c.ring(0.5, 0.5, inner + band * 0.16, inner, lum=88, alpha=255)

    # Inner border ring: the second rim of the assembly, identical at every
    # tier. The XP channel runs between this and the band above -- it is what
    # makes the arc read as SET INTO the frame rather than floating inside it.
    c.ring(0.5, 0.5, INNER_RIM_OUTER, INNER_RIM_INNER, lum=170, alpha=255)
    c.ring(0.5, 0.5, INNER_RIM_OUTER, INNER_RIM_OUTER - 0.005, lum=235, alpha=255)
    c.ring(0.5, 0.5, INNER_RIM_INNER + 0.005, INNER_RIM_INNER, lum=90, alpha=255)

    # Fittings at the compass points (and diagonals at tier 4).
    if cfg["diamonds"]:
        n = cfg["diamonds"]
        for i in range(n):
            a = (i / n) * 2 * math.pi - math.pi / 2
            _fitting(c, style.get("fit", "neutral"), a, mid, band)

    # Small outer points between the fittings: the notched edge that keeps the
    # band from reading as a plain washer at a glance.
    if cfg["points"]:
        n = cfg["points"]
        offset = math.pi / n  # midway between the fitting positions
        for i in range(n):
            a = (i / n) * 2 * math.pi - math.pi / 2 + offset
            _spike(c, a, outer - 0.002, 0.018, 0.007, lum=205)

    c.apply_light(strength=0.40)
    return c.resolve(alpha_blur=0.6)


# --------------------------------------------------------------------------
# FILL CHANNEL -- the XP arc annulus and the groove it runs in
# --------------------------------------------------------------------------

# Radial placement: exactly the gap between the casing's two rims (2026-08-16,
# second pass). The outer band's inner edge is fixed at BAND_INNER = 0.345 and
# the inner border ring's outer edge at 0.264, so the channel fills the gap
# with a hair of clearance on each side -- the arc is SET INTO the frame, which
# is the reference's whole construction. Both files are consumed by a Cooldown
# swipe in SigilBarStyle.lua, which reveals sigil-fill clockwise from the crest.
FILL_OUTER = 0.338
FILL_INNER = 0.270


def build_fill() -> Image.Image:
    """The bright annulus the swipe reveals. Near-white so the runtime tint
    (class accent or XP bar colour) lands on it the way it lands on the fill
    texture of every other style."""
    c = Canvas(CASING_SIZE, SS)

    c.ring(0.5, 0.5, FILL_OUTER, FILL_INNER, lum=235, alpha=255)
    # The same narrow-lip bevel trick the casing uses, so the arc reads as a
    # solid inlay rather than a flat band.
    band = FILL_OUTER - FILL_INNER
    c.ring(0.5, 0.5, FILL_OUTER, FILL_OUTER - band * 0.14, lum=255, alpha=255)
    c.ring(0.5, 0.5, FILL_INNER + band * 0.12, FILL_INNER, lum=180, alpha=255)

    c.apply_light(strength=0.25)
    return c.resolve(alpha_blur=0.5)


def build_track() -> Image.Image:
    """The recessed groove, drawn statically under the arcs. Without it an
    empty or nearly-empty channel is invisible against the cavity and the arc
    appears from nowhere; with it the eye knows the path before the fill does."""
    c = Canvas(CASING_SIZE, SS)

    c.ring(0.5, 0.5, FILL_OUTER, FILL_INNER, lum=30, alpha=215)
    # Groove lips: dark inside the recess, a faint catch-light on the rim.
    band = FILL_OUTER - FILL_INNER
    c.ring(0.5, 0.5, FILL_OUTER, FILL_OUTER - band * 0.10, lum=8, alpha=235)
    c.ring(0.5, 0.5, FILL_OUTER + 0.006, FILL_OUTER, lum=110, alpha=160)
    c.ring(0.5, 0.5, FILL_INNER, FILL_INNER - 0.006, lum=95, alpha=140)

    c.apply_light(strength=0.20)
    return c.resolve(alpha_blur=0.5)


# --------------------------------------------------------------------------
# CRESTS -- the class mark at 6 o'clock
# --------------------------------------------------------------------------

# The medallion: the official class crests are uniformly ROUND badges -- one
# circular frame per class with the class motif inside -- so the plate is a
# single medallion for everyone (2026-08-16; the six family plate shapes moved
# aside once the family identity migrated into the casing theming). Bright rim,
# thin accent ring, darker body: the badge construction, drawn from primitives.
def _medallion(c: Canvas):
    cx, cy, r = 0.5, 0.52, 0.42
    c.disc(cx, cy, r, lum=205, alpha=255)                      # rim
    c.disc(cx, cy, r * 0.90, lum=96, alpha=255)                # body
    c.ring(cx, cy, r * 0.84, r * 0.81, lum=175, alpha=255)     # accent ring


def _motif(c: Canvas, class_token: str):
    """The class\'s iconic motif, drawn fresh from primitives.

    Aimed at the official class crests\' ICONOGRAPHY -- crossed swords, the
    warhammer, the drawn bow, paired daggers, the winged holy orb, the crossed
    warglaives -- while shipping nothing traced, copied or derived from
    Blizzard\'s artwork. Motifs are concepts; the drawings here are ours.
    Bold and simple on purpose: at 64px detail turns to mud.
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
    elif class_token == "PRIEST":                    # winged holy orb
        c.disc(cx, cy - 0.02, 0.10, lum=250, alpha=255)
        for k in range(3):                           # three rays above the orb
            a = -math.pi / 2 + (k - 1) * 0.5
            c.line(cx + math.cos(a) * 0.13, cy - 0.02 + math.sin(a) * 0.13,
                   cx + math.cos(a) * 0.27, cy - 0.02 + math.sin(a) * 0.27,
                   W * 0.55, lum=230, alpha=255)
        for side in (-1, 1):                         # swept wings at the sides
            c.poly([(cx + side * 0.12, cy + 0.02), (cx + side * 0.30, cy - 0.10),
                    (cx + side * 0.26, cy + 0.06), (cx + side * 0.12, cy + 0.10)],
                   lum=235, alpha=255)
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
    elif class_token == "DEMONHUNTER":               # crossed warglaives
        # Each glaive: a crescent blade (thick arc) with a short centre grip.
        for side in (-1, 1):
            gx = cx + side * 0.05
            c.arc(gx, cy, 0.24, 250 - side * 20, 470 - side * 20,
                  W * 1.15, lum=245, alpha=255)
            c.line(gx - 0.07, cy, gx + 0.07, cy, W * 0.8, lum=200, alpha=255)
    elif class_token == "EVOKER":                    # wing
        c.poly([(cx - 0.26, cy + 0.22), (cx - 0.02, cy - 0.28), (cx + 0.06, cy - 0.02),
                (cx + 0.24, cy - 0.16), (cx + 0.12, cy + 0.24)], lum=245, alpha=255)
        c.line(cx - 0.10, cy + 0.02, cx + 0.10, cy + 0.06, W * 0.5, lum=120, alpha=255)


def build_crest(class_token: str) -> Image.Image:
    c = Canvas(CREST_SIZE, CREST_SS)
    _medallion(c)
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
        print(f"  neutral tier {tier}")
    themed = {}
    for family in FAMILY_STYLE:
        themed[family] = {}
        for tier in (1, 2, 3, 4):
            img = build_casing(tier, family)
            themed[family][tier] = img
            save_tga(img, os.path.join(args.out, f"sigil-casing-{family}-{tier}.tga"))
            written += 1
        print(f"  {family}")

    print("crests")
    crests = {}
    for class_token in CLASSES:
        img = build_crest(class_token)
        crests[class_token] = img
        save_tga(img, os.path.join(args.out, f"sigil-crest-{class_token.lower()}.tga"))
        written += 1
        print(f"  {class_token.lower()}")

    print("fill channel")
    save_tga(build_fill(), os.path.join(args.out, "sigil-fill.tga"))
    save_tga(build_track(), os.path.join(args.out, "sigil-track.tga"))
    written += 2
    print("  fill + track")

    print(f"\n{written} TGA files written to {args.out}")

    if args.preview:
        _write_previews(here, casings, crests)

    return 0


def _write_previews(raw_dir, casings, crests):
    """Contact sheets on a dark slate, tinted like a class colour would tint
    them, so the output can be judged the way it will actually be seen."""
    def tinted(img, rgb):
        r, g, b, a = img.split()
        return Image.merge("RGBA", (
            r.point(lambda v: int(v * rgb[0])),
            g.point(lambda v: int(v * rgb[1])),
            b.point(lambda v: int(v * rgb[2])), a))

    gold = (1.0, 0.82, 0.42)

    families = ["neutral"] + list(FAMILY_STYLE)
    sheet = Image.new("RGBA", (4 * 256, len(families) * 256), (24, 24, 30, 255))
    for row, family in enumerate(families):
        for i, tier in enumerate((1, 2, 3, 4)):
            img = casings[tier] if family == "neutral" else build_casing(tier, family)
            sheet.alpha_composite(tinted(img, gold), (i * 256, row * 256))
    sheet.convert("RGB").save(os.path.join(raw_dir, "sigil-preview-casings.png"))

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
