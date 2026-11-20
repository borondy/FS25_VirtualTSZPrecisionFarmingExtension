"""Wiki charts: organic matter of the rotations A-E over their game years, EN and HU.

Three aligned parts: yield potential per harvest (top), OM curve with a label on every harvest (middle),
one lane per fertilizer product with every application (bottom).
Reuses sim.py / rot.py, so the numbers stay in sync with the config copy in sim.py (check_config.py keeps that in sync).
Writes docs/wiki/images/om-rotation-<a..e>-<en|hu>.svg.

    python om_chart.py          # all rotations
    python om_chart.py d        # one rotation
"""
import math
import os
import sys
from rot import A, B, C, D, E, run, TG
import chartkit as ck
from chartkit import COL, ORG, MIX, num, mon, L, R, PW

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "wiki", "images")
START_OM = 3.25  # run() default start value (mean of the four noise levels on loam)
ROTATIONS = {'a': (A, 5), 'b': (B, 4), 'c': (C, 4), 'd': (D, 6), 'e': (E, 8)}  # events, game years

# fertilizer lanes in display order: product -> colour (only products the rotation uses are drawn)
LANES = [('LIQUIDMANURE', ORG), ('MANURE', ORG), ('DIGESTATE', ORG), ('PETISO27', COL['N']), ('KARBAMID46', COL['N']), ('NITROSOL30', COL['N']),
         ('NPK15_15_15', MIX), ('NPK8_24_24', MIX), ('MAP11_52', COL['P']), ('TSP46', COL['P']), ('SSP18', COL['P']), ('KALISO60', COL['K']), ('PATENTKALI', COL['K'])]
ORGANIC = ('LIQUIDMANURE', 'MANURE', 'DIGESTATE')
FORAGE_CROPS = ('SILAGEMAIZE',)  # chopped with the forage harvester

