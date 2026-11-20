"""Wiki output of the rotation simulation: charts with numbered callouts (EN + HU), the D-vs-E comparison chart, and the tables that
sit inside docs/wiki/EN-06-Crop-Rotations.md and docs/wiki/HU-06-Vetesforgok.md.

    python tools/rotation_sim/gen.py --wiki

Everything is computed from sim.py / rot.py (the config copy that check_config.py keeps in sync). The two pages carry marker pairs

    <!-- gen:A-ops -->  ...  <!-- /gen:A-ops -->        (ids: A..E with -ops / -sum, and omtable)

and this script rewrites what is between them, so the numbers in the pages are never typed by hand.
Writes docs/wiki/images/rotation-<a..e>-<en|hu>.svg and rotation-d-vs-e-<en|hu>.svg.
"""
import os
import re
import sys
import json
import textwrap
from xml.sax.saxutils import escape

import gen  # noqa: F401
import npk_chart
import om_chart
from rot import *  # noqa: F401,F403  (run, A..E, TG, TS, ... from sim)
import om_tables

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
IMG = os.path.join(ROOT, "docs", "wiki", "images")
PAGES = {'en': os.path.join(ROOT, "docs", "wiki", "EN-06-Crop-Rotations.md"), 'hu': os.path.join(ROOT, "docs", "wiki", "HU-06-Vetesforgok.md")}

