"""Generates the label textures and model copies of the bag and IBC products.

Run from the mod folder:  python tools/generate_textures.py
Needs Pillow and numpy, and the base game data (GAME_DATA below).
Writes to models/: vtszBag_<ID>.i3d, vtszTank_<ID>.i3d (+ one shared .shapes copy each),
bag_<ID>_diffuse.dds (2048x1024, DXT1), tank_<ID>_decal.dds (1024x1024, DXT5).
The product list comes from tools/generate_products.py (one source for names and N-P2O5-K2O).
The Helm logo and texts of the base textures are painted over; only the paper/crease shading is kept.
"""
import os
import re
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_products import PRODUCTS  # noqa: E402

GAME_DATA = "C:/Program Files (x86)/Steam/steamapps/common/Farming Simulator 25/data/objects"
FONT = "C:/Windows/Fonts/arialbd.ttf"
BRAND = "VirtualTSZ"
OUT = os.path.join(ROOT, "models")

# family colours: (accent, dark). N blue, P orange, K red, mixed green, organic brown
FAMILY = {
    "N": ((38, 110, 200), (20, 65, 130)),
    "P": ((232, 132, 20), (150, 80, 10)),
    "K": ((200, 50, 62), (120, 25, 35)),
    "NPK": ((70, 165, 55), (35, 100, 30)),
    "ORG": ((140, 95, 50), (85, 55, 28)),
}


def family(p):
    if p["om"] > 0:
        return "ORG"
    kinds = [x for x in ("n", "p", "k") if p[x] > 0]
    return kinds[0].upper() if len(kinds) == 1 else "NPK"


def split_name(p):
    """'Pétisó 27 (27-0-0)' -> ('Pétisó 27', '27-0-0')"""
    m = re.match(r"^(.*?)\s*\(([^)]*)\)\s*$", p["hu"])
    return (m.group(1), m.group(2)) if m else (p["hu"], "")


def font(size):
    return ImageFont.truetype(FONT, size)


def fit(draw, text, max_w, size, min_size=24):
    while size > min_size and draw.textlength(text, font=font(size)) > max_w:
        size -= 2
    return font(size)


def text_lines(name, max_w, draw, size):
    """Splits the name into at most two lines (at spaces) so the font stays large."""
    words = name.split(" ")
    if len(words) == 1 or draw.textlength(name, font=font(size)) <= max_w:
        return [name]
    best = None
    for i in range(1, len(words)):
        a, b = " ".join(words[:i]), " ".join(words[i:])
        w = max(draw.textlength(a, font=font(size)), draw.textlength(b, font=font(size)))
        if best is None or w < best[0]:
            best = (w, [a, b])
    return best[1]


def draw_chem(draw, x, y, size, fill, right=None):
    """Draws N-P2O5-K2O with real subscripts (Arial Bold has no subscript glyphs). Right-aligned to `right` when given."""
    parts = [("N-P", 0), ("2", 1), ("O", 0), ("5", 1), ("-K", 0), ("2", 1), ("O", 0)]
    big, small = font(size), font(int(size * 0.62))
    width = sum(draw.textlength(t, font=small if sub else big) for t, sub in parts)
    if right is not None:
        x = right - width
    for t, sub in parts:
        draw.text((x, y + (size * 0.38 if sub else 0)), t, font=small if sub else big, fill=fill)
        x += draw.textlength(t, font=small if sub else big)


def draw_centered(draw, cx, y, text, fnt, fill):
    w = draw.textlength(text, font=fnt)
    draw.text((cx - w / 2, y), text, font=fnt, fill=fill)


