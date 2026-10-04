"""The animals, drawn at the point where their feet go.

Each figure is drawn in its own 100 x 100 design space and
placed with a transform. So far only the squirrel, from
entwuerfe/eichhoernchen.svg; the others stand in as a marker.
"""

from figures_more import SHADES_MORE

FIGURE_SCALE = 0.15

# How big each animal is drawn, against a house ~12 units high. Small
# animals need the camera to come close (cards.py, views).
SIZE = {'Eichhörnchen': 0.05}


def _place(o, x, y, feet, scale, flip):
    sx = -scale if flip else scale
    o.append(f'<g transform="translate({x:.2f} {y:.2f}) scale({sx} {scale}) translate({-feet[0]} {-feet[1]})">')


# Shading as on the stones and the crown: every part a round body, lit from
# the upper left, darker towards its lower right edge. (light, base, dark)
SHADES = {
    'fur-light': ('#F09A5C', '#D4612F', '#9E3D1D'),
    'fur':       ('#E07B45', '#C9542D', '#8E3519'),
    'fur-dark':  ('#C9592F', '#A9411F', '#6E2812'),
    'tail':      ('#F4A866', '#DD7034', '#A8441F'),
    'belly':     ('#FFFCF3', '#F2EDDB', '#C9BFA6'),
    'nut':       ('#A3754A', '#744F30', '#4A311C'),
    'leaf':      ('#6BBF73', '#408F4A', '#2B6633'),
}


def figure_defs():
    """Gradients the figures use; scene.py puts them into every scene."""
    d = []
    for name, (light, base, dark) in {**SHADES, **SHADES_MORE}.items():
        d.append(f'<radialGradient id="fig-{name}" cx="0.36" cy="0.3" r="0.8"><stop offset="0" stop-color="{light}"/>'
                 f'<stop offset="0.55" stop-color="{base}"/><stop offset="1" stop-color="{dark}"/></radialGradient>')
    return d


def tuft(x, y, size, fill):
    """An ear's tuft: a few tapering wisps of hair rising from the tip and
    swept back, the middle one longest."""
    wisps = ((-2.4, -5.6, -0.3), (-0.6, -7.0, 0.0), (1.2, -5.2, 0.3))   # tip offset, lean
    out = ''
    for dx, dy, lean in wisps:
        tx, ty = x + dx*size, y + dy*size
        w = 0.9*size
        out += (f'<path d="M{x-w:.2f} {y+0.6:.2f} Q{x-w*0.6+lean+dx*0.3*size:.2f} {y+dy*0.55*size:.2f} {tx:.2f} {ty:.2f} '
                f'Q{x+w*0.6+lean+dx*0.5*size:.2f} {y+dy*0.45*size:.2f} {x+w:.2f} {y+0.6:.2f} Z" fill="{fill}"/>')
    return out


def _spline(points, n):
    """Catmull-Rom through the points, n samples."""
    import math
    pts = [points[0]] + points + [points[-1]]
    out = []
    for i in range(n):
        t = i/(n - 1)*(len(points) - 1)
        k = min(int(t), len(points) - 2)
        u = t - k
        p0, p1, p2, p3 = pts[k], pts[k + 1], pts[k + 2], pts[k + 3]
        out.append(tuple(0.5*((2*p1[j]) + (-p0[j] + p2[j])*u + (2*p0[j] - 5*p1[j] + 4*p2[j] - p3[j])*u*u
                              + (-p0[j] + 3*p1[j] - 3*p2[j] + p3[j])*u**3) for j in (0, 1)))
    return out


# The tail's spine from the root behind the back up over the head, and how
# wide it is along the way: thin at the root, full in the middle, a curl at the end.
TAIL_SPINE = [(42, 80), (28, 72), (20, 56), (21, 40), (28, 28), (38, 21), (47, 21), (51, 26)]
TAIL_WIDTH = [9, 17, 21, 20, 17, 13, 8, 3]