TEXT = {
    'en': dict(
        title="Organic matter on %s", sub="Rotation %s on loam: %s",
        names=dict(a="a livestock silage rotation", b="an arable farm without livestock", c="a dairy farm", d="a dairy silage rotation", e="a dairy rotation with an alfalfa break"),
        desc=dict(a="green rye + silage maize / vetch rye + corn / winter barley / canola",
                  b="corn / winter wheat / sunflowers / winter barley, fertiliser only, straw baled",
                  c="silage maize / winter wheat / faba beans / winter barley, manure after the silage",
                  d="manure after every silage maize, sized to the nitrogen target",
                  e="as D, plus manure after the barley and an alfalfa year"),
        foot="OM changes are 6 times the real-world annual value per game year (timeScale 6); on the server 6 game years ≈ 1 real year. Simulation with typical yields, not an in-game measurement.",
        target="target", xlabel="game year", ylabel="organic matter, %",
        start="start %s %%", end="end %s %%", delta="%s percentage points in %d game years",
        yield_title="Yield potential at harvest, %", lane_title="Fertilizer applications (kg/ha; manure, slurry and digestate in 1000 l/ha)",
        lim=dict(N="nitrogen", P="phosphorus", K="potassium", OM="organic matter", none="no limit (≥ 99.5 %)"),
        crops=dict(GREENRYE="green rye", SILAGEMAIZE="silage maize", VETCHRYE="vetch rye", MAIZE="corn", WINTERBARLEY="winter barley", WHOLEBARLEY="whole-crop barley",
                   WINTERWHEAT="winter wheat", CANOLA="canola", SUNFLOWER="sunflowers", FABABEAN="faba beans", ALFALFA="alfalfa"),
        verbs=dict(harvest="harvest", chop="chopping", mow="mowing"),
        prod=dict(LIQUIDMANURE="Slurry", MANURE="Manure", DIGESTATE="Digestate", PETISO27="CAN 27", KARBAMID46="Urea 46", NITROSOL30="Nitrosol 30", NPK15_15_15="NPK 15-15-15",
                  NPK8_24_24="NPK 8-24-24", MAP11_52="MAP 11-52", TSP46="TSP 46", SSP18="SSP 18", KALISO60="Potash 60", PATENTKALI="Patentkali"), dec='.'),
    'hu': dict(
        title="Szerves anyag %s", sub="%s. forgó vályogon: %s",
        names=dict(a="állattartó silóforgóban", b="állat nélküli gazdaságban", c="tejelő gazdaságban", d="tehenészeti sílóforgóban", e="lucernás szünetes tehenészeti forgóban"),
        desc=dict(a="zöldrozs + silókukorica / rozsos bükköny + szemes kukorica / őszi árpa / repce",
                  b="szemes kukorica / őszi búza / napraforgó / őszi árpa, csak műtrágya, szalma lehordva",
                  c="silókukorica / őszi búza / lóbab / őszi árpa, trágya a silókukorica után",
                  d="trágya minden silókukorica után, a nitrogéncélhoz méretezve",
                  e="mint a D, plusz trágya az árpa után és egy lucernás év"),
        foot="Az OM-változás játékévenként a valós éves érték 6-szorosa (timeScale 6); a szerveren 6 játékév ≈ 1 valós év. Szimuláció tipikus hozamokkal, nem játékbeli mérés.",
        target="célérték", xlabel="játékév", ylabel="szerves anyag, %",
        start="kezdőérték %s %%", end="végérték %s %%", delta="%s %%-pont %d játékév alatt",
        yield_title="Hozampotenciál az aratáskor, %", lane_title="Trágyázások (kg/ha; szilárd-, hígtrágya és fermentált ezer l/ha)",
        lim=dict(N="nitrogén", P="foszfor", K="kálium", OM="szerves anyag", none="nincs korlát (≥ 99,5 %)"),
        crops=dict(GREENRYE="zöldrozs", SILAGEMAIZE="silókukorica", VETCHRYE="rozsos bükköny", MAIZE="szemes kukorica", WINTERBARLEY="őszi árpa", WHOLEBARLEY="egész növényes árpa",
                   WINTERWHEAT="őszi búza", CANOLA="repce", SUNFLOWER="napraforgó", FABABEAN="lóbab", ALFALFA="lucerna"),
        verbs=dict(harvest="aratás", chop="szecskázás", mow="kaszálás"),
        prod=dict(LIQUIDMANURE="Hígtrágya", MANURE="Szilárd trágya", DIGESTATE="Fermentált", PETISO27="Pétisó 27", KARBAMID46="Karbamid 46", NITROSOL30="Nitrosol 30",
                  NPK15_15_15="NPK 15-15-15", NPK8_24_24="NPK 8-24-24", MAP11_52="MAP 11-52", TSP46="TSZF 46", SSP18="SZF 18", KALISO60="Kálisó 60", PATENTKALI="Patentkali"), dec=','),
}


def limiting(y):
    fp, fk, fo, total, fn = y
    if total >= 0.995:
        return 'none'
    cand = {'N': fn, 'P': fp, 'K': fk, 'OM': fo}
    return min(cand, key=cand.get)


def place_labels(items, lo_x, hi_x, gap=6):
    """items: [(x, w)] -> [(x0, level)] with as few levels as possible. A box sits on a level, centred under its leader or shifted so the leader
    still hits it. Constraints: boxes on one level do not overlap, and no leader crosses a box on a level above its own.
    Depth-first search with the number of levels raised until a layout exists."""
    n = len(items)

    def compatible(i, x0i, li, j, x0j, lj):
        xi, wi = items[i]
        xj, wj = items[j]
        if li == lj and not (x0i + wi + gap <= x0j or x0j + wj + gap <= x0i):
            return False
        if lj < li and x0j - 3 <= xi <= x0j + wj + 3:
            return False  # leader i crosses box j
        if li < lj and x0i - 3 <= xj <= x0i + wi + 3:
            return False  # leader j crosses box i
        return True

    def search(i, maxlvl, placed):
        if i == n:
            return placed
        x, w = items[i]
        for lvl in range(maxlvl):
            for x0 in (x - w / 2, x - w + 12, x - 12):
                if x0 < lo_x or x0 + w > hi_x:
                    continue
                if all(compatible(i, x0, lvl, j, p0, pl) for j, (p0, pl) in enumerate(placed)):
                    r = search(i + 1, maxlvl, placed + [(x0, lvl)])
                    if r:
                        return r
        return None

    for maxlvl in range(1, 9):
        r = search(0, maxlvl, [])
        if r:
            return r
    return [(x - w / 2, 7) for x, w in items]


