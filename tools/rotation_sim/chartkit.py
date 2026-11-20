"""Shared look of the wiki rotation charts (om_chart.py and npk_chart.py): fonts, colours, number format, frame, header, year bands, boxes, footer."""
import textwrap

W = 1200
L, R = 190, 110  # plot area x: left margin (row labels, tick labels), right margin (target label)
PW = W - L - R
FONT = 'font-family="Segoe UI, Roboto, Helvetica, Arial, sans-serif"'
INK, MUTED, FAINT = '#2b2b2b', '#555555', '#777777'
GRID, AXIS, BAND, BOXLINE = '#e3dfd8', '#999999', '#f6f3ee', '#c9c2b6'
CURVE_OM = '#a8641a'
# nutrient colours (limiting-factor dots, N/P/K curves, fertilizer lanes)
COL = dict(N='#3b7dd8', P='#8e5ab0', K='#d98a1f', OM='#2f8f5b', none='#9a9a9a')
ORG, MIX = '#7a5a2a', '#2a9d8f'
CROP_BANDS = ('#e8f1fb', '#fdf1de')


def num(v, dec, digits=2, sign=False):
    s = ('%+.' + str(digits) + 'f') % v if sign else ('%.' + str(digits) + 'f') % v
    s = s.replace('-', '−')  # real minus sign
    return s.replace('.', dec)


def mon(t):
    return (t[0] - 1) * 12 + (t[1] - 1) + t[2] / 31.0


def X_of(months):
    return lambda m: L + PW * m / months


def open_svg(h):
    return ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d" %s>' % (W, h, W, h, FONT),
            '<rect x="0" y="0" width="%d" height="%d" rx="18" ry="18" fill="#ffffff" stroke="#d8d2c8" stroke-width="2"/>' % (W, h)]


def header(o, title, subtitle):
    o.append('<text x="56" y="52" font-size="30" font-weight="700" fill="%s">%s</text>' % (INK, title))
    o.append('<text x="56" y="84" font-size="21" fill="%s">%s</text>' % (MUTED, subtitle))


def year_bands(o, X, years, top, bottom, label_y, xlabel):
    """Alternate year shading from top to bottom, year numbers and the axis title at label_y."""
    for y in range(years):
        if y % 2 == 1:
            o.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s"/>' % (X(y * 12), top, X(12) - X(0), bottom - top, BAND))
        o.append('<text x="%.1f" y="%.1f" font-size="20" fill="%s" text-anchor="middle">%d</text>' % (X(y * 12 + 6), label_y, MUTED, y + 1))
    o.append('<text x="%.1f" y="%.1f" font-size="19" fill="%s" text-anchor="middle">%s</text>' % (X(years * 6), label_y + 26, FAINT, xlabel))


def hline(o, y, color=GRID, width=1.5, dash=None):
    o.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="%s" stroke-width="%s"%s/>' % (L, L + PW, y, y, color, width, ' stroke-dasharray="%s"' % dash if dash else ''))


def tick(o, y, text, size=19):
    o.append('<text x="%d" y="%.1f" font-size="%d" fill="%s" text-anchor="end">%s</text>' % (L - 10, y + 6, size, MUTED, text))


def target_line(o, y, label, value_text):
    hline(o, y, '#8a8a8a', 2, '9 7')
    o.append('<text x="%d" y="%.1f" font-size="17" fill="#666666">%s</text>' % (L + PW + 8, y - 2, label))
    o.append('<text x="%d" y="%.1f" font-size="17" fill="#666666">%s</text>' % (L + PW + 8, y + 17, value_text))


def box(o, x, y, w, h):
    o.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="8" fill="#ffffff" stroke="%s" stroke-width="1.5"/>' % (x, y, w, h, BOXLINE))


def ring(o, x, y, color, r=7):
    o.append('<circle cx="%.1f" cy="%.1f" r="%d" fill="#ffffff" stroke="%s" stroke-width="4"/>' % (x, y, r, color))


def dot(o, x, y, color, r=6):
    o.append('<circle cx="%.1f" cy="%.1f" r="%d" fill="%s"/>' % (x, y, r, color))


def footer(o, text, y):
    for j, line in enumerate(textwrap.wrap(text, 135)):
        o.append('<text x="56" y="%d" font-size="17" fill="%s">%s</text>' % (y + 24 * j, FAINT, line))


def footer_lines(text):
    return len(textwrap.wrap(text, 135))
