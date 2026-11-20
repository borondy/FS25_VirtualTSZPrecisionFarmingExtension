"""Wiki chart: nitrogen, phosphorus and potassium of the rotations A-E over their game years, EN and HU, in the look of om_chart.py.

Three panels (N, P, K) with the crop bands on top, numbered highlights with a key under the chart. The organic matter panel of the older
rotation-X charts is not drawn here: om_chart.py shows it (with yield potential and every application).
Writes docs/wiki/images/npk-rotation-<a..e>-<en|hu>.svg.

    python npk_chart.py d
"""
import os
import sys
import textwrap
from xml.sax.saxutils import escape

import chartkit as ck
from chartkit import COL, L, PW, num, mon
import om_chart
import wiki_rot
from rot import run, TG, START as SIM_START

OUT = om_chart.OUT
START = dict(N=40.0, P=SIM_START[0], K=SIM_START[1])  # absolute content = baseline + distance (the maps store the distance)
# crop bands per rotation, Hungarian readme spelling (wiki_rot.band_name maps them to the wiki names): (from month, to month, label)
BANDS = {
    'a': [(0, 3.9, 'zöldrozs'), (4, 8.65, 'silókukorica'), (9.2, 16.3, 'rozsos bükköny'), (16.5, 21.5, 'szemes kuk.'), (21.7, 30.1, 'őszi árpa'), (31.6, 42.3, 'repce'),
          (44.3, 51.9, 'zöldrozs'), (52, 56.65, 'silókuk.')],
    'b': [(2.5, 9.4, 'szemes kukorica'), (12.0, 19.3, 'őszi búza'), (21.2, 29.5, 'napraforgó'), (33.0, 42.0, 'őszi árpa')],
    'c': [(0, 8.8, 'silókukorica'), (9.1, 18.2, 'őszi búza'), (23.0, 31.7, 'lóbab'), (33.5, 42.0, 'őszi árpa')],
    'd': [(0, 12, 'zöldrozs + silókukorica'), (12, 24, 'bükköny + silókukorica'), (24, 36, 'egész növényes árpa'), (36, 48, 'zöldrozs + silókukorica'),
          (48, 60, 'bükköny + silókukorica'), (60, 72, 'egész növényes árpa')],
    'e': [(0, 12, 'zöldrozs + silókuk.'), (12, 24, 'bükköny + silókuk.'), (24, 36, 'egész növényes árpa'), (36, 48, 'lucerna (3 kaszálás)'), (48, 60, 'zöldrozs + silókuk.'),
          (60, 72, 'bükköny + silókuk.'), (72, 84, 'egész növényes árpa'), (84, 96, 'lucerna (3 kaszálás)')],
}
YEARS = {k: v[1] for k, v in om_chart.ROTATIONS.items()}
TEXT = {
    'en': dict(title="N, P and K on %s", panels=dict(N="Nitrogen, kg/ha", P="Phosphorus (P₂O₅), kg/ha", K="Potassium (K₂O), kg/ha"), target="target",
               applied="application", harvest="harvest / cut", xlabel="game year"),
    'hu': dict(title="N, P és K %s", panels=dict(N="Nitrogén, kg/ha", P="Foszfor (P₂O₅), kg/ha", K="Kálium (K₂O), kg/ha"), target="célérték",
               applied="kijuttatás", harvest="aratás / kaszálás", xlabel="játékév"),
}