def build(lang, key):
    T = TEXT[lang]
    dec = T['dec']
    events, years = ROTATIONS[key]
    rows = run(events)
    trace = run.trace
    end_om = rows[-1]['OM']
    delta = end_om - START_OM
    harv = [r for r in rows if r['kind'] == 'h']

    pw = PW
    months = years * 12
    X = ck.X_of(months)

    # yield panel
    YT, YB = 145, 265
    ylo = math.floor((min(r['y'][3] for r in harv) - 0.005) * 20) / 20
    yhi = 1.035
    step = 0.05 if yhi - ylo <= 0.2 else 0.1

    def YY(v):
        return YB - (v - ylo) / (yhi - ylo) * (YB - YT)

    # harvest labels: text, box width, level
    lab = []
    for r in harv:
        nm = T['crops']['WHOLEBARLEY'] if (r['forage'] and r['name'] == 'WINTERBARLEY') else T['crops'][r['name']]
        if r['name'] == 'ALFALFA':
            verb = ''
        elif r['forage'] or r['name'] in FORAGE_CROPS:
            verb = T['verbs']['chop']
        else:
            verb = T['verbs']['harvest']
        l2 = (verb + ' ' if verb else '') + num(r['dOM'], dec, 2, True)
        lab.append((nm, l2, max(len(nm), len(l2)) * 7.9 + 18))
    xs = [X(mon(r['t'])) for r in harv]
    pos = place_labels([(x, w) for x, (_, _, w) in zip(xs, lab)], L + 4, L + pw + R - 14)
    nlev = max(lv for _, lv in pos) + 1
    # OM panel scale: curve on top, label stack under it
    vals = [v for _, v in trace] + [START_OM, end_om]
    hi, lo = max(vals), min(vals)
    PXU = 300.0
    TOP = 315
    ph = (hi - lo + 0.32) * PXU + nlev * 62 + 40
    BOT = TOP + ph
    ymax = hi + 0.32
    ymin = ymax - ph / PXU

    def Y(v):
        return BOT - (v - ymin) / (ymax - ymin) * ph

    used = [(p, c) for p, c in LANES if any(r['kind'] == 'sp' and r['name'] == p for r in rows)]
    LT = BOT + 90
    LROW = 30
    LB = LT + LROW * len(used)
    H = int(LB + 40 + 24 * ck.footer_lines(T['foot']))

    o = ck.open_svg(H)
    ck.header(o, T['title'] % T['names'][key], T['sub'] % (key.upper(), T['desc'][key]))
    ck.year_bands(o, X, years, YT, LB, BOT + 28, T['xlabel'])

    # ---- yield potential panel
    o.append('<text x="56" y="%d" font-size="19" font-weight="700" fill="#2b2b2b">%s</text>' % (YT - 14, T['yield_title']))
    lx = L + pw
    for k in ('none', 'OM', 'K', 'P', 'N'):
        label = T['lim'][k]
        lx -= len(label) * 8.4 + 26
        o.append('<circle cx="%.1f" cy="%d" r="6" fill="%s"/>' % (lx + 6, YT - 20, COL[k]))
        o.append('<text x="%.1f" y="%d" font-size="16" fill="#555555">%s</text>' % (lx + 17, YT - 14, label))
    v = ylo
    while v <= 1.0001:
        o.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#e3dfd8" stroke-width="1.5"/>' % (L, L + pw, YY(v), YY(v)))
        o.append('<text x="%d" y="%.1f" font-size="18" fill="#555555" text-anchor="end">%d</text>' % (L - 10, YY(v) + 6, round(v * 100)))
        v += step
    o.append('<line x1="%d" x2="%d" y1="%d" y2="%d" stroke="#999999" stroke-width="2"/>' % (L, L + pw, YB, YB))
    prev = []  # (x, raise) of earlier value labels: a label too close to the previous one is lifted
    for r, x in zip(harv, xs):
        total = r['y'][3]
        c = COL[limiting(r['y'])]
        lift = 0
        while any(abs(x - px) < 40 and pl == lift for px, pl in prev[-3:]):
            lift += 1
        prev.append((x, lift))
        o.append('<line x1="%.1f" x2="%.1f" y1="%d" y2="%.1f" stroke="%s" stroke-width="3"/>' % (x, x, YB, YY(total), c))
        o.append('<circle cx="%.1f" cy="%.1f" r="7" fill="#ffffff" stroke="%s" stroke-width="4"/>' % (x, YY(total), c))
        o.append('<text x="%.1f" y="%.1f" font-size="17" font-weight="700" fill="#2b2b2b" text-anchor="middle">%s</text>' % (x, YY(total) - 13 - 19 * lift, num(total * 100, dec, 1)))

    # ---- OM panel
    v = math.ceil((lo - 0.1) * 5) / 5
    while v <= ymax:
        if Y(v) > TOP + 4:
            o.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#e3dfd8" stroke-width="1.5"/>' % (L, L + pw, Y(v), Y(v)))
            o.append('<text x="%d" y="%.1f" font-size="19" fill="#555555" text-anchor="end">%s</text>' % (L - 10, Y(v) + 6, num(v, dec, 1)))
        v += 0.2
    o.append('<text transform="translate(%d,%.1f) rotate(-90)" font-size="19" fill="#777777" text-anchor="middle">%s</text>' % (L - 62, (TOP + BOT) / 2, T['ylabel']))
    o.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#999999" stroke-width="2"/>' % (L, L + pw, BOT, BOT))
    ty = Y(TG['OM'])
    o.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#8a8a8a" stroke-width="2" stroke-dasharray="9 7"/>' % (L, L + pw, ty, ty))
    o.append('<text x="%d" y="%.1f" font-size="17" fill="#666666">%s</text>' % (L + pw + 8, ty - 2, T['target']))
    o.append('<text x="%d" y="%.1f" font-size="17" fill="#666666">%s</text>' % (L + pw + 8, ty + 17, num(TG['OM'], dec, 1) + ' %'))
    pts = ' '.join('%.1f,%.1f' % (X(m), Y(v)) for m, v in trace)
    o.append('<polyline points="%s" fill="none" stroke="#a8641a" stroke-width="4" stroke-linejoin="round" stroke-linecap="round"/>' % pts)

    base = Y(lo) + 46
    for r, x, (_, lvl) in zip(harv, xs, pos):
        o.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#7a7a7a" stroke-width="1.8"/>' % (x, Y(r['OM']) + 8, x, base + 62 * lvl - 22))
    for (nm, l2, w), (x0, lvl) in zip(lab, pos):  # boxes after all leaders, so no leader is drawn over a label
        by = base + 62 * lvl
        o.append('<rect x="%.1f" y="%.1f" width="%.1f" height="54" rx="8" fill="#ffffff" stroke="#c9c2b6" stroke-width="1.5"/>' % (x0, by - 22, w))
        o.append('<text x="%.1f" y="%.1f" font-size="16" font-weight="700" fill="#2b2b2b" text-anchor="middle">%s</text>' % (x0 + w / 2, by, nm))
        o.append('<text x="%.1f" y="%.1f" font-size="16" fill="#2b2b2b" text-anchor="middle">%s</text>' % (x0 + w / 2, by + 24, l2))

    def pt(m, v):
        o.append('<circle cx="%.1f" cy="%.1f" r="7" fill="#ffffff" stroke="#a8641a" stroke-width="4"/>' % (X(m), Y(v)))

    for r in harv:
        pt(mon(r['t']), r['OM'])
    pt(0, START_OM)
    pt(mon(rows[-1]['t']), end_om)
    # start and end boxes in the free band above the curve
    st = T['start'] % num(START_OM, dec)
    o.append('<rect x="%d" y="%d" width="%.1f" height="34" rx="8" fill="#ffffff" stroke="#c9c2b6" stroke-width="1.5"/>' % (L + 12, TOP + 4, len(st) * 10.6 + 24))
    o.append('<text x="%d" y="%d" font-size="20" font-weight="700" fill="#2b2b2b">%s</text>' % (L + 24, TOP + 27, st))
    o.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%d" stroke="#7a7a7a" stroke-width="1.8"/>' % (L, Y(START_OM) - 8, L + 12, TOP + 38))
    ex = X(mon(rows[-1]['t']))
    d2 = T['delta'] % (num(delta, dec, 2, True), years)
    en1 = T['end'] % num(end_om, dec)
    ew = max(len(d2), len(en1)) * 10.4 + 24
    o.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%d" stroke="#7a7a7a" stroke-width="1.8"/>' % (ex, Y(end_om) - 8, ex, TOP + 63))
    o.append('<rect x="%.1f" y="%d" width="%.1f" height="59" rx="8" fill="#ffffff" stroke="#c9c2b6" stroke-width="1.5"/>' % (L + pw - ew, TOP + 4, ew))
    o.append('<text x="%d" y="%d" font-size="20" font-weight="700" fill="#2b2b2b" text-anchor="end">%s</text>' % (L + pw - 10, TOP + 28, en1))
    o.append('<text x="%d" y="%d" font-size="20" fill="#2b2b2b" text-anchor="end">%s</text>' % (L + pw - 10, TOP + 53, d2))

    # ---- fertilizer lanes
    o.append('<text x="56" y="%.1f" font-size="19" font-weight="700" fill="#2b2b2b">%s</text>' % (LT - 14, T['lane_title']))
    for i, (prod, col) in enumerate(used):
        cy = LT + LROW * i + LROW / 2
        o.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#e3dfd8" stroke-width="1.5"/>' % (L, L + pw, cy, cy))
        o.append('<text x="%d" y="%.1f" font-size="17" fill="#555555" text-anchor="end">%s</text>' % (L - 10, cy + 6, T['prod'][prod]))
        evs = [r for r in rows if r['kind'] == 'sp' and r['name'] == prod]
        dots = [X(mon(r['t'])) for r in evs]
        taken = []  # label boxes placed in this row
        for r, x in zip(evs, dots):
            txt = str(int(r['amt'] / 1000)) if prod in ORGANIC else str(int(r['amt']))
            tw = len(txt) * 7.6 + 2
            # right of the dot, else left of it, else above it
            cands = [(x + 10, x + 10 + tw, 'start', x + 10, cy + 5), (x - 10 - tw, x - 10, 'end', x - 10, cy + 5), (x - tw / 2, x + tw / 2, 'middle', x, cy - 10)]
            for a, b, anc, tx, tyy in cands:
                other_dots = any(b > d - 7 and a < d + 7 for d in dots if abs(d - x) > 0.5)
                if anc != 'middle' and (other_dots or any(b > q0 and a < q1 for q0, q1 in taken) or a < L + 2 or b > L + pw + 60):
                    continue
                taken.append((a, b))
                o.append('<text x="%.1f" y="%.1f" font-size="14" fill="#2b2b2b" text-anchor="%s">%s</text>' % (tx, tyy, anc, txt))
                break
        for x in dots:
            o.append('<circle cx="%.1f" cy="%.1f" r="6" fill="%s"/>' % (x, cy, col))
    ck.footer(o, T['foot'], LB + 40)
    o.append('</svg>')
    return '\n'.join(o), dict(end=end_om, delta=delta, harvests=len(harv), applications=sum(1 for r in rows if r['kind'] == 'sp'), levels=nlev, height=H)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    sys.stdout.reconfigure(encoding='utf-8')
    for key in (sys.argv[1:] or sorted(ROTATIONS)):
        for lang in ('hu', 'en'):
            svg, vals = build(lang, key)
            with open(os.path.join(OUT, 'om-rotation-%s-%s.svg' % (key, lang)), 'w', encoding='utf-8', newline='\n') as fh:
                fh.write(svg)
        print(key, {k: round(v, 3) for k, v in vals.items()})
