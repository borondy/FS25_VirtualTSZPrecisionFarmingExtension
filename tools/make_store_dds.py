"""Writes shop/store_<ID>.dds (DXT5, full mip chain) next to each shop/store_<ID>.png.
The game loads the .dds beside the .png, so XML keeps pointing at the .png. Without mips the engine
logs "CPU mip generation code activated for texture ... please build mips".
Run from the mod folder after re-rendering icons: python tools/make_store_dds.py
Needs Pillow."""
import glob, io, os, struct
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def payload(im):
	buf = io.BytesIO()
	im.save(buf, format="DDS", pixel_format="DXT5")
	return buf.getvalue()[128:]

def build(im):
	im = im.convert("RGBA")
	w, h = im.size
	levels = []
	cur = im
	while True:
		levels.append(payload(cur))
		if cur.width == 1 and cur.height == 1:
			break
		cur = cur.resize((max(1, cur.width // 2), max(1, cur.height // 2)), Image.LANCZOS)
	# header: flags CAPS|HEIGHT|WIDTH|PIXELFORMAT|MIPMAPCOUNT|LINEARSIZE
	flags = 0x1 | 0x2 | 0x4 | 0x1000 | 0x20000 | 0x80000
	linear = len(levels[0])
	hdr = b"DDS " + struct.pack("<7I", 124, flags, h, w, linear, 0, len(levels))
	hdr += struct.pack("<11I", *([0] * 11))
	hdr += struct.pack("<4I", 32, 0x4, struct.unpack("<I", b"DXT5")[0], 0) + struct.pack("<4I", 0, 0, 0, 0)
	hdr += struct.pack("<5I", 0x1000 | 0x8 | 0x400000, 0, 0, 0, 0)  # TEXTURE | COMPLEX | MIPMAP
	return hdr + b"".join(levels)

for png in sorted(glob.glob(os.path.join(ROOT, "shop", "store_*.png"))):
	out = png[:-4] + ".dds"
	with open(out, "wb") as f:
		f.write(build(Image.open(png)))
	print(out)
