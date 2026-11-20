# per 1000 l: P2O5, K2O, OM, N kg (PF fertilizerUsage), N is estimate (none any more)
PROD = {
    'MANURE': (1.75, 4.2, 0.0008, 7.0, False), 'LIQUIDMANURE': (1.7, 5.0, 0.00034, 4.0, False), 'DIGESTATE': (3.0, 5.0, 0.00038, 5.5, False),
    'PETISO27': (0, 0, 0, 270, False), 'KARBAMID46': (0, 0, 0, 345, False), 'MAP11_52': (499.2, 0, 0, 105.6, False), 'TSP46': (506, 0, 0, 0, False),
    'SSP18': (189, 0, 0, 0, False), 'KALISO60': (0, 660, 0, 0, False), 'PATENTKALI': (0, 357, 0, 0, False), 'NPK15_15_15': (157.5, 157.5, 0, 157.5, False),
    'NPK8_24_24': (252, 252, 0, 84, False), 'NITROSOL30': (0, 0, 0, 382.5, False),
}
# crop: (P removal, P straw, K removal, K straw, OM removal, OM removalStraw, OM gain, OM strawGain)
CROP = {
    'GREENRYE': (40, 0, 150, 0, 0.01167, 0, 0, 0),
    'SILAGEMAIZE': (65, 0, 190, 0, 0.01167, 0, 0, 0),
    'VETCHRYE': (45, 0, 155, 0, 0.01167, 0, 0, 0),
    'MAIZE': (62, 0, 55, 0, 0.01167, 0, 0.02292, 0),
    'WINTERBARLEY': (56, 15, 42, 120, 0, 0.01123, 0, 0.01123),
    'WINTERWHEAT': (64, 19, 44, 90, 0, 0.01467, 0, 0.01467),
    'CANOLA': (55, 0, 30, 0, 0, 0, 0.01364, 0),
    'SUNFLOWER': (56, 0, 84, 0, 0, 0, 0.01604, 0),
    'FABABEAN': (44, 0, 56, 0, 0, 0, 0.01833, 0),
    'ALFALFA': (20, 0, 93, 0, 0, 0, 0.00944, 0),  # per cut, 3 cuts a year on the server (config gain 0.00944, net +400 Haeq/yr)
}
# forageRemoval (OM) of the cereals: forage harvester header / mower takes crop and straw, no gain (config forageRemoval)
FORAGE_REMOVAL = {}
# Szalok map.xml, soil type 3: (N target, N reduction)
NCROP = {
    'GREENRYE': (100, 100), 'SILAGEMAIZE': (220, 220), 'VETCHRYE': (100, 80), 'MAIZE': (220, 215),
    'WINTERBARLEY': (180, 160), 'WINTERWHEAT': (200, 180), 'CANOLA': (200, 140), 'SUNFLOWER': (160, 140), 'FABABEAN': (60, 20),
    'ALFALFA': (60, 60),  # Szalok map.xml: alfalfa target 60, reduction 60 per cut (PF handles mower steps too)
}
CHOPPED_STRAW_N = 25
# fruit types whose combine harvest can leave chopped straw (+25 kg N, PF NitrogenMap choppedStraw): every crop with a harvest chopperType in the game data or
# the Szalok foliage xml (check_config.py verifies this), cut with a combine with the chopper on (no swath). Forage harvester headers and mowers do not give it:
# GREENRYE, VETCHRYE and SILAGEMAIZE have a chopperType too but are cut with the forage header in the examples (the "forage" flag), so they are not listed.
CHOPPER_N_CROPS = ('WHEAT', 'WINTERWHEAT', 'BARLEY', 'WINTERBARLEY', 'OAT', 'RYE', 'TRITICALE', 'SPELT', 'CANOLA', 'SUNFLOWER', 'MAIZE', 'SOYBEAN', 'FABABEAN', 'FODDERPEA', 'MUSTARD')
TG = dict(P=600, K=740, OM=3.2)  # soil type 3 (Loam) baseline of the maps; the maps store the DISTANCE to it (levelOffset), the sim keeps P and K as absolute
# content = baseline + distance so the charts and tables stay in kg/ha of the old absolute scale
TARGET_SHARE = dict(P=0.0, K=0.0)  # config nutrientMap targetRemovalShare (crop target = baseline + share x removal); none on P and K
K_TARGET_SHARE = TARGET_SHARE['K']
TARGET_SCALE = 1.0  # config fruitRequirement DEFAULT targetScale of P and K (no crop overrides)
REMOVAL_SCALE = 1.0  # config <balance removalScale>
# config nutrientMap storage: numChannels (bits), step, levelOffset, optional soft cap maxUnits (distance, spreading never raises a pixel above it)
MAPS = dict(P=dict(bits=8, step=5.0, offset=120, cap=300.0), K=dict(bits=8, step=5.0, offset=120, cap=None))
START = (562.5, 700.0, 3.25)  # P, K, OM at the start = baseline + mean of the soil type 3 initialValue deltas (checked by check_config.py)
N_CAP = 220  # the game does not let the N map above 220 kg/ha
# PF NitrogenMap yieldMappings: (N - crop target) -> yield factor (over-fertilisation is punished hard)
YN = [(-200, 0.0), (-180, .01), (-160, .05), (-140, .14), (-120, .26), (-100, .40), (-80, .58), (-60, .70), (-40, .82), (-20, .90), (-10, .95), (0, 1.0),
      (20, .98), (40, .96), (60, .92), (80, .89), (100, .85), (120, .82), (140, .79)]
