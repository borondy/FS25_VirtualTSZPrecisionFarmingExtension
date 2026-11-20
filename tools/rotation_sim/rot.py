from sim import *


def T(y, m, d=1):
    return (y, m, d)


def sp(t, n, l):
    return (t, 'sp', n, l)


def h(t, n, chop=True, forage=False):
    return (t, 'h', n, chop, forage)


A = [
    sp(T(1, 3, 10), 'PETISO27', 250),
    h(T(1, 4, 28), 'GREENRYE'),
    sp(T(1, 4, 30), 'LIQUIDMANURE', 25000),
    sp(T(1, 5, 5), 'NPK8_24_24', 200),
    sp(T(1, 6, 10), 'PETISO27', 300),
    h(T(1, 9, 20), 'SILAGEMAIZE'),
    sp(T(1, 10, 1), 'MANURE', 14000),
    sp(T(1, 10, 2), 'KALISO60', 300),
    h(T(2, 5, 10), 'VETCHRYE'),
    sp(T(2, 5, 12), 'LIQUIDMANURE', 30000),
    sp(T(2, 5, 15), 'MAP11_52', 200),
    sp(T(2, 6, 5), 'KARBAMID46', 100),
    h(T(2, 10, 15), 'MAIZE'),
    sp(T(2, 10, 18), 'KALISO60', 150),
    sp(T(3, 3, 10), 'PETISO27', 330),
    sp(T(3, 4, 15), 'NITROSOL30', 120),
    h(T(3, 6, 25), 'WINTERBARLEY'),
    sp(T(3, 8, 10), 'DIGESTATE', 20000),
    sp(T(4, 3, 1), 'PETISO27', 100),
    h(T(4, 6, 28), 'CANOLA'),
    sp(T(4, 9, 5), 'TSP46', 80),
    sp(T(4, 9, 6), 'KALISO60', 60),
    h(T(5, 4, 28), 'GREENRYE'),
    sp(T(5, 4, 30), 'LIQUIDMANURE', 25000),
    sp(T(5, 5, 5), 'NPK8_24_24', 200),
    sp(T(5, 6, 10), 'PETISO27', 350),
    h(T(5, 9, 20), 'SILAGEMAIZE'),
    sp(T(5, 10, 1), 'MANURE', 14000),
    sp(T(5, 10, 2), 'KALISO60', 100),
]

B = [
    sp(T(1, 3, 20), 'MAP11_52', 200),
    sp(T(1, 3, 22), 'KALISO60', 250),
    sp(T(1, 4, 10), 'KARBAMID46', 350),
    sp(T(1, 6, 5), 'NITROSOL30', 120),
    h(T(1, 10, 10), 'MAIZE'),
    sp(T(2, 4, 15), 'PETISO27', 380),
    sp(T(2, 5, 10), 'NITROSOL30', 240),
    h(T(2, 7, 8), 'WINTERWHEAT', False),
    sp(T(2, 8, 5), 'TSP46', 230),
    sp(T(2, 8, 6), 'PATENTKALI', 300),
    sp(T(3, 4, 5), 'NPK15_15_15', 300),
    sp(T(3, 4, 20), 'PETISO27', 200),
    h(T(3, 9, 15), 'SUNFLOWER'),
    sp(T(3, 10, 1), 'KALISO60', 250),
    sp(T(4, 4, 5), 'PETISO27', 100),
    sp(T(4, 4, 25), 'NITROSOL30', 250),
    h(T(4, 6, 25), 'WINTERBARLEY', False),
    sp(T(4, 8, 5), 'SSP18', 300),
    sp(T(4, 8, 6), 'PATENTKALI', 300),
]

C = [
    sp(T(1, 5, 5), 'NPK8_24_24', 150),
    sp(T(1, 6, 10), 'PETISO27', 400),
    sp(T(1, 6, 20), 'NITROSOL30', 210),
    h(T(1, 9, 25), 'SILAGEMAIZE'),
    sp(T(1, 10, 5), 'MANURE', 25000),
    sp(T(1, 10, 6), 'LIQUIDMANURE', 10000),
    sp(T(1, 10, 7), 'KALISO60', 200),
    h(T(2, 7, 5), 'WINTERWHEAT', False),
    sp(T(2, 8, 10), 'KALISO60', 150),
    sp(T(3, 3, 15), 'TSP46', 250),
    h(T(3, 7, 10), 'FABABEAN'),
    sp(T(3, 9, 5), 'MANURE', 15000),
    h(T(4, 6, 25), 'WINTERBARLEY', False),
    sp(T(4, 8, 10), 'LIQUIDMANURE', 20000),
    sp(T(4, 8, 12), 'KALISO60', 150),
]

