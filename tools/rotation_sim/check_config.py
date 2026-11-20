"""Consistency check: rotation_sim <-> config/NutrientMaps.xml <-> Szalok map.xml <-> wiki pages (docs/wiki).
Run from tools/rotation_sim:  python check_config.py     (exit code 1 on any mismatch)
Checks:
 1. sim.py constants (products, crops, targets, relative P/K map storage + soft cap + start deltas, yield curves, OM timeScale, mineralisation) equal the config
 2. sim N targets / reductions (soil type 3) equal the Szalok map.xml (skipped with a warning when the file is missing)
 3. the wiki crop table ("Betakarítás: elvonás", "OM-változás betakarításonként") equal om_tables.py
 4. the wiki rotation tables equal the gen.py output
 5. (removed with the long README)
 6. every sim.CHOPPER_N_CROPS crop has a harvest chopperType in the game data or the Szalok foliage xml (see 2b)
 7. the number of cuts in the gen.py E band labels and in the HU wiki E intro equals the ALFALFA harvest events per year in rot.py E
 8. every harvest event date of rot.py lies in the harvest window derived from the Szalok foliage growth chain (see harvest_months)
"""
import math
import os
import sys
import re
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, "tools"))
import sim  # noqa: E402
import om_tables  # noqa: E402

SZALOK_MAP = os.path.join(os.path.expanduser("~"), "Documents", "My Games", "FarmingSimulator2025", "mods", "FS25_Szalok", "map", "map.xml")
errors = []
SIM_TO_CFG = {"PETISO27": None, "KARBAMID46": None, "NITROSOL30": None}


def err(msg):
    errors.append(msg)
    print("MISMATCH:", msg)


def close(a, b, tol=1e-6):
    return abs(a - b) <= tol * max(1.0, abs(a), abs(b))


def curve(root, mid):
    nm = [n for n in root.find("nutrientMaps") if n.get("id") == mid][0]
    return [(float(y.get("difference")), float(y.get("yieldFactor"))) for y in nm.find("yieldMappings")]


def harvest_months(path):
    """Calendar months in which a stand of this crop can be harvest ready, derived from the foliage xml <growth><seasonal>.
    Sowing puts the first foliageState into every period with plantingAllowed="true"; every period moves a stand one step along its <update>
    chain (states without an update stay). A month counts when, after the updates of its period (applied on the first day of the period),
    some reachable state has isHarvestReady="true". The result is the union over all stands (a necessary condition, not a guarantee)."""
    root = ET.parse(path).getroot()
    layer = root.find("foliageLayer")
    seasonal = root.find("growth/seasonal")
    if layer is None or seasonal is None:
        return None
    states = [st.get("name") for st in layer.findall("foliageState")]
    ready = {st.get("name") for st in layer.findall("foliageState") if st.get("isHarvestReady") == "true"}
    periods = seasonal.findall("period")
    if len(periods) != 12 or not states:
        return None
    reach = set()
    months = set()
    for year in range(4):  # the cycle repeats; the last year is the steady state
        months = set()
        for i, per in enumerate(periods):
            if per.get("plantingAllowed") == "true":
                reach.add(states[0])
            ups = {}
            for u in per.findall("update"):
                ups.setdefault(u.get("startState"), set()).add(u.get("endState"))
            nxt = set()
            for st in reach:
                nxt |= ups.get(st, {st})
            reach = nxt
            if reach & ready:
                months.add((i + 2) % 12 + 1)  # period 1 = EARLY_SPRING = March
    return months


