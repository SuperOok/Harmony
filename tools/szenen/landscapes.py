"""The landscapes of the board, one function each, drawn as SVG.

A function that draws something standing up takes the list it appends to
and the middle of its hex; scene.py sorts those back to front. Flat land
(water, field ground) is drawn straight onto the board. All settings come
from style.py.
"""
import math
import random

from style import *

R, SQ = HEX_RADIUS, SQUASH
W = R*math.sqrt(3)
RX, RY, H = STONE_RX, STONE_RY, STONE_H

# Neighbour across the edge whose middle lies at this angle (0 = right,
# clockwise, since y grows downwards).
NEIGHBOURS = {0: (1, 0), 60: (0, 1), 120: (-1, 1), 180: (-1, 0), 240: (0, -1), 300: (1, -1)}


class Board:
    """Where the hexes lie: axial (q, r), hex (0, 0) at origin."""
    def __init__(self, origin=(50 + W/2, 72)):
        self.ox, self.oy = origin

    def pos(self, q, r):
        return self.ox + W*(q + r/2), self.oy + 1.5*R*SQ*r


# ------------------------------------------------------------- helpers

def path(ps): return ' L'.join(f'{x:.2f} {y:.2f}' for x, y in ps)
def points(ps): return ' '.join(f'{x:.2f},{y:.2f}' for x, y in ps)
def grey(v): v = max(0, min(255, int(v))); return f'#{v:02X}{v:02X}{v:02X}'

def corners(cx, cy, s=1.0):
    return [(cx + s*R*math.cos(math.radians(30 + 60*k)), cy + s*R*math.sin(math.radians(30 + 60*k))*SQ)
            for k in range(6)]

def inside(px, py, cx, cy, s=1.0):
    dx, dy = abs(px - cx)/(s*R), abs(py - cy)/(s*R*SQ)
    return dx <= math.sqrt(3)/2 and dy + dx/math.sqrt(3) <= 1

def outer_edges(board, cells):
    """Edges of a group of hexes that border no other hex of the group."""
    for q, r in cells:
        pts = corners(*board.pos(q, r))
        for k in range(6):
            angle = (60*(k + 1)) % 360
            dq, dr = NEIGHBOURS[angle]
            if (q + dq, r + dr) not in cells:
                yield pts[k], pts[(k + 1) % 6], angle

def visibility(r):
    """1 in the front row, less for every row behind it."""
    return max(0.0, 1 + FADE_PER_ROW*r) if r < 0 else 1.0


def defs():
    """Gradients and filters every scene uses."""
    d = ['<defs>']
    for k, (b, t, dk) in STONES.items():
        d.append(f'<linearGradient id="side-{k}" x1="0" x2="1"><stop offset="0" stop-color="{dk}"/><stop offset="0.3" stop-color="{b}"/>'
                 f'<stop offset="0.45" stop-color="{t}"/><stop offset="0.7" stop-color="{b}"/><stop offset="1" stop-color="{dk}"/></linearGradient>')
        d.append(f'<radialGradient id="top-{k}" cx="0.4" cy="0.35" r="0.75"><stop offset="0" stop-color="{t}"/><stop offset="1" stop-color="{b}"/></radialGradient>')
    for r in range(-6, 0):
        a = 0.2 + 0.6*visibility(r)
        d.append(f'<filter id="far{-r}"><feColorMatrix type="saturate" values="{SATURATION_FAR}" result="s"/>'
                 f'<feFlood flood-color="{BACKGROUND}" result="f"/><feComposite in="f" in2="SourceAlpha" operator="in" result="fm"/>'
                 f'<feComposite in="s" in2="fm" operator="arithmetic" k2="{a:.2f}" k3="{1-a:.2f}"/></filter>')
    d.append(f'<linearGradient id="haze" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{BACKGROUND}"/>'
             f'<stop offset="{HAZE_TOP[0]}" stop-color="{BACKGROUND}"/><stop offset="{HAZE_TOP[1]}" stop-color="{BACKGROUND}" stop-opacity="0"/></linearGradient>')
    for name, (light, base, dark) in (('ball', CROWN_FRONT), ('ball-back', CROWN_BACK)):
        d.append(f'<radialGradient id="{name}" cx="0.36" cy="0.3" r="0.75"><stop offset="0" stop-color="{light}"/>'
                 f'<stop offset="0.6" stop-color="{base}"/><stop offset="1" stop-color="{dark}"/></radialGradient>')
    d.append(f'<linearGradient id="water" gradientUnits="userSpaceOnUse" x1="0" y1="40" x2="0" y2="100">'
             f'<stop offset="0" stop-color="{WATER[0]}"/><stop offset="1" stop-color="{WATER[1]}"/></linearGradient>')
    d.append('</defs>')
    return d


