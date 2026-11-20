import os, json, textwrap
from rot import *
from xml.sax.saxutils import escape

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "readme")
os.makedirs(OUT, exist_ok=True)
PN = {'PETISO27': 'Pétisó 27 (27-0-0)', 'KARBAMID46': 'Karbamid (46-0-0)', 'MAP11_52': 'MAP (11-52-0)', 'TSP46': 'Tripleszuperfoszfát (0-46-0)', 'SSP18': 'Szuperfoszfát (0-18-0)', 'KALISO60': 'Kálisó 60 (0-0-60)', 'PATENTKALI': 'Patentkali (0-0-30)', 'NPK15_15_15': 'NPK (15-15-15)', 'NPK8_24_24': 'NPK (8-24-24)', 'NITROSOL30': 'Nitrosol UAN (30-0-0)', 'MANURE': 'Trágya', 'LIQUIDMANURE': 'Hígtrágya', 'DIGESTATE': 'Fermentált'}
CN = {'GREENRYE': 'zöldrozs', 'SILAGEMAIZE': 'silókukorica', 'VETCHRYE': 'rozsos bükköny', 'MAIZE': 'szemes kukorica', 'WINTERBARLEY': 'őszi árpa', 'WINTERWHEAT': 'őszi búza', 'CANOLA': 'repce', 'SUNFLOWER': 'napraforgó', 'FABABEAN': 'lóbab', 'ALFALFA': 'lucerna'}
MON = ['jan.', 'febr.', 'márc.', 'ápr.', 'máj.', 'jún.', 'júl.', 'aug.', 'szept.', 'okt.', 'nov.', 'dec.']


def mon(t):
    return (t[0] - 1) * 12 + (t[1] - 1) + t[2] / 31.0


def md(rows):
    L = ['| Idő | Művelet | ΔN | ΔP₂O₅ | ΔK₂O | ΔOM | OM lebomlás | N talajból | N | P₂O₅ | K₂O | OM % | Hozam |', '|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|']
    f = lambda v, fmt: (fmt % v) if abs(v) >= 0.5 else '·'
    for r in rows:
        t = r['t']
        d = '%d. év %s %d.' % (t[0], MON[t[1] - 1], t[2])
        if r['kind'] == 'sp':
            op = '%s %s l/ha' % (PN[r['name']], format(r['amt'], ',').replace(',', ' '))
            dn = ('≈' if r['est'] else '') + ('%+.0f' % r['dN'] if abs(r['dN']) >= 0.5 else '0') if r['dN'] else '·'
            y = ''
        else:
            if r['name'] == 'ALFALFA':
                op = '**Kaszálás:** lucerna'
            elif r['forage']:
                op = '**Aratás:** %s, egész növény (szecskázás / kasza)' % CN[r['name']]
            else:
                op = '**Aratás:** %s%s' % (CN[r['name']], '' if r['chop'] else ', szalma lehordva')
            dn = '%+.0f' % r['dN']
            y = '%.2f' % r['y'][3]
        dp = f(r['dP'], '%+.0f')
        dk = f(r['dK'], '%+.0f')
        do = '%+.3f' % r['dOM'] if abs(r['dOM']) > 1e-9 else '·'
        dd = '%+.3f' % r['dDecay'] if abs(r['dDecay']) > 5e-4 else '·'
        nr = '%+.0f' % r['dNrel'] if r['dNrel'] >= 0.5 else '·'
        L.append('| %s | %s | %s | %s | %s | %s | %s | %s | %.0f | %.0f | %.0f | %.2f | %s |' % (d, op, dn, dp, dk, do, dd, nr, r['N'], r['P'], r['K'], r['OM'], y))
    return chr(10).join(L)