# names as the player sees them (Szalok modDesc l10n, base game l10n, mod fill types: tools/generate_products.py)
CROPS = {
    'hu': {'GREENRYE': 'zöldrozs', 'SILAGEMAIZE': 'silókukorica', 'VETCHRYE': 'rozsos bükköny', 'MAIZE': 'szemes kukorica', 'WINTERBARLEY': 'őszi árpa', 'WINTERWHEAT': 'őszi búza',
           'CANOLA': 'repce', 'SUNFLOWER': 'napraforgó', 'FABABEAN': 'lóbab', 'ALFALFA': 'lucerna'},
    'en': {'GREENRYE': 'green rye', 'SILAGEMAIZE': 'silage maize', 'VETCHRYE': 'vetch rye', 'MAIZE': 'corn', 'WINTERBARLEY': 'winter barley', 'WINTERWHEAT': 'winter wheat',
           'CANOLA': 'canola', 'SUNFLOWER': 'sunflowers', 'FABABEAN': 'faba beans', 'ALFALFA': 'alfalfa'},
}
PRODUCTS = {
    'hu': {'PETISO27': 'Pétisó 27 (27-0-0)', 'KARBAMID46': 'Karbamid (46-0-0)', 'MAP11_52': 'MAP (11-52-0)', 'TSP46': 'Tripleszuperfoszfát (0-46-0)', 'SSP18': 'Szuperfoszfát (0-18-0)',
           'KALISO60': 'Kálisó 60 (0-0-60)', 'PATENTKALI': 'Patentkali (0-0-30)', 'NPK15_15_15': 'NPK (15-15-15)', 'NPK8_24_24': 'NPK (8-24-24)', 'NITROSOL30': 'Nitrosol UAN (30-0-0)',
           'MANURE': 'Trágya', 'LIQUIDMANURE': 'Hígtrágya', 'DIGESTATE': 'Fermentált'},
    'en': {'PETISO27': 'CAN 27 (27-0-0)', 'KARBAMID46': 'Urea (46-0-0)', 'MAP11_52': 'MAP (11-52-0)', 'TSP46': 'Triple superphosphate (0-46-0)', 'SSP18': 'Single superphosphate (0-18-0)',
           'KALISO60': 'Potassium chloride 60 MOP (0-0-60)', 'PATENTKALI': 'Patentkali (0-0-30)', 'NPK15_15_15': 'NPK (15-15-15)', 'NPK8_24_24': 'NPK (8-24-24)', 'NITROSOL30': 'Nitrosol UAN (30-0-0)',
           'MANURE': 'Manure', 'LIQUIDMANURE': 'Slurry', 'DIGESTATE': 'Digestate'},
}
MONTHS = {'hu': ['jan.', 'febr.', 'márc.', 'ápr.', 'máj.', 'jún.', 'júl.', 'aug.', 'szept.', 'okt.', 'nov.', 'dec.'],
          'en': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']}
# band labels of the readme charts (Hungarian readme spelling) -> wiki spelling
BAND_ALIAS = {'silókuk.': 'silókukorica', 'szemes kuk.': 'szemes kukorica', 'bükköny': 'rozsos bükköny'}
BAND_KEY = {'zöldrozs': 'GREENRYE', 'silókukorica': 'SILAGEMAIZE', 'rozsos bükköny': 'VETCHRYE', 'szemes kukorica': 'MAIZE', 'őszi árpa': 'WINTERBARLEY', 'őszi búza': 'WINTERWHEAT',
            'repce': 'CANOLA', 'napraforgó': 'SUNFLOWER', 'lóbab': 'FABABEAN'}
WHOLE = {'hu': 'egész növényes árpa', 'en': 'whole-crop barley'}
ALF3 = {'hu': 'lucerna (3 kaszálás)', 'en': 'alfalfa (3 cuts)'}
TITLES = {
    'A': {'hu': 'A. forgó: állattartó silóforgó (zöldrozs + silókukorica / rozsos bükköny + kukorica / őszi árpa / repce)',
          'en': 'A. Livestock silage rotation (green rye + silage maize / vetch rye + corn / winter barley / canola)'},
    'B': {'hu': 'B. forgó: állat nélküli gazdaság (kukorica / őszi búza / napraforgó / őszi árpa, műtrágya, szalma lehordva)',
          'en': 'B. Arable farm without livestock (corn / winter wheat / sunflowers / winter barley, fertiliser, straw baled)'},
    'C': {'hu': 'C. forgó: tejelő gazdaság (silókukorica / őszi búza / lóbab / őszi árpa, trágya a siló után)',
          'en': 'C. Dairy farm (silage maize / winter wheat / faba beans / winter barley, manure after the silage)'},
    'D': {'hu': 'D. forgó: tehenészet, silóforgó, trágya minden silókukorica után (az N-célhoz méretezve)',
          'en': 'D. Dairy silage rotation, manure after every silage maize (sized to the nitrogen target)'},
    'E': {'hu': 'E. forgó: tehenészet, trágya a silókukorica után, lucernás szünettel',
          'en': 'E. Dairy rotation with an alfalfa break, manure after the silage maize'},
}
SLUG = {'A': 'a', 'B': 'b', 'C': 'c', 'D': 'd', 'E': 'e'}
EV = {'A': A, 'B': B, 'C': C, 'D': D, 'E': E}
MINUS = '−'


def band_name(name, lang):
    """Readme band label -> wiki label in lang (game crop names)."""
    if name == 'egész növényes árpa':
        return WHOLE[lang]
    if name.startswith('lucerna'):
        return ALF3[lang]
    out = []
    for part in name.split(' + '):
        part = BAND_ALIAS.get(part, part)
        out.append(CROPS[lang][BAND_KEY[part]])
    return ' + '.join(out)


def num(v, lang, nd=0, sign=False, minus=True):
    s = ('%+.' + str(nd) + 'f') % v if sign else ('%.' + str(nd) + 'f') % v
    if minus:
        s = s.replace('-', MINUS)
    return s.replace('.', ',') if lang == 'hu' else s


def mon(t):
    return (t[0] - 1) * 12 + (t[1] - 1) + t[2] / 31.0


def year_net(rows, y):
    rs = [r for r in rows if r['t'][0] == y]
    return sum(r['dOM'] + r['dDecay'] for r in rs)  # same definition as the yearly table (gen.summary)


# ----------------------------------------------------------------------------------------------------------------------------- callouts

def art(n):
    return 'az' if n in (1, 5) else 'a'


def why_low(r, lang):
    """Why the yield factor of harvest r is below 1: the smallest of the four factors, with the numbers from the simulation."""
    fp, fk, fo, tot, fn = r['y']
    c = CROP[r['name']]
    cand = [('K', fk), ('P', fp), ('OM', fo), ('N', fn)]
    which = min(cand, key=lambda x: x[1])[0]
    crop = CROPS[lang][r['name']]
    if which == 'K':
        pre = r['K'] - r['dK']
        tgt = crop_target_abs('K', c[2])
        if lang == 'hu':
            return 'a K₂O (%s kg/ha) a növény K-célja (%s) alatt volt' % (num(pre, lang), num(tgt, lang)), 'K'
        return 'soil K₂O (%s kg/ha) was below the K target of %s (%s)' % (num(pre, lang), crop, num(tgt, lang)), 'K'
    if which == 'P':
        pre = r['P'] - r['dP']
        if lang == 'hu':
            return 'a P₂O₅ (%s kg/ha) a célérték (%s) alatt volt' % (num(pre, lang), num(TG['P'], lang)), 'P'
        return 'soil P₂O₅ (%s kg/ha) was below the target (%s)' % (num(pre, lang), num(TG['P'], lang)), 'P'
    if which == 'OM':
        pre = r['OM'] - r['dOM']
        if lang == 'hu':
            return 'a szerves anyag (%s %%) a célérték (%s %%) alatt volt' % (num(pre, lang, 2), num(TG['OM'], lang, 1)), 'OM'
        return 'organic matter (%s %%) was below the target (%s %%)' % (num(pre, lang, 2), num(TG['OM'], lang, 1)), 'OM'
    d = r['nshort']
    nt = NCROP[r['name']][0]
    if lang == 'hu':
        return 'az aratáskori nitrogén eltérése a növény N-céljától (%s): %s kg/ha' % (num(nt, lang), num(d, lang, 0, True)), 'N'
    return 'nitrogen was %s kg/ha %s the N target of %s (%s)' % (num(abs(d), lang), 'above' if d > 0 else 'below', crop, num(nt, lang)), 'N'


def callouts_for(nm, lang):
    rows = run(EV[nm])
    years = max(r['t'][0] for r in rows)
    out = []
    # 1 lowest yield
    hs = [r for r in rows if r['kind'] == 'h']
    low = min(hs, key=lambda r: r['y'][3])  # first of equal minima
    if low['y'][3] >= 0.98:
        # every harvest is at 0.98 or better, so "lowest yield" would say nothing: show the biggest K2O removal instead
        kr = max(hs, key=lambda r: -r['dK'])
        crop = CROPS[lang][kr['name']]
        yr = kr['t'][0]
        if lang == 'hu':
            txt = 'A legnagyobb K₂O-elvonás: %s kg/ha (%s, %d. év). A legrosszabb hozamtényező az egész forgóban %s.' % (num(-kr['dK'], lang), crop, yr, num(low['y'][3], lang, 2))
        else:
            txt = 'Biggest K₂O removal: %s kg/ha (%s, year %d). The worst yield factor in the whole rotation is %s.' % (num(-kr['dK'], lang), crop, yr, num(low['y'][3], lang, 2))
        out.append(dict(panel='K', m=mon(kr['t']), v=kr['K'], text=txt, kind='kremoval', val=-kr['dK'], year=yr, crop=kr['name']))
    else:
        why, panel = why_low(low, lang)
        yr = low['t'][0]
        crop = CROPS[lang][low['name']]
        if lang == 'hu':
            txt = 'Legalacsonyabb hozamtényező: %s (%s, %d. év): %s.' % (num(low['y'][3], lang, 2), crop, yr, why)
        else:
            txt = 'Lowest yield factor: %s (%s, year %d): %s.' % (num(low['y'][3], lang, 2), crop, yr, why)
        out.append(dict(panel=panel, m=mon(low['t']), v=low[panel], text=txt, kind='lowyield', val=low['y'][3], year=yr, crop=low['name']))

    # 2 biggest OM change of a year (net, with decomposition)
    nets = {y: year_net(rows, y) for y in range(1, years + 1)}
    by = max(nets, key=lambda y: abs(nets[y]))
    last = [r for r in rows if r['t'][0] == by][-1]
    if lang == 'hu':
        txt = 'Legnagyobb éves szervesanyag-változás: %s %%-pont %s %d. évben (a betakarítások, a trágya és a lebomlás együtt).' % (num(nets[by], lang, 2, True), art(by), by)
    else:
        txt = 'Biggest yearly organic matter change: %s percentage points in year %d (harvests, manure and decomposition together).' % (num(nets[by], lang, 2, True), by)
    out.append(dict(panel='OM', m=mon(last['t']), v=last['OM'], text=txt, kind='omyear', val=nets[by], year=by))
    # 3 the P or K extreme that is farthest from its target (relative)
    best = None
    for key in ('P', 'K'):
        for r in rows:
            dev = abs(r[key] - TG[key]) / TG[key]
            if best is None or dev > best[0]:
                best = (dev, key, r)
    dev, key, r = best
    sub = 'P₂O₅' if key == 'P' else 'K₂O'
    hi = r[key] > TG[key]
    if lang == 'hu':
        txt = 'A %s %s: %s kg/ha %s %d. évben (célérték: %s)' % (sub, 'csúcsa' if hi else 'mélypontja', num(r[key], lang), art(r['t'][0]), r['t'][0], num(TG[key], lang))
        txt += '. A szimuláció nem számol K-kimosódással, a játékban a célérték fölötti K lassan csökken.' if hi and key == 'K' else '.'
    else:
        txt = '%s %s: %s kg/ha in year %d (target: %s)' % (sub, 'peak' if hi else 'low point', num(r[key], lang), r['t'][0], num(TG[key], lang))
        txt += '. The simulation has no K leaching; in the game, K above the target slowly falls.' if hi and key == 'K' else '.'
    out.append(dict(panel=key, m=mon(r['t']), v=r[key], text=txt, kind='pk', key=key, val=r[key], year=r['t'][0], hi=hi))
    # 4 end of the rotation
    e = rows[-1]
    if lang == 'hu':
        txt = 'A forgó végén (%d. év): P₂O₅ %s, K₂O %s kg/ha, szerves anyag %s %% (kezdet: %s, %s, %s %%).' % (
            years, num(e['P'], lang), num(e['K'], lang), num(e['OM'], lang, 2), num(START[0], lang), num(START[1], lang), num(START[2], lang, 2))
    else:
        txt = 'End of the rotation (year %d): P₂O₅ %s, K₂O %s kg/ha, organic matter %s %% (start: %s, %s, %s %%).' % (
            years, num(e['P'], lang), num(e['K'], lang), num(e['OM'], lang, 2), num(START[0], lang), num(START[1], lang), num(START[2], lang, 2))
    out.append(dict(panel='OM', m=mon(e['t']), v=e['OM'], text=txt, kind='end', P=e['P'], K=e['K'], OM=e['OM'], year=years))
    return out


# ----------------------------------------------------------------------------------------------------------------------------- D vs E chart

def dve_svg(lang):
    rowsD = run(D)
    trD = list(run.trace)
    rowsE = run(E)
    trE = list(run.trace)
    omE6 = [r for r in rowsE if r['t'][0] == 6][-1]['OM']
    netE4 = year_net(rowsE, 4)
    endD, endE = rowsD[-1]['OM'], rowsE[-1]['OM']
    W, H = 1100, 640
    L, R, TOP, BOT = 84, 250, 150, 520
    pw, ph = W - L - R, BOT - TOP
    ymin, ymax = 2.7, 3.45
    months = 96

    def X(m):
        return L + pw * m / months

    def Y(v):
        return BOT - (v - ymin) / (ymax - ymin) * ph

    T = {
        'en': dict(title='Same dairy farm, with and without the alfalfa break', sub='Organic matter on loam, simulated with the mod\'s config (rotations D and E)',
                   target='target %s %%', year='game year', y='organic matter, %', d='D: no alfalfa', e='E: alfalfa break every 4th year',
                   alf=['alfalfa year:', '%s percentage points (net)'], after6='after 6 game years', endd='D: %s %%', ende6='E: %s %%', ende=['E: %s %%', 'after 8 game years'],
                   foot='OM changes are 6 times the real-world annual value per game year (timeScale 6); on the server 6 game years are about 1 real year. Simulation with typical yields, not an in-game measurement.'),
        'hu': dict(title='Ugyanaz a tehenészet lucerna-szünettel és anélkül', sub='Szerves anyag vályogon, a mod konfigurációjával szimulálva (D és E forgó)',
                   target='célérték %s %%', year='játékév', y='szerves anyag, %', d='D: lucerna nélkül', e='E: lucerna-szünet minden 4. évben',
                   alf=['a lucerna éve:', '%s %%-pont (nettó)'], after6='6 játékév után', endd='D: %s %%', ende6='E: %s %%', ende=['E: %s %%', '8 játékév után'],
                   foot='Az OM-változás játékévenként a valós éves érték 6-szorosa (timeScale 6); a szerveren 6 játékév kb. 1 valós év. Szimuláció tipikus hozamokkal, nem játékbeli mérés.'),
    }[lang]
    f = 'font-family="Segoe UI, Roboto, Helvetica, Arial, sans-serif"'
    o = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d" %s>' % (W, H, W, H, f),
         '<rect x="0" y="0" width="%d" height="%d" rx="18" ry="18" fill="#ffffff" stroke="#d8d2c8" stroke-width="2"/>' % (W, H),
         '<text x="40" y="52" font-size="30" font-weight="700" fill="#2b2b2b">%s</text>' % T['title'],
         '<text x="40" y="84" font-size="21" fill="#555555">%s</text>' % T['sub']]
    for y in range(8):
        if y % 2 == 1:
            o.append('<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="#f6f3ee"/>' % (X(y * 12), TOP, X(12) - X(0), ph))
    for a in (36, 84):  # alfalfa years of E
        o.append('<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="#dff1e3" opacity="0.9"/>' % (X(a), TOP, X(12) - X(0), ph))
    for y in range(8):
        o.append('<text x="%.1f" y="%d" font-size="20" fill="#555555" text-anchor="middle">%d</text>' % (X(y * 12 + 6), BOT + 30, y + 1))
    o.append('<text x="%.1f" y="%d" font-size="19" fill="#777777" text-anchor="middle">%s</text>' % (X(48), BOT + 58, T['year']))
    for v in (2.8, 2.9, 3.0, 3.1, 3.3, 3.4):
        o.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#e3dfd8" stroke-width="1.5"/>' % (L, L + pw, Y(v), Y(v)))
    for v in (2.8, 3.0, 3.2, 3.4):
        o.append('<text x="%d" y="%.1f" font-size="19" fill="#555555" text-anchor="end">%s</text>' % (L - 10, Y(v) + 6, num(v, lang, 1)))
    o.append('<text transform="translate(26,%.1f) rotate(-90)" font-size="19" fill="#777777" text-anchor="middle">%s</text>' % ((TOP + BOT) / 2, T['y']))
    o.append('<line x1="%d" x2="%d" y1="%d" y2="%d" stroke="#999999" stroke-width="2"/>' % (L, L + pw, BOT, BOT))
    o.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#8a8a8a" stroke-width="2" stroke-dasharray="9 7"/>' % (L, L + pw, Y(TG['OM']), Y(TG['OM'])))
    o.append('<text x="%d" y="%.1f" font-size="19" fill="#666666" text-anchor="end">%s</text>' % (L + 300, Y(TG['OM']) - 9, T['target'] % num(TG['OM'], lang, 1)))
    cD, cE = '#a8641a', '#1f7a4d'
    o.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="4" stroke-linejoin="round" stroke-linecap="round"/>' % (' '.join('%.1f,%.1f' % (X(m), Y(v)) for m, v in trE), cE))
    o.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="4" stroke-linejoin="round" stroke-linecap="round"/>' % (' '.join('%.1f,%.1f' % (X(m), Y(v)) for m, v in trD), cD))

    def dot(m, v, c):
        o.append('<circle cx="%.1f" cy="%.1f" r="7" fill="#ffffff" stroke="%s" stroke-width="4"/>' % (X(m), Y(v), c))

    def label(x, y, lines, c, colors=None):
        w = max(len(t) for t in lines) * 9.6 + 20
        o.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%d" rx="8" fill="#ffffff" stroke="%s" stroke-width="2"/>' % (x - 10, y - 22, w, 14 + 26 * len(lines), c))
        for i, t in enumerate(lines):
            col = (colors[i] if colors else None) or '#2b2b2b'
            o.append('<text x="%.1f" y="%.1f" font-size="19" font-weight="%s" fill="%s">%s</text>' % (x, y + 26 * i, '700' if i == 0 else '400', col, t))

    mD = mon(rowsD[-1]['t'])
    mE6 = mon([r for r in rowsE if r['t'][0] == 6][-1]['t'])
    mE = mon(rowsE[-1]['t'])
    o.append('<line x1="%.1f" x2="%.1f" y1="%d" y2="%d" stroke="#999999" stroke-width="2" stroke-dasharray="4 6"/>' % (X(72), X(72), TOP, BOT))
    dot(0, 3.25, '#555555')
    dot(mD, endD, cD)
    dot(mE6, omE6, cE)
    dot(mE, endE, cE)
    label(X(72) + 22, Y(3.0), [T['after6'], T['endd'] % num(endD, lang, 2), T['ende6'] % num(omE6, lang, 2)], '#999999', [None, cD, cE])
    label(X(mE) + 20, Y(endE) + 4, [T['ende'][0] % num(endE, lang, 2), T['ende'][1]], cE)
    label(X(36) + 12, TOP + 30, [T['alf'][0], T['alf'][1] % num(netE4, lang, 2, True)], cE)
    # legend
    ly = 118
    o.append('<line x1="%d" x2="%d" y1="%d" y2="%d" stroke="%s" stroke-width="5"/><text x="%d" y="%d" font-size="19" fill="#2b2b2b">%s</text>' % (L + 480, L + 520, ly, ly, cD, L + 530, ly + 6, T['d']))
    o.append('<line x1="%d" x2="%d" y1="%d" y2="%d" stroke="%s" stroke-width="5"/><text x="%d" y="%d" font-size="19" fill="#2b2b2b">%s</text>' % (L + 480, L + 520, ly + 28, ly + 28, cE, L + 530, ly + 34, T['e']))
    o.append('<text x="40" y="%d" font-size="17" fill="#777777">%s</text>' % (H - 26, T['foot']))
    o.append('</svg>')
    return '\n'.join(o), dict(endD=endD, endE=endE, omE6=omE6, netE4=netE4)