def board(o, b, rows=range(-6, 3), cols=range(-8, 8)):
    for r in rows:
        for q in cols:
            cx, cy = b.pos(q, r)
            if not (-W < cx < 100 + W and 20 < cy < 110):
                continue
            a = 0.25 + 0.75*visibility(r)
            o.append(f'<polygon points="{points(corners(cx, cy, HEX_GAP))}" fill="{HEX_FILL}" fill-opacity="{a:.2f}" '
                     f'stroke="{HEX_EDGE}" stroke-opacity="{a:.2f}" stroke-width="0.35"/>')


# ------------------------------------------------------------- stones

def token(o, cx, yb, k, rx=RX, ry=RY, h=H):
    """A stone as it lies on the table: a short cylinder."""
    yt = yb - h
    o.append(f'<path d="M{cx-rx:.2f} {yt:.2f} L{cx-rx:.2f} {yb:.2f} A{rx} {ry:.2f} 0 0 0 {cx+rx:.2f} {yb:.2f} L{cx+rx:.2f} {yt:.2f} Z" fill="url(#side-{k})"/>')
    o.append(f'<path d="M{cx-rx:.2f} {yb:.2f} A{rx} {ry:.2f} 0 0 0 {cx+rx:.2f} {yb:.2f}" fill="none" stroke="#000" stroke-opacity="0.35" stroke-width="0.4"/>')
    o.append(f'<ellipse cx="{cx:.2f}" cy="{yt:.2f}" rx="{rx}" ry="{ry:.2f}" fill="url(#top-{k})"/>')
    o.append(f'<ellipse cx="{cx:.2f}" cy="{yt:.2f}" rx="{rx-0.35:.2f}" ry="{ry-0.3:.2f}" fill="none" stroke="#fff" stroke-opacity="0.18" stroke-width="0.45"/>')

def shadow(o, cx, cy, rx=RX + 1.4, ry=RY + 0.9):
    o.append(f'<ellipse cx="{cx+1:.2f}" cy="{cy+0.5:.2f}" rx="{rx:.2f}" ry="{ry:.2f}" fill="#000" opacity="{SHADOW_OPACITY}"/>')


# ------------------------------------------------------------- building

def roof(o, cx, yb, rx=EAVE_RX, rise=ROOF_RISE):
    """The brick on top: a gable whose ridge runs away from the viewer, with a chimney."""
    ry = rx*RY/RX
    b, t, d = STONES['brick']
    def rim(a0, a1, n=32):
        return [(cx + rx*math.cos(a0 + (a1 - a0)*i/n),
                 yb + ry*math.sin(a0 + (a1 - a0)*i/n) - rise*(1 - abs(math.cos(a0 + (a1 - a0)*i/n)))) for i in range(n + 1)]
    front = rim(0, math.pi)
    o.append(f'<path d="M{cx-rx:.2f} {yb:.2f} L{path(front[::-1])} L{cx+rx:.2f} {yb:.2f} A{rx} {ry:.2f} 0 0 1 {cx-rx:.2f} {yb:.2f} Z" fill="url(#side-brick)"/>')
    o.append(f'<path d="M{cx-rx:.2f} {yb:.2f} A{rx} {ry:.2f} 0 0 0 {cx+rx:.2f} {yb:.2f}" fill="none" stroke="#000" stroke-opacity="0.35" stroke-width="0.4"/>')
    ridge_front, ridge_back = (cx, yb + ry - rise), (cx, yb - ry - rise)
    o.append(f'<path d="M{path(rim(math.pi/2, 3*math.pi/2))} L{path([ridge_front])} Z" fill="{t}"/>')   # towards the light
    o.append(f'<path d="M{path(rim(-math.pi/2, math.pi/2))} L{path([ridge_back])} Z" fill="{d}"/>')     # in shade
    o.append(f'<path d="M{path([ridge_front, ridge_back])}" stroke="#fff" stroke-opacity="0.3" stroke-width="0.45"/>')
    o.append(f'<path d="M{path(front)}" fill="none" stroke="#000" stroke-opacity="0.25" stroke-width="0.35"/>')
    light, dark, mouth = CHIMNEY
    x0, w = cx + 0.4*rx, 1.8
    foot = yb - rise*(1 - (x0 + w/2 - cx)/rx) + 0.7
    top = foot - 3.8
    o.append(f'<rect x="{x0:.2f}" y="{top:.2f}" width="{w}" height="{foot-top:.2f}" fill="{light}"/>')
    o.append(f'<rect x="{x0+w*0.55:.2f}" y="{top:.2f}" width="{w*0.45:.2f}" height="{foot-top:.2f}" fill="{dark}"/>')
    o.append(f'<ellipse cx="{x0+w/2:.2f}" cy="{top:.2f}" rx="{w/2+0.22:.2f}" ry="0.48" fill="{mouth}" stroke="#9A9A9A" stroke-width="0.3"/>')

