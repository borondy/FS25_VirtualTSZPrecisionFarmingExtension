"""Screenshot placeholder for the wiki.

    python tools/wiki/make_placeholder.py <id> "<EN description>" "<HU description>"

Writes docs/wiki/images/placeholder-<id>.svg (1600 x 900, light grey, centered text) and prints the id and the
descriptions so they can be copied into the "Screenshots to take" table of the review notes.
Reference it in a page as ![alt](images/placeholder-<id>.svg). Replace it with the real screenshot later.
"""
import os
import re
import sys
import textwrap
from xml.sax.saxutils import escape

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "wiki", "images")


def main(argv):
    if len(argv) != 4 or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", argv[1]):
        print(__doc__)
        return 2
    pid, en, hu = argv[1], argv[2], argv[3]
    lines = []
    for text in ("Screenshot coming soon: " + en, "Képernyőkép hamarosan: " + hu):
        lines += textwrap.wrap(text, 52) + [""]
    lines.pop()
    lh = 62
    y0 = 450 - (len(lines) - 1) * lh / 2 + 16
    out = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 900" width="1600" height="900" font-family="Segoe UI, Roboto, Helvetica, Arial, sans-serif">',
           '<rect width="1600" height="900" fill="#e6e6e6"/>',
           '<rect x="12" y="12" width="1576" height="876" fill="none" stroke="#b5b5b5" stroke-width="4" stroke-dasharray="18 12"/>']
    for i, s in enumerate(lines):
        if s:
            out.append('<text x="800" y="%.0f" font-size="46" fill="#4a4a4a" text-anchor="middle">%s</text>' % (y0 + i * lh, escape(s)))
    out.append('</svg>')
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "placeholder-%s.svg" % pid)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out))
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    print("wrote", os.path.normpath(path))
    print("review-notes row:")
    print("| %s | <page> | %s / %s |" % (pid, en, hu))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