# ----------------------------------------------------------------------------------------------------------------------------- tables

HEAD = {
    'hu': ['Idő', 'Művelet', 'ΔN', 'ΔP₂O₅', 'ΔK₂O', 'ΔOM', 'OM lebomlás', 'N talajból', 'N', 'P₂O₅', 'K₂O', 'OM %', 'Hozamtényező'],
    'en': ['Time', 'Operation', 'ΔN', 'ΔP₂O₅', 'ΔK₂O', 'ΔOM', 'OM decomposition', 'N from soil', 'N', 'P₂O₅', 'K₂O', 'OM %', 'Yield factor'],
}
SHEAD = {
    'hu': ['Év', 'N be', 'ebből a talajból', 'N ki', 'P₂O₅ be', 'P₂O₅ ki', 'K₂O be', 'K₂O ki', 'OM nettó', 'ebből lebomlás', 'Év végén N', 'P₂O₅', 'K₂O', 'OM %', 'Legrosszabb hozamtényező'],
    'en': ['Year', 'N in', 'of which from soil', 'N out', 'P₂O₅ in', 'P₂O₅ out', 'K₂O in', 'K₂O out', 'OM net', 'of which decomposition', 'N at year end', 'P₂O₅', 'K₂O', 'OM %', 'Worst yield factor'],
}