def recolor(img, accent, dark):
    """Recolours the Helm green and orange (flaps, band, handle) of a float RGB array (0-255) to the family colours, keeps the shading."""
    rgb = img / 255.0
    mx, mn = rgb.max(2), rgb.min(2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    green = (sat > 0.35) & (g >= r) & (g > b)
    orange = (sat > 0.45) & (r > g) & (g > b) & (r > 0.7)
    shade = np.maximum(mx, 0.05)
    for mask, target, ref in ((green, accent, 0.72), (orange, dark, 0.96)):
        t = np.array(target, np.float32) / 255.0
        img[mask] = (t[None, :] * (shade[mask][:, None] / ref)).clip(0, 1) * 255
    return img


# ---------------------------------------------------------------- bag
def bag_texture(p, base):
    """base: RGB uint8 array of the Helm diffuse (1024 high, 2048 wide)."""
    accent, dark = FAMILY[family(p)]
    img = base.astype(np.float32)
    h, w, _ = img.shape
    img = recolor(img, accent, dark)
    # wipe the Helm logos and texts: paper colour from a clean strip above, light noise
    region = img[300:480, 40:880].reshape(-1, 3)
    paper = region[region.sum(1) >= np.percentile(region.sum(1), 90)].mean(0)
    rng = np.random.default_rng(1)
    for x0 in (0, 916):
        y0, y1 = 480, 887
        patch = paper[None, None, :] + rng.normal(0, 1.6, (y1 - y0, 916, 1))
        img[y0:y1, x0:x0 + 916] = patch
        # band and stripe, redrawn flat
        img[886:990, x0:x0 + 900] = np.array(accent, np.float32)
        img[990:1024, x0:x0 + 900] = np.array(dark, np.float32)
    out = Image.fromarray(img.clip(0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(out)
    name, npk = split_name(p)
    for x0 in (0, 916):
        left, width = x0 + 50, 800
        d.text((left, 505), BRAND, font=font(58), fill=accent)
        d.rectangle((left, 575, left + 140, 583), fill=accent)
        lines = text_lines(name, width, d, 118)
        fnt = min((fit(d, ln, width, 118) for ln in lines), key=lambda f: f.size)
        y = 610
        for ln in lines:
            d.text((left, y), ln, font=fnt, fill=dark)
            y += int(fnt.size * 1.12)
        if npk:
            d.rounded_rectangle((left, 790, left + 800, 870), radius=18, fill=accent)
            d.text((left + 24, 800), npk, font=font(64), fill=(255, 255, 255))
            draw_chem(d, 0, 812, 40, (255, 255, 255), right=left + 800 - 24)
        d.text((left, 912), "SZEMCS\u00c9S M\u0170TR\u00c1GYA", font=font(52), fill=(255, 255, 255))
    return out


# ---------------------------------------------------------------- tank decal
def tank_decal(p):
    accent, dark = FAMILY[family(p)]
    out = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    # top strip: brand plate (the Helm logo spot)
    d.rounded_rectangle((250, 20, 774, 250), radius=110, fill=(250, 250, 250, 255), outline=accent + (255,), width=14)
    fnt = fit(d, BRAND, 440, 110)
    draw_centered(d, 512, 135 - fnt.size * 0.62, BRAND, fnt, dark + (255,))
    # left panel: label
    px0, px1, py0 = 0, 510, 304
    d.rectangle((px0, py0, px1, 1024), fill=(250, 250, 250, 255))
    name, npk = split_name(p)
    left, width = 34, 450
    d.text((left, py0 + 70), BRAND, font=font(42), fill=accent + (255,))
    d.rectangle((left, py0 + 128, left + 100, py0 + 134), fill=accent + (255,))
    lines = text_lines(name, width, d, 84)
    fnt = min((fit(d, ln, width, 84) for ln in lines), key=lambda f: f.size)
    y = py0 + 200
    for ln in lines:
        d.text((left, y), ln, font=fnt, fill=dark + (255,))
        y += int(fnt.size * 1.12)
    if npk:
        d.rounded_rectangle((left, y + 24, left + width, y + 112), radius=16, fill=accent + (255,))
        nf = fit(d, npk, width - 40, 60)
        d.text((left + 20, y + 24 + (88 - nf.size) // 2 - 4), npk, font=nf, fill=(255, 255, 255, 255))
        draw_chem(d, left, y + 126, 34, dark + (255,))
    d.rectangle((px0, 880, px1, 980), fill=accent + (255,))
    d.rectangle((px0, 980, px1, 1024), fill=dark + (255,))
    lab = "FOLY\u00c9KONY M\u0170TR\u00c1GYA"
    d.text((left, 915), lab, font=fit(d, lab, width, 44), fill=(255, 255, 255, 255))
    return out


# ---------------------------------------------------------------- i3d copies
def read_i3d(rel):
    with open(os.path.join(GAME_DATA, rel), encoding="iso-8859-1") as f:
        return f.read()


def write_text(path, text):
    with open(path, "w", encoding="iso-8859-1", newline="\n") as f:
        f.write(text)


def main():
    os.makedirs(OUT, exist_ok=True)
    shutil.copyfile(os.path.join(GAME_DATA, "bigBag/bigBag.i3d.shapes"), os.path.join(OUT, "vtszBag.i3d.shapes"))
    shutil.copyfile(os.path.join(GAME_DATA, "pallets/liquidTank/liquidTank.i3d.shapes"), os.path.join(OUT, "vtszTank.i3d.shapes"))
    bag_i3d = read_i3d("bigBag/bigBag.i3d")
    tank_i3d = read_i3d("pallets/liquidTank/liquidTank.i3d")
    helm_png = "$data/objects/bigBag/fertilizer/bigBagFertilizerHelm_diffuse.png"
    decal_png = "$data/objects/pallets/liquidTank/helmDecal_diffuse.png"
    assert helm_png in bag_i3d and decal_png in tank_i3d
    base = np.array(Image.open(os.path.join(GAME_DATA, "bigBag/fertilizer/bigBagFertilizerHelm_diffuse.dds")).convert("RGB"))
    for p in PRODUCTS:
        pid = p["id"]
        if p["liquid"]:
            tank_decal(p).save(os.path.join(OUT, "tank_%s_decal.dds" % pid), format="DDS", pixel_format="DXT5")
            text = tank_i3d.replace(decal_png, "tank_%s_decal.dds" % pid)
            text = text.replace('externalShapesFile="liquidTank.i3d.shapes"', 'externalShapesFile="vtszTank.i3d.shapes"')
            write_text(os.path.join(OUT, "vtszTank_%s.i3d" % pid), text)
        else:
            bag_texture(p, base).save(os.path.join(OUT, "bag_%s_diffuse.dds" % pid), format="DDS", pixel_format="DXT1")
            text = bag_i3d.replace(helm_png, "bag_%s_diffuse.dds" % pid)
            text = text.replace('externalShapesFile="bigBag.i3d.shapes"', 'externalShapesFile="vtszBag.i3d.shapes"')
            write_text(os.path.join(OUT, "vtszBag_%s.i3d" % pid), text)
    print("textures and i3d written to", OUT)


if __name__ == "__main__":
    sys.exit(main())