def nice_ticks(lo, hi):
    """Round tick values (step 1, 2, 2.5, 5 x 10^n) inside [lo, hi], about 4-6 of them."""
    raw = (hi - lo) / 4.0
    mag = 10 ** (len(str(int(raw))) - 1) if raw >= 1 else 1
    step = min((m * mag for m in (1, 2, 2.5, 5, 10) if m * mag >= raw), default=raw)
    v = (int(lo // step) + 1) * step if lo % step else lo
    out = []
    while v <= hi + 1e-9:
        out.append(v)
        v += step
    return out


def build(lang, key):
    T, OT = TEXT[lang], om_chart.TEXT[lang]
    dec = OT['dec']
    nm = key.upper()
    FOOT = OT['foot'].split('. ')[-1]  # only the simulation disclaimer, the timeScale note is about OM
    events, years = om_chart.ROTATIONS[key]
    rows = run(events)
    co = [c for c in wiki_rot.callouts_for(nm, lang) if c['kind'] != 'omyear']  # the OM highlight lives in the OM chart
    run(events)  # callouts_for() runs the other rotations too
    for c in co:
        if c['panel'] == 'OM':
            c['panel'] = 'K'  # the end-of-rotation highlight (P, K and OM values) sits on the last panel
            c['v'] = rows[-1]['K']
    months = years * 12
    X = ck.X_of(months)

    # key under the chart
    keylines = [textwrap.wrap(c['text'], 118) for c in co]
    key_h = sum(len(k) * 21 + 10 for k in keylines)
    PH, GAP = 180, 56
    BANDY = 116
    TOP0 = BANDY + 74
    panels = ['N', 'P', 'K']
    bottom = TOP0 + 3 * PH + 2 * GAP
    H = int(bottom + 80 + key_h + 20 + 40 + 24 * ck.footer_lines(FOOT) + 10)  # key, legend, footer
    o = ck.open_svg(H)
    ck.header(o, T['title'] % OT['names'][key], OT['sub'] % (nm, OT['desc'][key]))
    ck.year_bands(o, X, years, BANDY, bottom, bottom + 30, T['xlabel'])

    # crop bands row (labels wrapped to the band width)
    for i, (a, b, name) in enumerate(BANDS[key]):
        label = wiki_rot.band_name(name, lang)
        bw = X(b) - X(a)
        o.append('<rect x="%.1f" y="%d" width="%.1f" height="44" rx="6" fill="%s" stroke="%s" stroke-width="1"/>' % (X(a), BANDY, bw, ['#cfe3f7', '#fbe0b3'][i % 2], ck.BOXLINE))
        per = max(6, int((bw - 8) / 7.4))
        parts = label.split(' + ') if len(label) > per and ' + ' in label else textwrap.wrap(label, per, break_long_words=False)
        parts = parts[:2]
        fs = max(10, min(15, int((bw - 6) / (0.52 * max(len(p) for p in parts)))))  # shrink so the longest word fits the band
        for li, part in enumerate(parts):
            yy = BANDY + (28 if len(parts) == 1 else 19 + li * 16)
            o.append('<text x="%.1f" y="%d" font-size="%d" fill="%s" text-anchor="middle">%s</text>' % ((X(a) + X(b)) / 2, yy, fs, ck.INK, part))

    placed_all = []
    for pi, pk in enumerate(panels):
        top = TOP0 + pi * (PH + GAP)
        vals = [START[pk]] + [r[pk] for r in rows]
        tg = TG.get(pk)
        lo, hi = min(vals + ([tg] if tg else [])), max(vals + ([tg] if tg else []))
        pad = (hi - lo) * 0.18 or 1
        lo, hi = lo - pad, hi + pad
        if pk == 'N':
            lo = max(lo, 0)
        ticks = nice_ticks(lo, hi)

        def Y(v, top=top, lo=lo, hi=hi):
            return top + PH - (v - lo) / (hi - lo) * PH

        o.append('<text x="56" y="%d" font-size="19" font-weight="700" fill="%s">%s</text>' % (top - 14, ck.INK, T['panels'][pk]))
        for v in ticks:
            ck.hline(o, Y(v))
            ck.tick(o, Y(v), num(v, dec, 0), 18)
        ck.hline(o, top + PH, ck.AXIS, 2)
        if tg:
            ck.target_line(o, Y(tg), T['target'], num(tg, dec, 0))
        pts = [(0, START[pk])]
        for r in rows:
            m = mon(r['t'])
            pts.append((m, pts[-1][1]))
            pts.append((m, r[pk]))
        pts.append((months, pts[-1][1]))
        o.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="4" stroke-linejoin="round" stroke-linecap="round"/>' % (' '.join('%.1f,%.1f' % (X(m), Y(v)) for m, v in pts), COL[pk]))
        for r in rows:
            m = mon(r['t'])
            if r['kind'] == 'h':
                ck.ring(o, X(m), Y(r[pk]), COL[pk])
            elif abs(r['d' + pk]) > 1e-9:
                ck.dot(o, X(m), Y(r[pk]), COL[pk])
        # numbered highlights of this panel
        placed = []
        for ci, c in enumerate(co):
            if c['panel'] != pk:
                continue
            bx, by = X(c['m']), Y(c['v'])
            while any(abs(bx - ox) < 30 and abs(by - oy) < 30 for ox, oy in placed):
                bx += 32
            placed.append((bx, by))
            if abs(bx - X(c['m'])) > 1:
                o.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#444" stroke-width="1.2"/>' % (X(c['m']), by, bx, by))
            o.append('<circle cx="%.1f" cy="%.1f" r="13" fill="#fff8d6" stroke="#222" stroke-width="1.8"/>' % (bx, by))
            o.append('<text x="%.1f" y="%.1f" text-anchor="middle" font-size="16" font-weight="700" fill="#111">%d</text>' % (bx, by + 5.5, ci + 1))

    # key
    ky = bottom + 80
    for ci, lines in enumerate(keylines):
        o.append('<circle cx="%d" cy="%.1f" r="13" fill="#fff8d6" stroke="#222" stroke-width="1.8"/>' % (L - 120, ky - 5))
        o.append('<text x="%d" y="%.1f" text-anchor="middle" font-size="16" font-weight="700" fill="#111">%d</text>' % (L - 120, ky + 0.5, ci + 1))
        for li, ln in enumerate(lines):
            o.append('<text x="%d" y="%.1f" font-size="17" fill="%s">%s</text>' % (L - 96, ky + li * 21, ck.INK, escape(ln)))
        ky += len(lines) * 21 + 10
    # legend
    ly = ky + 20
    ck.dot(o, 70, ly - 5, ck.MUTED)
    o.append('<text x="84" y="%.1f" font-size="17" fill="%s">%s</text>' % (ly, ck.MUTED, T['applied']))
    ck.ring(o, 260, ly - 5, ck.MUTED, 6)
    o.append('<text x="276" y="%.1f" font-size="17" fill="%s">%s</text>' % (ly, ck.MUTED, T['harvest']))
    ck.footer(o, FOOT, ly + 40)
    o.append('</svg>')
    return '\n'.join(o)


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    for key in (sys.argv[1:] or sorted(om_chart.ROTATIONS)):
        for lang in ('hu', 'en'):
            with open(os.path.join(OUT, 'npk-rotation-%s-%s.svg' % (key, lang)), 'w', encoding='utf-8', newline='\n') as fh:
                fh.write(build(lang, key))
        print('written', key)