def ops_table(rows, lang):
    L = ['| ' + ' | '.join(HEAD[lang]) + ' |', '|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|']
    z = lambda v, nd=0, sign=True: (num(v, lang, nd, sign) if abs(v) >= 0.5 else '·')
    for r in rows:
        t = r['t']
        d = ('%d. év %s %d.' % (t[0], MONTHS[lang][t[1] - 1], t[2])) if lang == 'hu' else ('Y%d %s %d' % (t[0], MONTHS[lang][t[1] - 1], t[2]))
        if r['kind'] == 'sp':
            amt = format(r['amt'], ',').replace(',', ' ' if lang == 'hu' else ',')
            op = '%s %s l/ha' % (PRODUCTS[lang][r['name']], amt)
            dn = num(r['dN'], lang, 0, True) if abs(r['dN']) >= 0.5 else '·'
            y = ''
        else:
            crop = CROPS[lang][r['name']]
            hu = lang == 'hu'
            if r['name'] == 'ALFALFA':
                op = ('**Kaszálás:** ' if hu else '**Cut:** ') + crop
            elif r['forage']:
                op = ('**Aratás:** %s, egész növény (szecskázás / kasza)' if hu else '**Harvest:** %s, whole crop (forage harvesting / mowing)') % crop
            elif r['name'] == 'SILAGEMAIZE':
                op = ('**Szecskázás:** ' if hu else '**Chopping:** ') + crop
            else:
                op = ('**Aratás:** ' if hu else '**Harvest:** ') + crop
                if r['name'] in ('WINTERBARLEY', 'WINTERWHEAT'):
                    op += (', szalma lehordva' if hu else ', straw baled') if not r['chop'] else (', szalma aprítva' if hu else ', straw chopped')
            dn = num(r['dN'], lang, 0, True)
            y = num(r['y'][3], lang, 2)
        dp = z(r['dP'])
        dk = z(r['dK'])
        do = num(r['dOM'], lang, 3, True) if abs(r['dOM']) > 1e-9 else '·'
        dd = num(r['dDecay'], lang, 3, True) if abs(r['dDecay']) > 5e-4 else '·'
        nr = num(r['dNrel'], lang, 0, True) if r['dNrel'] >= 0.5 else '·'
        L.append('| ' + ' | '.join([d, op, dn, dp, dk, do, dd, nr, num(r['N'], lang), num(r['P'], lang), num(r['K'], lang), num(r['OM'], lang, 2), y]) + ' |')
    return '\n'.join(L)