def summary(rows, years):
    L = ['| Év | N be | ebből a talajból | N ki | P₂O₅ be | P₂O₅ ki | K₂O be | K₂O ki | OM nettó | ebből lebomlás | Év végén N | P₂O₅ | K₂O | OM % | Legrosszabb hozam |', '|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|']
    for y in range(1, years + 1):
        rs = [r for r in rows if r['t'][0] == y]
        nrel = sum(r['dNrel'] for r in rs)
        ni = sum(r['dN'] for r in rs if r['kind'] == 'sp') + nrel
        no = -sum(r['dN'] for r in rs if r['kind'] == 'h')
        pi = sum(r['dP'] for r in rs if r['kind'] == 'sp')
        po = -sum(r['dP'] for r in rs if r['kind'] == 'h')
        ki = sum(r['dK'] for r in rs if r['kind'] == 'sp')
        ko = -sum(r['dK'] for r in rs if r['kind'] == 'h')
        om = sum(r['dOM'] + r['dDecay'] for r in rs)
        dec = sum(r['dDecay'] for r in rs)
        ys = [r['y'][3] for r in rs if r['y']]
        e = rs[-1]
        L.append('| %d | %.0f | %.0f | %.0f | %.0f | %.0f | %.0f | %.0f | %+.3f | %+.3f | %.0f | %.0f | %.0f | %.2f | %.2f |' % (y, ni, nrel, no, pi, po, ki, ko, om, dec, e['N'], e['P'], e['K'], e['OM'], min(ys) if ys else 1))
    return chr(10).join(L)


LABELS = {
    'hu': dict(om='Szervesanyag (%)', target='cél %s', applied='kijuttatás', harvest='aratás / kaszálás', soil='célérték (Vályog, 3-as talajtípus)', year='%d. év'),
    'en': dict(om='Organic matter (%)', target='target %s', applied='application', harvest='harvest / cut', soil='target (Loam, soil type 3)', year='year %d'),
}