# D: dairy silage rotation with unlimited manure / slurry spread after every silage maize (no alfalfa): forage rye + silage maize, vetch rye +
# silage maize, whole-crop barley cut with a forage header. 6 game years (= 1 real year) = the cycle twice.
# The N map is capped at 220 kg/ha and over-fertilisation costs yield (PF yieldMappings), so every organic dose is sized to the N target of
# the NEXT crop: ~100 kg N before vetch (target 100), ~175 kg N before the whole-crop barley (target 180).
D = []
for y0 in (0, 3):
    D += [
        sp(T(y0 + 1, 3, 10), 'PETISO27', 250 if y0 == 0 else 200),
        h(T(y0 + 1, 4, 28), 'GREENRYE'),
        sp(T(y0 + 1, 5, 5), 'NPK8_24_24', 200),
        sp(T(y0 + 1, 5, 6), 'LIQUIDMANURE', 30000),
        sp(T(y0 + 1, 6, 10), 'PETISO27', 215),
        h(T(y0 + 1, 9, 20), 'SILAGEMAIZE'),
        sp(T(y0 + 1, 10, 1), 'MANURE', 14000),
        sp(T(y0 + 1, 10, 3), 'KALISO60', 200),
        h(T(y0 + 2, 5, 10), 'VETCHRYE'),
        sp(T(y0 + 2, 5, 15), 'MAP11_52', 200),
        sp(T(y0 + 2, 5, 12), 'LIQUIDMANURE', 30000),
        sp(T(y0 + 2, 6, 5), 'KARBAMID46', 100),
        h(T(y0 + 2, 10, 5), 'SILAGEMAIZE'),
        sp(T(y0 + 2, 10, 17), 'MANURE', 25000),
        sp(T(y0 + 2, 10, 19), 'KALISO60', 300),
        h(T(y0 + 3, 6, 25), 'WINTERBARLEY', False, True),
        sp(T(y0 + 3, 8, 11), 'KALISO60', 300),
    ]
D.sort(key=lambda e: e[0])

# E: as D, plus manure after the whole-crop barley and an alfalfa break in the last year of each cycle (3 cuts, slurry after each cut).
# Years 1-2 crops of D, year 3 whole-crop barley, year 4 alfalfa.
E = []
for y0 in (0, 4):
    E += [sp(T(y0 + 1, 3, 10), 'PETISO27', 250)] if y0 == 0 else []
    E += [
        h(T(y0 + 1, 4, 28), 'GREENRYE'),
        sp(T(y0 + 1, 5, 5), 'NPK8_24_24', 200),
        sp(T(y0 + 1, 5, 6), 'LIQUIDMANURE', 30000),
        sp(T(y0 + 1, 6, 10), 'PETISO27', 215),
        h(T(y0 + 1, 9, 20), 'SILAGEMAIZE'),
        sp(T(y0 + 1, 10, 1), 'MANURE', 14000),
        sp(T(y0 + 1, 10, 3), 'KALISO60', 200),
        h(T(y0 + 2, 5, 10), 'VETCHRYE'),
        sp(T(y0 + 2, 5, 15), 'MAP11_52', 200),
        sp(T(y0 + 2, 5, 12), 'LIQUIDMANURE', 30000),
        sp(T(y0 + 2, 6, 5), 'KARBAMID46', 100),
        h(T(y0 + 2, 10, 5), 'SILAGEMAIZE'),
        sp(T(y0 + 2, 10, 17), 'MANURE', 25000),
        sp(T(y0 + 2, 10, 19), 'KALISO60', 200),
        h(T(y0 + 3, 6, 25), 'WINTERBARLEY', False, True),
        sp(T(y0 + 4, 3, 20), 'KALISO60', 300),
        sp(T(y0 + 4, 3, 25), 'LIQUIDMANURE', 5000),
        h(T(y0 + 4, 4, 25), 'ALFALFA', False, False),
        sp(T(y0 + 4, 4, 27), 'LIQUIDMANURE', 13000),
        h(T(y0 + 4, 7, 10), 'ALFALFA', False, False),
        sp(T(y0 + 4, 7, 12), 'LIQUIDMANURE', 13000),
        h(T(y0 + 4, 10, 10), 'ALFALFA', False, False),
        sp(T(y0 + 4, 10, 12), 'LIQUIDMANURE', 22000),
    ]
E.sort(key=lambda e: e[0])

if __name__ == '__main__':
    for nm, e in (('A', A), ('B', B), ('C', C), ('D', D), ('E', E)):
        print(nm)
        for r in run(e):
            if r['kind'] == 'h':
                print(r['t'], r['name'], 'Nshort %+.0f' % r['nshort'], 'N %.0f P %.0f K %.0f OM %.3f' % (r['N'], r['P'], r['K'], r['OM']), 'Y %.2f %.2f %.2f =%.2f' % r['y'])