def facade(o, cx, yb, rx=HOUSE_RX):
    """Door and lit window on the front of the stone under the roof."""
    base = yb + rx*RY/RX*0.93
    dl, dr, dt = cx - 3.3, cx - 0.9, base - 4.1
    o.append(f'<path d="M{dl:.2f} {base:.2f} L{dl:.2f} {dt+1.2:.2f} A1.2 1.2 0 0 1 {dr:.2f} {dt+1.2:.2f} L{dr:.2f} {base:.2f} Z" fill="{DOOR}"/>')
    o.append(f'<circle cx="{dr-0.5:.2f}" cy="{base-2.0:.2f}" r="0.24" fill="#D9B45A"/>')
    wl, wt, ww, wh = cx + 0.9, base - 3.9, 2.4, 2.1
    o.append(f'<rect x="{wl:.2f}" y="{wt:.2f}" width="{ww}" height="{wh}" rx="0.25" fill="{WINDOW}" stroke="{DOOR}" stroke-width="0.4"/>')
    o.append(f'<path d="M{wl+ww/2:.2f} {wt:.2f} V{wt+wh:.2f} M{wl:.2f} {wt+wh/2:.2f} H{wl+ww:.2f}" stroke="{DOOR}" stroke-width="0.3"/>')

def eave_shadow(o, cx, yt, rx=HOUSE_RX):
    ry = rx*RY/RX
    o.append(f'<path d="M{cx-rx:.2f} {yt:.2f} A{rx} {ry:.2f} 0 0 0 {cx+rx:.2f} {yt:.2f} L{cx+rx:.2f} {yt+1.4:.2f} '
             f'A{rx} {ry:.2f} 0 0 1 {cx-rx:.2f} {yt+1.4:.2f} Z" fill="#000" opacity="0.28"/>')

def building(base='stone'):
    """A red stone on a grey, brown or red one."""
    def draw(o, cx, cy):
        shadow(o, cx, cy, HOUSE_RX + 1.6, (HOUSE_RX + 1.6)*RY/RX + 0.6)
        token(o, cx, cy, base, rx=HOUSE_RX, ry=HOUSE_RX*RY/RX, h=HOUSE_H)
        facade(o, cx, cy)
        eave_shadow(o, cx, cy - HOUSE_H)
        roof(o, cx, cy - HOUSE_H)
    return draw


# ------------------------------------------------------------- tree

def tree(height):
    """Wood stones as a narrow trunk, the leaves as a crown of clumps."""
    def draw(o, cx, cy):
        shadow(o, cx, cy)
        for i in range(height - 1):
            token(o, cx, cy - i*H, 'wood', rx=TRUNK_RX, ry=TRUNK_RY)
        yb = cy - (height - 1)*H
        for dx, dy, r, back in CROWN:
            o.append(f'<circle cx="{cx+dx:.2f}" cy="{yb+dy:.2f}" r="{r}" fill="url(#ball{"-back" if back else ""})"/>')
    return draw


# ------------------------------------------------------------- mountain

def rock(nx, ny):
    """Grey of a rock face with this outward normal; light from the upper left."""
    a, b, c = MOUNTAIN_GREY
    return a - b*nx + c*ny