def svg(rows, bands, months, title, fn, start=START, lang='hu', callouts=None, outdir=None, comma=False):
    """Rotation chart. Default arguments give the README chart (Hungarian, decimal point). The wiki passes lang, callouts (numbered badges on
    the panels plus a key under the chart, see wiki_rot.py), outdir and comma (decimal comma)."""
    LB = LABELS[lang]
    dz = (lambda t: t.replace('.', ',')) if comma else (lambda t: t)
    callouts = callouts or []
    key_lines = []
    for c in callouts:
        key_lines.append(textwrap.wrap(c['text'], 112))
    keyH = (sum(len(l) for l in key_lines) * 17 + len(key_lines) * 7 + 8) if key_lines else 0
    W, H = 940, 830 + keyH
    L, R = 62, 16
    pw = W - L - R
    panels = [('N', 'N (kg/ha)', None, 40.0), ('P', 'P₂O₅ (kg/ha)', TG['P'], start[0]), ('K', 'K₂O (kg/ha)', TG['K'], start[1]), ('OM', LB['om'], TG['OM'], start[2])]
    out = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" font-family="Segoe UI, Arial, sans-serif" font-size="12">' % (W, H, W),
           '<rect width="%d" height="%d" fill="#ffffff"/>' % (W, H),
           '<text x="%d" y="22" font-size="15" font-weight="600" fill="#1a1a1a">%s</text>' % (L, title)]

    def X(m):
        return L + pw * m / months

    top0, ph, gap = 62, 150, 34
    badges_all = lambda key: []
    pal = ['#e8f1fb', '#fdf1de']
    for pi, (key, lab, tg, s0) in enumerate(panels):
        top = top0 + pi * (ph + gap)
        vals = [s0] + [r[key] for r in rows]
        tgs = [] if tg is None else [tg]
        lo = min(vals + tgs)
        hi = max(vals + tgs)
        pad = (hi - lo) * 0.15 or 1
        lo -= pad
        hi += pad

        def Y(v):
            return top + ph - (v - lo) / (hi - lo) * ph

        if pi == 0:
            for i, (a, b, name) in enumerate(bands):
                out.append('<rect x="%.1f" y="%d" width="%.1f" height="22" fill="%s"/>' % (X(a), top0 - 24, X(b) - X(a), ['#cfe3f7', '#fbe0b3'][i % 2]))
                bw = X(b) - X(a)
                if lang == 'hu' and not callouts:
                    out.append('<text x="%.1f" y="%d" text-anchor="middle" font-size="10" fill="#1a1a1a">%s</text>' % ((X(a) + X(b)) / 2, top0 - 9, name))
                else:
                    parts = [name]
                    if len(name) * 5.6 > bw - 4:
                        cut = name.find(' + ')
                        parts = [name[:cut + 2], name[cut + 3:]] if cut > 0 else textwrap.wrap(name, max(6, int((bw - 4) / 5.6)))[:2]
                    fs = 10 if len(parts) == 1 else 9
                    for li, part in enumerate(parts):
                        yy = top0 - 9 if len(parts) == 1 else top0 - 15 + li * 10
                        out.append('<text x="%.1f" y="%d" text-anchor="middle" font-size="%d" fill="#1a1a1a">%s</text>' % ((X(a) + X(b)) / 2, yy, fs, part))
        for i, (a, b, name) in enumerate(bands):
            out.append('<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="%s" opacity="0.6"/>' % (X(a), top, X(b) - X(a), ph, pal[i % 2]))
        out.append('<rect x="%d" y="%d" width="%d" height="%d" fill="none" stroke="#c8c8c8"/>' % (L, top, pw, ph))
        for k in range(5):
            v = lo + (hi - lo) * k / 4
            out.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#e2e2e2"/>' % (L, L + pw, Y(v), Y(v)))
            out.append('<text x="%d" y="%.1f" text-anchor="end" fill="#555">%s</text>' % (L - 6, Y(v) + 4, dz(('%.2f' % v) if key == 'OM' else ('%.0f' % v))))
        out.append('<text x="14" y="%d" transform="rotate(-90 14 %d)" text-anchor="middle" fill="#333">%s</text>' % (top + ph / 2, top + ph / 2, lab))
        if tg is not None:
            out.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#c0392b" stroke-dasharray="6 4" stroke-width="1.5"/>' % (L, L + pw, Y(tg), Y(tg)))
            out.append('<text x="%d" y="%.1f" text-anchor="end" fill="#c0392b" font-size="11"%s>%s</text>' % (L + pw - 4, Y(tg) - 4, ' stroke="#ffffff" stroke-width="3" paint-order="stroke"' if callouts else '', LB['target'] % dz(('%.1f' % tg) if key == 'OM' else '%.0f' % tg)))
        pts = [(0, s0)]
        if key == 'OM':
            pts = list(run.trace)  # monthly decay steps included
        else:
            for r in rows:
                m = mon(r['t'])
                pts.append((m, pts[-1][1]))
                pts.append((m, r[key]))
        pts.append((months, pts[-1][1]))
        out.append('<polyline fill="none" stroke="#1f4e79" stroke-width="2" points="%s"/>' % ' '.join('%.1f,%.1f' % (X(m), Y(v)) for m, v in pts))
        for r in rows:
            m = mon(r['t'])
            if r['kind'] == 'h':
                out.append('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="#b9770e"/>' % (X(m) - 4, Y(r[key]) - 8, X(m) + 4, Y(r[key]) - 8, X(m), Y(r[key]) - 1))
            elif abs(r['d' + key]) > 1e-9:
                out.append('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="#1e8449"/>' % (X(m) - 4, Y(r[key]) + 8, X(m) + 4, Y(r[key]) + 8, X(m), Y(r[key]) + 1))
        placed = []
        for ci, c in enumerate(callouts):
            if c['panel'] != key:
                continue
            bx, by = X(c['m']), Y(c['v'])
            while any(abs(bx - ox) < 21 and abs(by - oy) < 21 for ox, oy in placed + badges_all(key)):
                bx += 22
            placed.append((bx, by))
            if abs(bx - X(c['m'])) > 1:
                out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#444" stroke-width="1"/>' % (X(c['m']), by, bx, by))
            out.append('<circle cx="%.1f" cy="%.1f" r="9.5" fill="#fff8d6" stroke="#222" stroke-width="1.6"/>' % (bx, by))
            out.append('<text x="%.1f" y="%.1f" text-anchor="middle" font-size="12" font-weight="700" fill="#111">%d</text>' % (bx, by + 4.3, ci + 1))
    base = top0 + 4 * (ph + gap) - gap + 16
    for y in range(0, int(months // 12) + 1):
        out.append('<line x1="%.1f" x2="%.1f" y1="%d" y2="%d" stroke="#888"/>' % (X(y * 12), X(y * 12), base - 8, base - 2))
        if y < months / 12:
            out.append('<text x="%.1f" y="%d" fill="#333">%s</text>' % (X(y * 12) + 4, base + 8, LB['year'] % (y + 1)))
    ky = base + 40
    for ci, lines in enumerate(key_lines):
        out.append('<circle cx="%d" cy="%.1f" r="9.5" fill="#fff8d6" stroke="#222" stroke-width="1.6"/>' % (L + 10, ky - 4))
        out.append('<text x="%d" y="%.1f" text-anchor="middle" font-size="12" font-weight="700" fill="#111">%d</text>' % (L + 10, ky + 0.3, ci + 1))
        for li, ln in enumerate(lines):
            out.append('<text x="%d" y="%d" font-size="13" fill="#1a1a1a">%s</text>' % (L + 26, ky + li * 17, escape(ln)))
        ky += len(lines) * 17 + 7
    ly = H - 8
    out.append('<polygon points="%d,%d %d,%d %d,%d" fill="#1e8449"/><text x="%d" y="%d" fill="#333">%s</text>' % (L, ly - 8, L + 8, ly - 8, L + 4, ly - 1, L + 14, ly, LB['applied']))
    out.append('<polygon points="%d,%d %d,%d %d,%d" fill="#b9770e"/><text x="%d" y="%d" fill="#333">%s</text>' % (L + 100, ly - 8, L + 108, ly - 8, L + 104, ly - 1, L + 114, ly, LB['harvest']))
    out.append('<line x1="%d" x2="%d" y1="%d" y2="%d" stroke="#c0392b" stroke-dasharray="6 4" stroke-width="1.5"/><text x="%d" y="%d" fill="#333">%s</text>' % (L + 240, L + 266, ly - 4, ly - 4, L + 272, ly, LB['soil']))
    out.append('</svg>')
    open(os.path.join(outdir or OUT, fn), 'w', encoding='utf-8').write('\n'.join(out))


if __name__ == '__main__':
    res = {}
    cfgs = (
        ('A', A, 5, [(0, 3.9, 'zöldrozs'), (4, 8.65, 'silókukorica'), (9.2, 16.3, 'rozsos bükköny'), (16.5, 21.5, 'szemes kuk.'), (21.7, 30.1, 'őszi árpa'), (31.6, 42.3, 'repce'), (44.3, 51.9, 'zöldrozs'), (52, 56.65, 'silókuk.')], 'A. forgó: zöldrozs + silókukorica / rozsos bükköny + szemes kukorica / őszi árpa / repce'),
        ('B', B, 4, [(2.5, 9.4, 'szemes kukorica'), (12.0, 19.3, 'őszi búza'), (21.2, 29.5, 'napraforgó'), (33.0, 42.0, 'őszi árpa')], 'B. forgó: kukorica / búza / napraforgó / árpa (műtrágya, szalma lehordva)'),
        ('C', C, 4, [(0, 8.8, 'silókukorica'), (9.1, 18.2, 'őszi búza'), (23.0, 31.7, 'lóbab'), (33.5, 42.0, 'őszi árpa')], 'C. forgó: állattartó farm, szerves trágya silókukorica után, szalma lehordva alomnak'),
        ('D', D, 6, [(0, 12, 'zöldrozs + silókukorica'), (12, 24, 'bükköny + silókukorica'), (24, 36, 'egész növényes árpa'), (36, 48, 'zöldrozs + silókukorica'), (48, 60, 'bükköny + silókukorica'), (60, 72, 'egész növényes árpa')], 'D. forgó: tehenészet, silóforgó, trágya minden silókukorica után (N-célhoz méretezve)'),
        ('E', E, 8, [(0, 12, 'zöldrozs + silókuk.'), (12, 24, 'bükköny + silókuk.'), (24, 36, 'egész növényes árpa'), (36, 48, 'lucerna (3 kaszálás)'), (48, 60, 'zöldrozs + silókuk.'), (60, 72, 'bükköny + silókuk.'), (72, 84, 'egész növényes árpa'), (84, 96, 'lucerna (3 kaszálás)')], 'E. forgó: tehenészet, trágya silókukorica után, lucerna-szünettel'),
    )
    for nm, e, yrs, bands, title in cfgs:
        rows = run(e)
        svg(rows, bands, yrs * 12, title, 'rotation_%s.svg' % nm)
        res[nm] = (md(rows), summary(rows, yrs))
    import sys
    sys.stdout.reconfigure(encoding='utf-8')  # the console default (cp1252) cannot print the Hungarian letters
    outdir = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else None
    if '--wiki' in sys.argv:  # wiki charts (EN + HU, with callouts) and the tables inside docs/wiki/*.md
        import wiki_rot
        wiki_rot.main(cfgs)
        sys.exit(0)
    for nm in res:
        if outdir:
            open(os.path.join(outdir, 'rot_%s_ops.md' % nm), 'w', encoding='utf-8').write(res[nm][0])
            open(os.path.join(outdir, 'rot_%s_sum.md' % nm), 'w', encoding='utf-8').write(res[nm][1])
        else:
            print('=== ', nm)
            print(res[nm][0])
            print(res[nm][1])