# OM timeScale (config OM <nutrientMap timeScale>): every change of the OM stock is multiplied by it (game years per real year)
TS = 6
# OM mineralisation, copy of config/NutrientMaps.xml <mineralisation>: fraction of the target per year, weights by game period (1 = March)
MIN_RATE = 0.00365
N_PER_PERCENT = 8  # kg N/ha/yr released into the N map per 1 % OM stock (config nPerPercent); stock = target, same weights
MIN_WEIGHTS = [0.06, 0.09, 0.11, 0.13, 0.15, 0.15, 0.12, 0.08, 0.05, 0.02, 0.02, 0.02]


def decay_for_month(m):
    # calendar month 1..12 -> OM %-points lost in that month
    period = (m - 3) % 12 + 1
    return MIN_RATE * TG['OM'] * MIN_WEIGHTS[period - 1] * TS


def n_release_for_month(m):
    # calendar month 1..12 -> kg N/ha released into the N map in that month
    period = (m - 3) % 12 + 1
    return N_PER_PERCENT * TG['OM'] * MIN_WEIGHTS[period - 1]


def combine(fp, fk, fo):
    # law of the minimum for P and K, OM multiplies (VtszNutrients.combineFactors)
    return min(fp, fk) * fo


def yn(d):
    # N factor: linear between keyframes, clamped at both ends (unlike yf, whose right side is capped at 1)
    if d <= YN[0][0]:
        return YN[0][1]
    for (a, fa), (b, fb) in zip(YN, YN[1:]):
        if d <= b:
            return fa + (fb - fa) * (d - a) / (b - a)
    return YN[-1][1]


def yf(pts, d):
    if d <= pts[0][0]:
        return pts[0][1]
    for (a, fa), (b, fb) in zip(pts, pts[1:]):
        if d <= b:
            return min(fa + (fb - fa) * (d - a) / (b - a), 1)
    return min(pts[-1][1], 1)


YP = [(-600, .65), (-300, .8), (-200, .87), (-100, .95), (0, 1)]
YK = [(-600, .65), (-400, .8), (-250, .88), (-100, .95), (0, 1), (200, 1), (400, .97), (600, .95)]
YO = [(-2.5, .68), (-2.0, .75), (-1.5, .82), (-1.25, .855), (-1.0, .89), (-.8, .92), (-.6, .95), (-.4, .97), (-.2, .99), (0, 1)]


def dist_limits(key):
    """(lowest, highest) distance to the baseline the map can store: (0 - levelOffset) x step .. (2^bits - 1 - levelOffset) x step."""
    m = MAPS[key]
    return -m['offset'] * m['step'], ((1 << m['bits']) - 1 - m['offset']) * m['step']


def clamp_content(key, v, spread=False):
    """Absolute content after a change: stored range of the map; a spread additionally stops at the soft cap (maxUnits, P +300 above the baseline)."""
    lo, hi = dist_limits(key)
    m = MAPS[key]
    if spread and m['cap'] is not None:
        hi = min(hi, (round(m['cap'] / m['step']) ) * m['step'])
    return min(max(v - TG[key], lo), hi) + TG[key]


def crop_extra(key, removal):
    """Crop target over the soil type baseline (NutrientMap:getTargetUnits, relative maps): baseline x (targetScale - 1) + share x removal x removalScale."""
    return TG[key] * (TARGET_SCALE - 1) + TARGET_SHARE[key] * removal * REMOVAL_SCALE