def mountain(height, seed=0):
    """A rocky cone that steps in at every stone's height, so the stones can be counted."""
    HM = MOUNTAIN_STONE_H
    def draw(o, cx, cy):
        rr = random.Random(seed)
        r0, N = R*MOUNTAIN_FOOT, MOUNTAIN_FACES
        rings = []
        for i in range(height):
            k0 = r0*(1 - i/(height + MOUNTAIN_TAPER))
            k1 = r0*(1 - (i + 1)/(height + MOUNTAIN_TAPER))
            rings += [(i*HM, k0), ((i + 1)*HM - 0.01, k1 + MOUNTAIN_LEDGE)]
        ax, ay = cx + rr.uniform(-1.5, 1.5), cy - height*HM - 2.0 - 0.8*height
        jitter = [rr.uniform(0.9, 1.08) for _ in range(N + 1)]
        def pt(j, up, k):
            t = math.pi*j/N          # 0 = right, pi = left, round the front
            return cx + k*jitter[j]*math.cos(t), cy + k*jitter[j]*math.sin(t)*SQ - up
        shadow(o, cx, cy, r0 + 1.4, (r0 + 1.4)*SQ)
        for j in range(N):
            tm = math.pi*(j + 0.5)/N
            nx, ny = math.cos(tm), math.sin(tm)
            for (u0, k0), (u1, k1) in zip(rings, rings[1:]):
                c = grey(rock(nx, ny) + (MOUNTAIN_LEDGE_LIGHT if k1 > k0 else 0))   # a ledge faces up
                o.append(f'<path d="M{path([pt(j, u0, k0), pt(j+1, u0, k0), pt(j+1, u1, k1), pt(j, u1, k1)])} Z" fill="{c}" stroke="{c}" stroke-width="0.15"/>')
            u, k = rings[-1]
            c = grey(rock(nx*0.8, ny*0.6))
            o.append(f'<path d="M{path([pt(j, u, k), pt(j+1, u, k), (ax, ay)])} Z" fill="{c}" stroke="{c}" stroke-width="0.15"/>')
        if height >= SNOW_FROM:
            u, k = rings[-1]
            edge = []
            for j in range(N + 1):
                bx, by = pt(j, u, k)
                f = rr.uniform(*SNOW_DOWN)
                edge.append((ax + (bx - ax)*f, ay + (by - ay)*f))
            o.append(f'<path d="M{ax:.2f} {ay:.2f} L{path(edge)} Z" fill="{SNOW[0]}"/>')
            o.append(f'<path d="M{ax:.2f} {ay:.2f} L{path(edge[:N//2 + 1])} Z" fill="{SNOW[1]}"/>')
    return draw

def ridge(b, a, c, ha, hc):
    """A lower ridge between two neighbouring mountains, so they read as one range."""
    def draw(o, *_):
        (ax, ay), (bx, by) = b.pos(*a), b.pos(*c)
        h = min(ha, hc)*MOUNTAIN_STONE_H*RIDGE_HEIGHT
        gx, gz = bx - ax, (by - ay)/SQ
        L = math.hypot(gx, gz)
        nx, nz = -gz/L, gx/L
        if nz < 0:
            nx, nz = -nx, -nz
        if abs(nz) < 1e-6:
            nx, nz = 0.0, 1.0
        w, M = R*RIDGE_WIDTH, 6
        rr = random.Random(int(ax*13 + bx*7 + ay))
        crest, foot = [], []
        for j in range(M + 1):
            f = j/M
            x, y = ax + (bx - ax)*f, ay + (by - ay)*f
            crest.append((x + rr.uniform(-0.5, 0.5), y - h*(1 - RIDGE_DIP*math.sin(math.pi*f)) + rr.uniform(-0.6, 0.6)))
            foot.append((x + nx*w, y + nz*w*SQ))
        for j in range(M):
            col = grey(rock(nx*0.7, nz*0.7) + rr.randint(-8, 8))
            o.append(f'<path d="M{path([foot[j], foot[j+1], crest[j+1], crest[j]])} Z" fill="{col}" stroke="{col}" stroke-width="0.15"/>')
    return draw


# ------------------------------------------------------------- flat land

def water(o, b, cells, name):
    """Water as one surface: no seams inside, a bank only where it meets land."""
    cells = set(cells)
    rnd = random.Random(name)
    o.append(f'<clipPath id="clip-{name}">' + ''.join(f'<polygon points="{points(corners(*b.pos(q, r), 1.004))}"/>' for q, r in cells) + '</clipPath>')
    o.append(f'<g clip-path="url(#clip-{name})"><rect width="100" height="100" fill="url(#water)"/>')
    for q, r in sorted(cells):
        cx, cy = b.pos(q, r)
        for _ in range(RIPPLES_PER_HEX):
            x, y, w = cx + rnd.uniform(-0.8, 0.8)*R, cy + rnd.uniform(-0.7, 0.7)*R*SQ, rnd.uniform(1.2, 2.6)
            o.append(f'<path d="M{x-w:.2f} {y:.2f} Q{x:.2f} {y-0.7:.2f} {x+w:.2f} {y:.2f}" fill="none" stroke="{RIPPLE}" '
                     f'stroke-opacity="{rnd.uniform(0.25, 0.55):.2f}" stroke-width="0.3" stroke-linecap="round"/>')
    o.append('</g>')
    for p, q, angle in outer_edges(b, cells):         # the far banks show their earth wall
        if 180 <= angle < 360 or angle == 0:
            o.append(f'<polygon points="{points([p, q, (q[0], q[1]+1.3), (p[0], p[1]+1.3)])}" fill="{BANK_WALL}" opacity="0.8"/>')
    for p, q, _ in outer_edges(b, cells):
        o.append(f'<line x1="{p[0]:.2f}" y1="{p[1]:.2f}" x2="{q[0]:.2f}" y2="{q[1]:.2f}" stroke="{BANK_EDGE}" stroke-opacity="0.7" stroke-width="0.45" stroke-linecap="round"/>')

