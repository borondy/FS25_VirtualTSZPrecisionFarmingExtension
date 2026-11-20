"""Builds a throw-away mod folder for the GIANTS FS Icon Generator (tools/iconGen/mods/FS25_VtszIconGen).

Why: the generator renders the store items in the GIANTS Editor, which knows only the base game fill types. With our own fill types
(KALISO60, ...) the bag gets no fill level (collapsed, tall shape) and no fillTypeMaterial (plain white). This folder holds copies of the
bag/IBC shop xmls with the base game fill types (fertilizer / LIQUIDFERTILIZER) so the bag is full and keeps our label texture
(the label comes from our own i3d copy, referenced through the Helm refNode).

Run from the mod folder:  python tools/make_icongen.py          (build)
                          python tools/make_icongen.py collect  (copy the rendered shop/store_<ID>.png back into shop/)
Then start FSIconGenerator.exe with Mods Folder Path = <mod folder>/tools/iconGen, select the VtszIconGen items, Generate.
"""
import glob
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "tools", "iconGen", "mods", "FS25_VtszIconGen")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_products import PRODUCTS  # noqa: E402


def build():
    if os.path.isdir(GEN):
        shutil.rmtree(GEN)
    os.makedirs(os.path.join(GEN, "shop"))
    shutil.copytree(os.path.join(ROOT, "models"), os.path.join(GEN, "models"))
    items = []
    for p in PRODUCTS:
        pid = p["id"]
        name = ("ibc_%s.xml" if p["liquid"] else "bigBag_%s.xml") % pid
        with open(os.path.join(ROOT, "shop", name), encoding="utf-8") as f:
            text = f.read()
        base = "LIQUIDFERTILIZER" if p["liquid"] else "fertilizer"
        text = text.replace('"%s"' % pid, '"%s"' % base).replace(">%s<" % pid, ">%s<" % base)
        with open(os.path.join(GEN, "shop", name), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        items.append('        <storeItem xmlFilename="shop/%s"/>' % name)
    with open(os.path.join(GEN, "modDesc.xml"), "w", encoding="utf-8", newline="\n") as f:
        f.write('<?xml version="1.0" encoding="utf-8" standalone="no"?>\n<modDesc descVersion="108">\n    <author>Hunor</author>\n    <version>0.0.0.1</version>\n'
                '    <title><en>VtszIconGen (icon rendering only)</en></title>\n    <description><en>Icon rendering helper, not a real mod.</en></description>\n'
                '    <storeItems>\n%s\n    </storeItems>\n</modDesc>\n' % "\n".join(items))
    print("built", GEN)


def collect():
    n = 0
    for src in glob.glob(os.path.join(GEN, "shop", "store_*.png")):
        shutil.copyfile(src, os.path.join(ROOT, "shop", os.path.basename(src)))
        n += 1
    print("copied", n, "files to shop/")


if __name__ == "__main__":
    collect() if sys.argv[1:] == ["collect"] else build()