def rel_target(key, extra, ph_eff=1.0):
    """Crop target as a distance (NutrientMap:getPhAdjustedTarget): (baseline + extra) / pH efficiency - baseline, capped one step below the map
    limit (the soft cap when there is one) but never below the unadjusted target. The sim assumes a pH at the optimum (efficiency 1)."""
    if ph_eff >= 1:
        return extra
    m = MAPS[key]
    hi = dist_limits(key)[1]
    if m['cap'] is not None:
        hi = min(hi, round(m['cap'] / m['step']) * m['step'])
    return min((TG[key] + extra) / ph_eff - TG[key], max(extra, hi - m['step']))


def crop_target_abs(key, removal, ph_eff=1.0):
    """The crop target as absolute content (baseline + relative target), for texts."""
    return TG[key] + rel_target(key, crop_extra(key, removal), ph_eff)


def run(events, start=START, n0=40.0):
    P, K, OM = start
    N = n0
    rows = []
    trace = [(0.0, OM)]
    done = 0  # absolute month index (0 = January of year 1) of the next month whose start decay is not yet applied
    for ev in events:
        t, kind, name = ev[0], ev[1], ev[2]
        # decay and N release at the START of every calendar month up to and including the month of this event: the mod runs them on the
        # PERIOD_CHANGED message, which Environment publishes with the new period on the first day of that period (not at the end of the month)
        target_month = (t[0] - 1) * 12 + (t[1] - 1)
        dDecay = 0.0
        dNrel = 0.0
        while done <= target_month:
            loss = min(decay_for_month(done % 12 + 1), OM)
            trace.append((float(done), OM))
            OM -= loss
            dDecay -= loss
            rel = n_release_for_month(done % 12 + 1)
            N = min(N + rel, N_CAP)
            dNrel += rel
            trace.append((float(done), OM))
            done += 1
        trace.append(((t[0] - 1) * 12 + (t[1] - 1) + t[2] / 31.0, OM))
        yfac = None
        dN = dP = dK = dOM = 0
        nshort = None
        est = False
        if kind == 'sp':
            l = ev[3]
            c = PROD[name]
            dP = c[0] * l / 1000
            dK = c[1] * l / 1000
            dOM = c[2] * l / 1000 * TS
            dN = c[3] * l / 1000
            est = c[4]
        else:
            chop = ev[3] if len(ev) > 3 else True
            forage = ev[4] if len(ev) > 4 else False
            if forage:
                chop = False  # the straw leaves with the crop
            c = CROP[name]
            # yield mapping 'difference' = actual distance - relative crop target (K: share x main-product removal over the baseline, config targetRemovalShare)
            fp = yf(YP, (P - TG['P']) - rel_target('P', crop_extra('P', c[0])))
            fk = yf(YK, (K - TG['K']) - rel_target('K', crop_extra('K', c[2])))
            fo = yf(YO, OM - TG['OM'])
            nt, nr = NCROP[name]
            fn = yn(N - nt) if nt > 0 else 1.0
            yfac = (fp, fk, fo, combine(fp, fk, fo) * fn, fn)
            nshort = N - nt  # negative: below the PF N target at harvest
            dP = -(c[0] + (0 if chop else c[1]))
            dK = -(c[2] + (0 if chop else c[3]))
            dOM = -c[4] + c[6]
            dN = -min(nr, N)  # the N map cannot go below 0: with less N than the reduction the harvest takes only what is there
            if forage and name in FORAGE_REMOVAL:
                dOM = -(max(c[4], FORAGE_REMOVAL[name]) + c[5])  # no gain, crop and straw leave
            elif chop:
                dOM += c[7]
                if name in CHOPPER_N_CROPS:
                    dN += CHOPPED_STRAW_N
            else:
                dOM -= c[5]
            dOM *= TS
        N = min(max(N + dN, 0), N_CAP)
        P = clamp_content('P', P + dP, kind == 'sp' and dP > 0)
        K = clamp_content('K', K + dK, kind == 'sp' and dK > 0)
        OM = min(max(OM + dOM, 0), 6.2)
        rows.append(dict(t=t, kind=kind, name=name, amt=ev[3] if kind == 'sp' else None, chop=(ev[3] if kind == 'h' and len(ev) > 3 else None), forage=(ev[4] if kind == 'h' and len(ev) > 4 else False),
                         dN=dN, dP=dP, dK=dK, dOM=dOM, dDecay=dDecay, dNrel=dNrel, N=N, P=P, K=K, OM=OM, y=yfac, nshort=nshort, est=est))
        trace.append(((t[0] - 1) * 12 + (t[1] - 1) + t[2] / 31.0, OM))
    run.trace = trace
    return rows