def _grid(b, cells, dx, dy, rnd, s=0.93):
    xs = [b.pos(*c)[0] for c in cells]
    ys = [b.pos(*c)[1] for c in cells]
    y, row = min(ys) - R*SQ, 0
    while y < max(ys) + R*SQ:
        x = min(xs) - R + (dx/2 if row % 2 else 0)
        while x < max(xs) + R:
            px, py = x + rnd.uniform(-0.3, 0.3)*dx, y + rnd.uniform(-0.2, 0.2)*dy
            if any(inside(px, py, *b.pos(*c), s) for c in cells):
                yield px, py
            x += dx
        y += dy
        row += 1

def _blade(px, py, h, lean, colour, w=0.25):
    return (f'<path d="M{px:.2f} {py:.2f} Q{px+lean*0.2:.2f} {py-h*0.6:.2f} {px+lean:.2f} {py-h:.2f}" '
            f'fill="none" stroke="{colour}" stroke-width="{w}" stroke-linecap="round"/>')

def field(o, b, cells, kind='korn', seed=3):
    """A field: its ground goes onto the board now; what grows on it comes
    back as (y, svg) to be sorted among the things that stand."""
    cells = set(cells)
    st = FIELD[kind]
    rnd = random.Random(seed)
    for q, r in cells:
        o.append(f'<polygon points="{points(corners(*b.pos(q, r), 1.004))}" fill="{st["ground"]}"/>')
    if kind == 'steppe':
        for q, r in cells:
            cx, cy = b.pos(q, r)
            for _ in range(9):
                x, y = cx + rnd.uniform(-0.75, 0.75)*R, cy + rnd.uniform(-0.65, 0.65)*R*SQ
                o.append(f'<ellipse cx="{x:.2f}" cy="{y:.2f}" rx="{rnd.uniform(0.3, 0.7):.2f}" ry="{rnd.uniform(0.18, 0.35):.2f}" fill="{rnd.choice(st["pebbles"])}"/>')
    for p, q, _ in outer_edges(b, cells):
        o.append(f'<line x1="{p[0]:.2f}" y1="{p[1]:.2f}" x2="{q[0]:.2f}" y2="{q[1]:.2f}" stroke="{st["edge"]}" stroke-opacity="0.6" stroke-width="0.4"/>')

    items = []
    lo, hi = st['height']
    for px, py in _grid(b, cells, *st['spacing'], rnd):
        if kind == 'korn':
            h, lean = rnd.uniform(lo, hi), rnd.uniform(-0.45, 0.45)
            tx, ty = px + lean, py - h
            angle = math.degrees(math.atan2(lean, h))
            items.append((py, _blade(px, py, h, lean, st['stalk'], 0.22) +
                          f'<ellipse cx="{tx:.2f}" cy="{ty:.2f}" rx="0.34" ry="0.85" fill="{rnd.choice(st["ears"])}" transform="rotate({angle:.1f} {tx:.2f} {ty:.2f})"/>'))
        elif kind == 'praerie':
            svg = ''.join(_blade(px + rnd.uniform(-0.3, 0.3), py, rnd.uniform(lo, hi), rnd.uniform(-1.0, 1.0), rnd.choice(st['blades']))
                          for _ in range(rnd.randint(3, 5)))
            if rnd.random() < st['flower_share']:
                svg += f'<circle cx="{px+rnd.uniform(-0.4, 0.4):.2f}" cy="{py-rnd.uniform(2.2, 3.0):.2f}" r="0.42" fill="{rnd.choice(st["flowers"])}"/>'
            items.append((py, svg))
        else:
            if rnd.random() > st['tuft_share']:
                continue
            items.append((py, ''.join(_blade(px + rnd.uniform(-0.25, 0.25), py, rnd.uniform(lo, hi), rnd.uniform(-1.2, 1.2), rnd.choice(st['blades']), 0.22)
                                      for _ in range(rnd.randint(3, 6)))))
    return items