def squirrel_tail(fill):
    """A bushy plume: one shape along a curved spine, the outer edge in
    pointed tufts of fur, the inner edge smooth; a few lighter strands
    give it its grain."""
    import math
    n = 60
    spine = _spline(TAIL_SPINE, n)
    widths = _spline([(w, 0) for w in TAIL_WIDTH], n)
    outer, inner = [], []
    for i, (x, y) in enumerate(spine):
        a, b = spine[max(0, i - 1)], spine[min(n - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) or 1
        nx, ny = dy/L, -dx/L                       # to the outside of the curve (left, back)
        w = widths[i][0]/2
        tuft = 1 + (0.16 if i % 3 == 1 else 0.0)*min(1, i/6)*min(1, (n - 1 - i)/4)
        outer.append((x + nx*w*tuft, y + ny*w*tuft))
        inner.append((x - nx*w*(0.8 + (0.08 if i % 5 == 2 else 0)), y - ny*w*(0.8 + (0.08 if i % 5 == 2 else 0))))
    P = lambda ps: ' L'.join(f'{px:.2f} {py:.2f}' for px, py in ps)
    out = f'<path d="M{P(outer)} L{P(inner[::-1])} Z" fill="{fill}" stroke="#A8441F" stroke-width="0.4" stroke-linejoin="round"/>'
    # strands: lighter lines along the spine, on the lit side
    for off, start, end, op in ((0.5, 6, 54, 0.4), (0.15, 10, 57, 0.3), (-0.2, 8, 50, 0.25), (-0.5, 14, 44, 0.2)):
        strand = []
        for i in range(start, end):
            x, y = spine[i]
            a, b = spine[max(0, i - 1)], spine[min(n - 1, i + 1)]
            dx, dy = b[0] - a[0], b[1] - a[1]
            L = math.hypot(dx, dy) or 1
            w = widths[i][0]/2
            strand.append((x + dy/L*w*off, y - dx/L*w*off))
        out += f'<path d="M{P(strand)}" fill="none" stroke="#F8C08A" stroke-opacity="{op}" stroke-width="0.7" stroke-linecap="round"/>'
    return out


SQUIRREL_FEET = (52, 88)
SQUIRREL_TAIL_ROOT = (42, 80)
SQUIRREL_EYE = (64, 43.5)


def squirrel_body(anim=None, shadow=True):
    """The squirrel in its design space, feet at SQUIRREL_FEET. `anim` may
    hold SMIL elements for the parts that move on their own: 'tail', 'nut',
    'eye', 'head'."""
    anim = anim or {}
    f = lambda n: f'url(#fig-{n})'
    o = []
    if shadow:
        o.append('<ellipse cx="50" cy="88.5" rx="20" ry="3" fill="#3A2813" opacity="0.3"/>')
    o.append('<g>' + anim.get('tail', '') + squirrel_tail(f('tail')) + '</g>')
    o.append(f'<ellipse cx="47" cy="79" rx="10" ry="8" fill="{f("fur-dark")}"/>'
             f'<ellipse cx="55" cy="86.2" rx="8.5" ry="2.7" fill="{f("fur-dark")}"/>')
    o.append(f'<ellipse cx="52" cy="68" rx="15" ry="17" fill="{f("fur")}" transform="rotate(-12 52 68)"/>'
             f'<ellipse cx="58" cy="71" rx="7.5" ry="11.5" fill="{f("belly")}" transform="rotate(-12 58 71)"/>')
    o.append('<g>' + anim.get('head', ''))
    # the head casts a little shade on the chest
    o.append('<ellipse cx="60" cy="57.5" rx="9" ry="3" fill="#000" opacity="0.15"/>')
    # far ear, then the head, then the near ear in front of it
    o.append(f'<path d="M58 37 Q57.5 29 61.5 26 Q65 31 64 38 Z" fill="{f("fur-dark")}"/>')
    o.append(tuft(61.5, 26.6, 1.0, '#6E2812'))
    o.append(f'<circle cx="60" cy="45" r="12" fill="{f("fur-light")}"/>'
             f'<ellipse cx="70" cy="49" rx="6.5" ry="5.2" fill="{f("fur-light")}"/>'
             f'<ellipse cx="66" cy="53" rx="6" ry="3.6" fill="{f("belly")}"/>')
    o.append(f'<path d="M50.5 39 Q49.5 29 54.5 24.5 Q59 30 58.5 37 Z" fill="{f("fur")}"/>'
             f'<path d="M52.6 36 Q52.4 30.5 54.6 28 Q56.6 31.5 56.4 35.5 Z" fill="#8E3519"/>')
    o.append(tuft(54.5, 25.2, 1.3, f("fur-dark")))
    ex, ey = SQUIRREL_EYE
    o.append(f'<g transform="translate({ex} {ey})"><g>{anim.get("eye", "")}<g transform="translate({-ex} {-ey})">'
             '<circle cx="64" cy="43.5" r="2.4" fill="#22313A"/><circle cx="64.9" cy="42.6" r="0.8" fill="#F2EDDB"/>'
             '</g></g></g>')
    o.append('<circle cx="76" cy="48" r="1.4" fill="#22313A"/><circle cx="75.6" cy="47.6" r="0.4" fill="#F2EDDB" opacity="0.7"/>')
    o.append('</g>')
    # nut and paws last: held in front of the chest, lifted to the mouth
    o.append('<g>' + anim.get('nut', '') +
             f'<ellipse cx="69" cy="63" rx="4.6" ry="5.4" fill="{f("nut")}"/>'
             f'<path d="M64.2 60.4 Q69 55.6 73.8 60.4 Q69 58.8 64.2 60.4 Z" fill="{f("leaf")}"/>'
             f'<ellipse cx="65" cy="64.5" rx="2.6" ry="3.4" fill="{f("fur-dark")}"/>'
             f'<ellipse cx="73" cy="64.5" rx="2.6" ry="3.4" fill="{f("fur-dark")}"/></g>')
    return ''.join(o)


def squirrel(o, x, y, scale=FIGURE_SCALE, flip=False):
    _place(o, x, y, SQUIRREL_FEET, scale, flip)
    o.append(squirrel_body())
    o.append('</g>')


def marker(o, x, y, scale=FIGURE_SCALE, flip=False):
    """Stands in for an animal not drawn yet: a cube."""
    s = 9*scale
    o.append(f'<path d="M{x-s:.2f} {y-s*0.4:.2f} L{x:.2f} {y-s*0.8:.2f} L{x+s:.2f} {y-s*0.4:.2f} L{x+s:.2f} {y-s*1.6:.2f} '
             f'L{x:.2f} {y-s*2:.2f} L{x-s:.2f} {y-s*1.6:.2f} Z" fill="#E9E2CF" stroke="#22313A" stroke-width="0.3"/>')


FIGURES = {'Eichhörnchen': squirrel}


# ---- the animals of figures_more.py, standing still, for the static scenes

def _still(body, feet):
    def draw(o, x, y, scale=FIGURE_SCALE, flip=False):
        _place(o, x, y, feet, scale, flip)
        o.append(body({}))
        o.append('</g>')
    return draw


from fig_duck import DUCK_FEET, duck_body

SIZE['Ente'] = 0.06
FIGURES['Ente'] = _still(duck_body, DUCK_FEET)

from fig_bug import BUG_FEET, bug_body

SIZE['Marienkäfer'] = 0.03
FIGURES['Marienkäfer'] = _still(bug_body, BUG_FEET)


from fig_bird import BIRD_FEET, eagle_still, raven_still

from fig_eagle import EAGLE_FEET, eagle_still as eagle_still_new

SIZE['Adler'] = 0.085
FIGURES['Adler'] = _still(eagle_still_new, EAGLE_FEET)
SIZE['Rabe'] = 0.05
FIGURES['Rabe'] = _still(raven_still, BIRD_FEET)
