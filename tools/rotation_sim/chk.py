import sys
from rot import *
def show(nm, e):
    print(nm)
    for r in run(e):
        if r['kind']=='h':
            T0=NCROP[r['name']][0]; pre=r['nshort']+T0
            print('  %s %-12s Npre %4.0f tgt %3d  fN %.2f  P/K/OM %.2f %.2f %.2f  Y %.2f  P %.0f K %.0f OM %.2f'%(r['t'],r['name'],pre,T0,r['y'][4],r['y'][0],r['y'][1],r['y'][2],r['y'][3],r['P'],r['K'],r['OM']))
for n in sys.argv[1:]: show(n, globals()[n])