def sum_table(rows, years, lang):
    L = ['| ' + ' | '.join(SHEAD[lang]) + ' |', '|' + '--:|' * len(SHEAD[lang])]
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
        cells = [str(y)] + [num(v, lang) for v in (ni, nrel, no, pi, po, ki, ko)] + [num(om, lang, 3, True), num(dec, lang, 3, True)] + \
                [num(v, lang) for v in (e['N'], e['P'], e['K'])] + [num(e['OM'], lang, 2), num(min(ys) if ys else 1, lang, 2)]
        L.append('| ' + ' | '.join(cells) + ' |')
    return '\n'.join(L)


def om_table(lang):
    maps = om_tables.load()
    ts = float(maps["OM"]["attrs"].get("timeScale", 1))
    head = {'hu': ['Növény', 'Szalma / szár lehordva', 'Aprított szalma', 'Szecskázás / kasza'], 'en': ['Crop', 'Straw / stalks baled', 'Straw chopped', 'Forage harvesting / mowing']}[lang]
    L = ['| ' + ' | '.join(head) + ' |', '|---|--:|--:|--:|']
    for fruit in om_tables.EXAMPLE_CROPS:
        t, c, f = om_tables.om_changes(maps, fruit)
        name = CROPS[lang][fruit]
        name = name[0].upper() + name[1:] + (' (vágásonként)' if fruit == 'ALFALFA' and lang == 'hu' else ' (per cut)' if fruit == 'ALFALFA' else '')
        L.append('| %s | %s | %s | %s |' % ((name,) + tuple(num(v * ts + (1e-9 if v >= 0 else -1e-9), lang, 3, True) if abs(v * ts) >= 0.0005 else num(0, lang, 3) for v in (t, c, f))))
    return '\n'.join(L)


