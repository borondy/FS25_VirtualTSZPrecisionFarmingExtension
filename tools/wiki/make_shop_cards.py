"""Builds docs/wiki/images/shop-products-<lang>.png: a grid of the VirtualTSZ shop cards (store icons, name, price).

Run from the mod folder:  python tools/wiki/make_shop_cards.py
Reads shop/store_<ID>.png and the PRODUCTS table of tools/generate_products.py. Needs Pillow and the Windows Arial fonts.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from generate_products import PRODUCTS  # noqa: E402

FONTS = "C:/Windows/Fonts/"
BG, CARD, TEXT, MUTED, ACCENT = (36, 38, 36), (52, 54, 52), (255, 255, 255), (170, 172, 170), (140, 178, 20)
COLS, CW, CH, GAP, PAD = 4, 300, 330, 14, 20


def fit(draw, text, font_path, size, width):
	while size > 12:
		font = ImageFont.truetype(font_path, size)
		if draw.textlength(text, font=font) <= width:
			return font
		size -= 1
	return ImageFont.truetype(font_path, 12)


def build(lang):
	rows = (len(PRODUCTS) + COLS - 1) // COLS
	w, h = PAD * 2 + COLS * CW + (COLS - 1) * GAP, PAD * 2 + rows * CH + (rows - 1) * GAP
	img = Image.new("RGB", (w, h), BG)
	d = ImageDraw.Draw(img)
	for i, p in enumerate(PRODUCTS):
		x = PAD + (i % COLS) * (CW + GAP)
		y = PAD + (i // COLS) * (CH + GAP)
		d.rounded_rectangle([x, y, x + CW, y + CH], 12, fill=CARD)
		icon = Image.open(os.path.join(ROOT, "shop", "store_%s.png" % p["id"])).convert("RGBA")
		icon = icon.crop(icon.getbbox())
		icon.thumbnail((CW - 80, 190), Image.LANCZOS)
		img.paste(icon, (x + (CW - icon.width) // 2, y + 16 + (190 - icon.height) // 2), icon)
		name = p[lang]
		d.text((x + CW // 2, y + 235), name, font=fit(d, name, FONTS + "arialbd.ttf", 21, CW - 24), fill=TEXT, anchor="mm")
		kind = "IBC" if p["liquid"] else "Big bag"
		d.text((x + CW // 2, y + 268), kind, font=ImageFont.truetype(FONTS + "arial.ttf", 17), fill=MUTED, anchor="mm")
		price = "{:,} / 1000 l".format(int(p["price"])).replace(",", " ")
		d.text((x + CW // 2, y + 300), price, font=ImageFont.truetype(FONTS + "arialbd.ttf", 22), fill=ACCENT, anchor="mm")
	out = os.path.join(ROOT, "docs", "wiki", "images", "shop-products-%s.png" % lang)
	img.save(out, optimize=True)
	print(out, img.size)


for lang in ("en", "hu"):
	build(lang)