def main():
    maps = om_tables.load()
    window_cache = {}
    root = ET.parse(om_tables.CONFIG).getroot()
    # 1a products: P / K / OM per 1000 l from the config fillTypes, N from the product generator
    fills = {}
    for nm in root.find("nutrientMaps"):
        for ft in nm.find("fillTypes"):
            fills.setdefault(nm.get("id"), {})[ft.get("name")] = float(ft.get("value"))
    import generate_products as gp
    prods = {p["id"]: p for p in gp.PRODUCTS}
    for name, (p, k, om, n, _est) in sim.PROD.items():
        cp = fills["P"].get(name, 0.0)
        ck = fills["K"].get(name, 0.0)
        co = fills["OM"].get(name, 0.0)
        if not (close(p, cp) and close(k, ck) and close(om, co)):
            err("product %s P/K/OM sim (%s, %s, %s) != config (%s, %s, %s)" % (name, p, k, om, cp, ck, co))
        if name in prods:
            pr = prods[name]
            for lab, simv, cfv in (("N", n, pr["n"] * pr["density"] * 1000), ("P", p, pr["p"] * pr["density"] * 1000), ("K", k, pr["k"] * pr["density"] * 1000)):
                if not close(simv, cfv, 1e-4):
                    err("product %s %s sim %s != generate_products %s" % (name, lab, simv, cfv))
    # 1b crops
    for fruit, (pr_, ps, kr, ks, omr, omrs, omg, omsg) in sim.CROP.items():
        P, K, O = (om_tables.req(maps, m, fruit) for m in ("P", "K", "OM"))
        exp = (P.get("removal", 0), P.get("removalStraw", 0), K.get("removal", 0), K.get("removalStraw", 0), O.get("removal", 0), O.get("removalStraw", 0), O.get("gain", 0), O.get("strawGain", 0))
        got = (pr_, ps, kr, ks, omr, omrs, omg, omsg)
        if not all(close(a, b) for a, b in zip(exp, got)):
            err("crop %s sim %s != config %s" % (fruit, got, exp))
    for fruit, v in sim.FORAGE_REMOVAL.items():
        if not close(v, om_tables.req(maps, "OM", fruit).get("forageRemoval", -1)):
            err("forageRemoval %s" % fruit)
    # 1c targets, curves, scales
    def tgt(mid):
        nm = [n for n in root.find("nutrientMaps") if n.get("id") == mid][0]
        return {int(t.get("soilTypeIndex")): float(t.get("value")) for t in nm.find("targets")}[3]
    for key, mid in (("P", "P"), ("K", "K"), ("OM", "OM")):
        if not close(sim.TG[key], tgt(mid)):
            err("target %s sim %s != config %s" % (key, sim.TG[key], tgt(mid)))
    kshare = float([n for n in root.find("nutrientMaps") if n.get("id") == "K"][0].get("targetRemovalShare", 0))
    if not close(sim.K_TARGET_SHARE, kshare):
        err("K targetRemovalShare")
    # 1c2 relative P / K maps (TODO.23): storage, soft cap, targetScale / share, start values as deltas
    for mid in ("P", "K"):
        nm = [n for n in root.find("nutrientMaps") if n.get("id") == mid][0]
        m = sim.MAPS[mid]
        lo_ = int(nm.get("levelOffset", 0))
        if lo_ <= 0:
            err("%s map is not relative (levelOffset %s): the sim models P and K as distance to the soil type target" % (mid, nm.get("levelOffset")))
        got = (int(nm.get("numChannels")), float(nm.get("step")), lo_, float(nm.get("maxUnits")) if nm.get("maxUnits") else None)
        want = (m["bits"], m["step"], m["offset"], m["cap"])
        if got != want:
            err("%s map storage (numChannels, step, levelOffset, maxUnits) sim %s != config %s" % (mid, want, got))
        if not close(sim.TARGET_SHARE[mid], float(nm.get("targetRemovalShare", 0))):
            err("%s targetRemovalShare sim %s != config %s" % (mid, sim.TARGET_SHARE[mid], nm.get("targetRemovalShare", 0)))
        if "initialValues" in [c.tag for c in nm] and any(iv.get("levels") for iv in nm.find("initialValues")):
            err("%s initialValue uses absolute levels, the relative map needs deltas" % mid)
        # the crops of the examples must not override targetScale / targetRemovalShare (the sim uses the map defaults)
        for fruit in sim.CROP:
            r = om_tables.req(maps, mid, fruit)
            if not close(r.get("targetScale", 1.0), sim.TARGET_SCALE) or ("targetRemovalShare" in r and not close(r["targetRemovalShare"], sim.TARGET_SHARE[mid])):
                err("%s fruitRequirement %s overrides targetScale / targetRemovalShare (sim has map defaults only)" % (mid, fruit))
        # start value of the soil type 3 on the sim scale = baseline + mean of the four deltas
        iv3 = [iv for iv in nm.find("initialValues") if iv.get("soilTypeIndex") == "3"][0]
        deltas = [float(x) for x in iv3.get("deltas").split()]
        idx = {"P": 0, "K": 1}[mid]
        if not close(sim.START[idx], sim.TG[mid] + sum(deltas) / len(deltas)):
            err("%s start value sim %s != baseline %s + mean delta %s" % (mid, sim.START[idx], sim.TG[mid], sum(deltas) / len(deltas)))
        # hard range -levelOffset x step .. matches the lowest yieldMapping key (floor)
        lo_dist = sim.dist_limits(mid)[0]
        if curve(root, mid)[0][0] < lo_dist:
            err("%s lowest yieldMapping key %s lies below the lowest storable distance %s" % (mid, curve(root, mid)[0][0], lo_dist))
    omn = [n for n in root.find("nutrientMaps") if n.get("id") == "OM"][0]
    iv3 = [iv for iv in omn.find("initialValues") if iv.get("soilTypeIndex") == "3"][0]
    dl = [float(x) for x in iv3.get("deltas").split()]
    if abs(sim.START[2] - (sim.TG["OM"] + sum(dl) / len(dl))) > 0.01:
        err("OM start value sim %s != baseline + mean delta %s" % (sim.START[2], sim.TG["OM"] + sum(dl) / len(dl)))
    # sim pH helper = NutrientMap:getPhAdjustedTarget (loam P at pH 5.0: efficiency 0.70 -> +257, below the +300 cap; K sugar beet-like extra 88 at eff 1 stays 88)
    if not close(sim.rel_target("P", 0.0, 0.7), 600 / 0.7 - 600) or not close(sim.rel_target("K", 88.0, 1.0), 88.0):
        err("sim.rel_target differs from the Lua relative target formula")
    if sim.rel_target("P", 0.0, 0.3) > 295.0 + 1e-9:
        err("sim.rel_target does not cap P at maxUnits minus one step")
    # P soft cap: a spread never lifts the content above baseline + maxUnits, a harvest change is only limited by the stored range
    if not close(sim.clamp_content("P", sim.TG["P"] + 400, True), sim.TG["P"] + 300) or not close(sim.clamp_content("K", sim.TG["K"] + 400, True), sim.TG["K"] + 400):
        err("sim.clamp_content soft cap")
    for name, mid in (("YP", "P"), ("YK", "K"), ("YO", "OM")):
        c = curve(root, mid)
        s = getattr(sim, name)
        if len(c) != len(s) or not all(close(a[0], b[0]) and close(a[1], b[1]) for a, b in zip(sorted(c), sorted(s))):
            err("yield curve %s sim != config" % name)
    om = [n for n in root.find("nutrientMaps") if n.get("id") == "OM"][0]
    if not close(sim.TS, float(om.get("timeScale"))):
        err("timeScale")
    mi = om.find("mineralisation")
    if not close(sim.MIN_RATE, float(mi.get("rate"))) or not close(sim.N_PER_PERCENT, float(mi.get("nPerPercent"))):
        err("mineralisation rate / nPerPercent")
    w = [float(x) for x in mi.get("weights").split()]
    sw = sum(w)
    if not all(close(a, b / sw) for a, b in zip(sim.MIN_WEIGHTS, w)):
        err("mineralisation weights (sim must hold the config values; config normalises them)")
    # 2 Szalok N values
    if os.path.exists(SZALOK_MAP):
        sx = ET.parse(SZALOK_MAP).getroot()
        for fr in sx.iter("fruitRequirement"):
            f = fr.get("fruitTypeName")
            if f in sim.NCROP:
                for soil in fr.findall("soil"):
                    if soil.get("soilTypeIndex") == "3":
                        t, r = int(soil.get("targetLevel")), int(soil.get("reduction"))
                        rf = int(soil.get("reductionForage", r))
                        want = sim.NCROP[f]
                        if f == "SILAGEMAIZE":  # silage maize is chopped with a forage header: reductionForage is the sim value
                            r = rf
                        if (t, r) != want:
                            err("N %s sim %s != Szalok map.xml (%s, %s)" % (f, want, t, r))
        # 2b the +25 kg N crops (sim.CHOPPER_N_CROPS) must have a harvest chopperType in the Szalok foliage xml files
        foliage = os.path.join(os.path.dirname(SZALOK_MAP), "foliage")
        chopper = set()
        fruit_files = {}
        for dirpath, _dirs, files in os.walk(foliage):
            for fn in files:
                if fn.endswith(".xml"):
                    try:
                        fx = ET.parse(os.path.join(dirpath, fn)).getroot()
                    except ET.ParseError:
                        continue
                    for ft in fx.iter("fruitType"):
                        if ft.get("name"):
                            fruit_files.setdefault(ft.get("name").upper(), os.path.join(dirpath, fn))
                        hv = ft.find("harvest")
                        if hv is not None and hv.get("chopperType") and ft.get("name"):
                            chopper.add(ft.get("name").upper())
        for f in sim.CHOPPER_N_CROPS:
            if chopper and f not in chopper:
                err("CHOPPER_N_CROPS %s has no harvest chopperType in the Szalok foliage xml" % f)
        # 8 harvest dates of the rotation examples inside the growth window of the Szalok foliage xml
        import rot
        for nm_, ev in (("A", rot.A), ("B", rot.B), ("C", rot.C), ("D", rot.D), ("E", rot.E)):
            for e in ev:
                if e[1] != "h" or e[2] not in fruit_files:
                    continue
                if e[2] not in window_cache:
                    window_cache[e[2]] = harvest_months(fruit_files[e[2]])
                win = window_cache[e[2]]
                if win is not None and e[0][1] not in win:
                    err("rot.py %s: %s harvest %s is outside the foliage growth window (months %s)" % (nm_, e[2], e[0], sorted(win)))
    else:
        print("WARNING: Szalok map.xml not found, N targets and harvest windows not checked")
    # 3 + 4 wiki crop table and rotation tables (generated blocks, python gen.py --wiki)
    import gen
    import wiki_rot
    pages = {}
    for lang, path in wiki_rot.PAGES.items():
        pages[lang] = open(path, encoding="utf-8").read()
    for lang in ("hu", "en"):
        if wiki_rot.om_table(lang).strip() not in pages[lang]:
            err("wiki %s crop OM table differs from wiki_rot.py (run python gen.py --wiki)" % lang)
        for nm_, ev, yrs in (("A", gen.A, 5), ("B", gen.B, 4), ("C", gen.C, 4), ("D", gen.D, 6), ("E", gen.E, 8)):
            rows = gen.run(ev)
            for what, text in (("ops", wiki_rot.ops_table(rows, lang)), ("summary", wiki_rot.sum_table(rows, yrs, lang))):
                if text.strip() not in pages[lang]:
                    err("wiki %s rotation %s %s differs from wiki_rot.py (run python gen.py --wiki)" % (lang, nm_, what))
    # 5 (README K target sentence) was removed with the long README: the K targets are in the Potassium wiki tables, not checked here.
    # 7 number of alfalfa cuts: E band labels in gen.py and the README E intro
    import gen
    cuts = {}
    for e in gen.E:
        if e[1] == "h" and e[2] == "ALFALFA":
            cuts[e[0][0]] = cuts.get(e[0][0], 0) + 1
    counts = set(cuts.values())
    labels = re.findall(r"lucerna \((\d+) kaszálás\)", open(os.path.join(HERE, "gen.py"), encoding="utf-8").read())
    if len(counts) != 1:
        err("rot.py E: the ALFALFA cuts per year differ: %s" % cuts)
    else:
        n = counts.pop()
        if len(labels) != len(cuts) or any(int(x) != n for x in labels):
            err("gen.py E band labels %s != %d ALFALFA events per year in rot.py E (%d alfalfa years)" % (labels, n, len(cuts)))
        if "évi %d lucernakaszálással" % n not in pages["hu"]:
            err("wiki HU E intro does not say 'évi %d lucernakaszálással'" % n)
    print("OK" if not errors else "%d mismatch(es)" % len(errors))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