def fill(path, gid, text):
    if not os.path.exists(path):
        return False
    s = open(path, encoding='utf-8').read()
    pat = re.compile(r'(<!-- gen:%s -->).*?(<!-- /gen:%s -->)' % (re.escape(gid), re.escape(gid)), re.S)
    if not pat.search(s):
        print('WARNING: marker gen:%s not found in %s' % (gid, os.path.basename(path)))
        return False
    s = pat.sub(lambda m: m.group(1) + '\n\n' + text + '\n\n' + m.group(2), s)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    return True


def main(cfgs):
    os.makedirs(IMG, exist_ok=True)
    facts = {}
    for nm, e, yrs, bands, _title in cfgs:
        rows = run(e)
        facts[nm] = {}
        for lang in ('hu', 'en'):
            co = callouts_for(nm, lang)
            run(e)  # callouts_for() runs the other rotations too
            # N/P/K chart (rotation-X) and OM chart (om-rotation-X), both in the shared chartkit look
            for fn, svg_text in (('rotation-%s-%s.svg' % (SLUG[nm], lang), npk_chart.build(lang, SLUG[nm])), ('om-rotation-%s-%s.svg' % (SLUG[nm], lang), om_chart.build(lang, SLUG[nm])[0])):
                with open(os.path.join(IMG, fn), 'w', encoding='utf-8', newline='\n') as fh:
                    fh.write(svg_text)
            run(e)
            fill(PAGES[lang], nm + '-ops', ops_table(rows, lang))
            fill(PAGES[lang], nm + '-sum', sum_table(rows, yrs, lang))
            facts[nm][lang] = [{k: (round(v, 4) if isinstance(v, float) else v) for k, v in c.items() if k != 'text'} for c in co] if lang == 'en' else None
            facts[nm]['text_' + lang] = [c['text'] for c in co]
    for lang in ('hu', 'en'):
        svg, vals = dve_svg(lang)
        with open(os.path.join(IMG, 'rotation-d-vs-e-%s.svg' % lang), 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(svg)
        fill(PAGES[lang], 'omtable', om_table(lang))
    facts['dve'] = {k: round(v, 4) for k, v in vals.items()}
    print(json.dumps(facts, ensure_ascii=False, indent=1))
