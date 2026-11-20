"""README crop tables computed from config/NutrientMaps.xml (single source for "Betakarítás: elvonás" and
"OM-változás betakarításonként"). Usage:  python om_tables.py   (prints both tables, Hungarian, ready to paste into README.md).
check_config.py compares the printed tables with the README."""
import os
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
CONFIG = os.path.join(ROOT, "config", "NutrientMaps.xml")

# (config fruit type, Hungarian name). Order = README order.
CROPS = [
    ("WINTERWHEAT", "Őszi búza"), ("WINTERBARLEY", "Őszi árpa"), ("OAT", "Zab"), ("RYE", "Rozs"), ("TRITICALE", "Tritikálé"), ("SPELT", "Tönköly"),
    ("MAIZE", "Szemes kukorica"), ("SILAGEMAIZE", "Silókukorica"), ("SORGHUM", "Cirok"), ("GREENRYE", "Zöldrozs"), ("VETCHRYE", "Rozsos bükköny"),
    ("CANOLA", "Repce"), ("SUNFLOWER", "Napraforgó"), ("SUGARBEET", "Cukorrépa"), ("POTATO", "Burgonya"), ("SOYBEAN", "Szója"),
    ("PEA", "Borsó"), ("FODDERPEA", "Takarmányborsó"), ("FABABEAN", "Lóbab"),
    ("GRASS", "Fű (vágásonként)"), ("FIELDGRASS", "Szántóföldi fű (vágásonként)"), ("MEADOW", "Mezei fű (vágásonként)"), ("ALFALFA", "Lucerna (vágásonként)"), ("CLOVER", "Here (vágásonként)"),
    ("DEFAULT", "Egyéb (DEFAULT)"),
]
# crops of the rotation examples (order of the OM table)
EXAMPLE_CROPS = ["GREENRYE", "VETCHRYE", "SILAGEMAIZE", "MAIZE", "WINTERBARLEY", "WINTERWHEAT", "CANOLA", "SUNFLOWER", "FABABEAN", "ALFALFA"]


def load(path=CONFIG):
    root = ET.parse(path).getroot()
    maps = {}
    for nm in root.find("nutrientMaps").findall("nutrientMap"):
        reqs = {}
        for fr in nm.find("fruitRequirements").findall("fruitRequirement"):
            reqs[fr.get("fruitTypeName")] = {k: float(v) for k, v in fr.attrib.items() if k != "fruitTypeName"}
        maps[nm.get("id")] = dict(attrs=nm.attrib, reqs=reqs)
    return maps


def req(maps, mid, fruit):
    r = maps[mid]["reqs"]
    d = dict(r.get("DEFAULT", {}))
    d.update(r.get(fruit, {}))
    return d


def om_changes(maps, fruit):
    """OM change per harvest (real time, typical yield) for: straw taken, straw chopped, forage header / mower."""
    o = req(maps, "OM", fruit)
    a = maps["OM"]["attrs"]
    removal, gain, rstraw = o.get("removal", 0), o.get("gain", 0), o.get("removalStraw", 0)
    straw_gain = o.get("strawGain", float(a.get("strawChopperGain", 0)))
    taken = gain - removal - rstraw
    chopped = gain - removal + straw_gain
    if "forageRemoval" in o:
        forage = -(max(removal, o["forageRemoval"]) + rstraw)
    else:
        forage = taken
    return taken, chopped, forage


def fmt(v, nd=4, sign=True):
    v = v + (1e-9 if v >= 0 else -1e-9)  # round half away from zero (0.01125 -> 0.0113)
    if abs(v) < 5 * 10 ** -(nd + 1):
        return "0"
    s = ("%+." + str(nd) + "f") % v if sign else ("%." + str(nd) + "f") % v
    return s.replace(".", ",").replace("-", "−")


def fmt_play(v):
    v = v + (1e-9 if v >= 0 else -1e-9)
    if abs(v) < 0.0005:
        return "0,000"
    return ("%+.3f" % v).replace("-", "−").replace(".", ",")


def pk_cell(maps, mid, fruit):
    r = req(maps, mid, fruit)
    rem, st = r.get("removal", 0), r.get("removalStraw", 0)
    return "%d (+%d)" % (rem, st) if st else "%d" % rem


def removal_table(maps):
    L = ["| Növény | P₂O₅ (+ szalma) | K₂O (+ szalma) | OM, szalma lehordva | OM, szalma aprítva | OM, szecskázás / kasza |", "|---|--:|--:|--:|--:|--:|"]
    for fruit, name in CROPS:
        t, c, f = om_changes(maps, fruit)
        L.append("| %s | %s | %s | %s | %s | %s |" % (name, pk_cell(maps, "P", fruit), pk_cell(maps, "K", fruit), fmt(t), fmt(c), fmt(f)))
    return "\n".join(L)


def example_table(maps):
    ts = float(maps["OM"]["attrs"].get("timeScale", 1))
    L = ["| Növény | Lehordott szalma / szár | Aprított szalma | Szecskázás / kasza |", "|---|--:|--:|--:|"]
    names = dict(CROPS)
    for fruit in EXAMPLE_CROPS:
        t, c, f = om_changes(maps, fruit)
        L.append("| %s | %s | %s | %s |" % (names[fruit], fmt_play(t * ts), fmt_play(c * ts), fmt_play(f * ts)))
    return "\n".join(L)


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    m = load()
    print(removal_table(m))
    print()
    print(example_table(m))
