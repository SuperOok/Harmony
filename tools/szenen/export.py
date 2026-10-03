"""Writes a scene as a display list for the app, a JSON file SwiftUI draws
with `Canvas` (MyApp/Szenen/).

    python3 tools/szenen/export.py

The scene is drawn by the same Python code as the SVGs. Here its SVG is
read back and flattened into shapes (paths of M, L, Q, C and Z, nothing
else), gradients, clips and named groups, in drawing order. What moves
(the squirrel's tail, nut and eye, the camera) is not in the list: the app
computes it, from the anchors written alongside (`SquirrelTimeline.swift`).
"""
import json
import math
import os
import re
import sys
import xml.etree.ElementTree as ET

from animate import anchors
from cards import build
from figures import (SIZE, SQUIRREL_FEET, SQUIRREL_TAIL_ROOT, SQUIRREL_EYE,
                     figure_defs, squirrel_body)

APP = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'MyApp', 'Szenen')
KAPPA = 0.5522847498

NS = '{http://www.w3.org/2000/svg}'


def tag(e): return e.tag.replace(NS, '')


def num(v): return round(v, 3) + 0.0


def colour(c):
    """#RGB written out as #RRGGBB, which is all the app reads."""
    c = c.upper()
    if re.fullmatch(r'#[0-9A-F]{3}', c):
        c = '#' + ''.join(ch*2 for ch in c[1:])
    assert re.fullmatch(r'#[0-9A-F]{6}', c), c
    return c


# ------------------------------------------------------------- paths

def ellipse_path(cx, cy, rx, ry):
    kx, ky = rx*KAPPA, ry*KAPPA
    return [('M', cx + rx, cy),
            ('C', cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry),
            ('C', cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy),
            ('C', cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry),
            ('C', cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy), ('Z',)]


def arc(x0, y0, rx, ry, large, sweep, x1, y1):
    """An SVG arc without rotation, as cubic Béziers."""
    if rx == 0 or ry == 0 or (x0, y0) == (x1, y1):
        return [('L', x1, y1)]
    dx, dy = (x0 - x1)/2, (y0 - y1)/2
    lam = (dx/rx)**2 + (dy/ry)**2
    if lam > 1:
        rx, ry = rx*math.sqrt(lam), ry*math.sqrt(lam)
    num_ = (rx*ry)**2 - (rx*dy)**2 - (ry*dx)**2
    den = (rx*dy)**2 + (ry*dx)**2
    co = math.sqrt(max(0, num_/den))*(-1 if large == sweep else 1)
    cxp, cyp = co*rx*dy/ry, -co*ry*dx/rx
    cx, cy = cxp + (x0 + x1)/2, cyp + (y0 + y1)/2
    a0 = math.atan2((dy - cyp)/ry, (dx - cxp)/rx)
    a1 = math.atan2((-dy - cyp)/ry, (-dx - cxp)/rx)
    d = a1 - a0
    if sweep and d < 0:
        d += 2*math.pi
    if not sweep and d > 0:
        d -= 2*math.pi
    n = max(1, math.ceil(abs(d)/(math.pi/2) - 1e-9))
    step = d/n
    k = 4/3*math.tan(step/4)
    out = []
    for i in range(n):
        s, e = a0 + i*step, a0 + (i + 1)*step
        p1 = (cx + rx*(math.cos(s) - k*math.sin(s)), cy + ry*(math.sin(s) + k*math.cos(s)))
        p2 = (cx + rx*(math.cos(e) + k*math.sin(e)), cy + ry*(math.sin(e) - k*math.cos(e)))
        p3 = (cx + rx*math.cos(e), cy + ry*math.sin(e))
        out.append(('C', *p1, *p2, *p3))
    out[-1] = out[-1][:5] + (x1, y1)
    return out


def parse_path(d):
    toks = re.findall(r'[MLQCAZVH]|-?\d*\.?\d+(?:e-?\d+)?', d)
    segs, i, cmd = [], 0, None
    x = y = sx = sy = 0.0
    def nums(n):
        nonlocal i
        v = [float(t) for t in toks[i:i + n]]
        i += n
        return v
    while i < len(toks):
        if re.match(r'[MLQCAZVH]', toks[i]):
            cmd = toks[i]
            i += 1
            if cmd == 'Z':
                segs.append(('Z',))
                x, y = sx, sy
                continue
        if cmd == 'M':
            x, y = nums(2)
            sx, sy = x, y
            segs.append(('M', x, y))
            cmd = 'L'
        elif cmd == 'L':
            x, y = nums(2)
            segs.append(('L', x, y))
        elif cmd == 'H':
            x, = nums(1)
            segs.append(('L', x, y))
        elif cmd == 'V':
            y, = nums(1)
            segs.append(('L', x, y))
        elif cmd == 'Q':
            v = nums(4)
            segs.append(('Q', *v))
            x, y = v[2], v[3]
        elif cmd == 'C':
            v = nums(6)
            segs.append(('C', *v))
            x, y = v[4], v[5]
        elif cmd == 'A':
            rx, ry, _rot, large, sweep, ex, ey = nums(7)
            segs += arc(x, y, rx, ry, int(large), int(sweep), ex, ey)
            x, y = ex, ey
    return segs


def flatten(segs):
    """Points along a path, for its bounding box."""
    pts, x, y = [], 0.0, 0.0
    for s in segs:
        if s[0] in 'ML':
            x, y = s[1], s[2]
            pts.append((x, y))
        elif s[0] == 'Q':
            for k in range(1, 9):
                t = k/8
                pts.append(((1-t)**2*x + 2*(1-t)*t*s[1] + t*t*s[3], (1-t)**2*y + 2*(1-t)*t*s[2] + t*t*s[4]))
            x, y = s[3], s[4]
        elif s[0] == 'C':
            for k in range(1, 17):
                t = k/16
                a, b, c, d = (1-t)**3, 3*(1-t)**2*t, 3*(1-t)*t*t, t**3
                pts.append((a*x + b*s[1] + c*s[3] + d*s[5], a*y + b*s[2] + c*s[4] + d*s[6]))
            x, y = s[5], s[6]
    return pts


def path_string(segs):
    return ' '.join(' '.join([s[0]] + [f'{num(v):g}' for v in s[1:]]) for s in segs)


def bbox(segs):
    pts = flatten(segs)
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return [num(min(xs)), num(min(ys)), num(max(xs) - min(xs)), num(max(ys) - min(ys))]


# ------------------------------------------------------------- transforms

def matmul(a, b):
    """a after b."""
    return [a[0]*b[0] + a[2]*b[1], a[1]*b[0] + a[3]*b[1],
            a[0]*b[2] + a[2]*b[3], a[1]*b[2] + a[3]*b[3],
            a[0]*b[4] + a[2]*b[5] + a[4], a[1]*b[4] + a[3]*b[5] + a[5]]


def parse_transform(t):
    m = [1, 0, 0, 1, 0, 0]
    for name, args in re.findall(r'(\w+)\(([^)]*)\)', t):
        v = [float(a) for a in re.split(r'[ ,]+', args.strip())]
        if name == 'translate':
            n = [1, 0, 0, 1, v[0], v[1] if len(v) > 1 else 0]
        elif name == 'scale':
            n = [v[0], 0, 0, v[1] if len(v) > 1 else v[0], 0, 0]
        elif name == 'rotate':
            c, s = math.cos(math.radians(v[0])), math.sin(math.radians(v[0]))
            n = [c, s, -s, c, 0, 0]
            if len(v) == 3:
                n = matmul([1, 0, 0, 1, v[1], v[2]], matmul(n, [1, 0, 0, 1, -v[1], -v[2]]))
        else:
            raise SystemExit(f'transform {name}')
        m = matmul(m, n)
    return m


# ------------------------------------------------------------- the walk

class Exporter:
    def __init__(self):
        self.gradients = {}
        self.clips = {}

    def read_defs(self, root):
        for e in root.iter():
            t = tag(e)
            if t in ('linearGradient', 'radialGradient'):
                stops = [[float(s.get('offset')), colour(s.get('stop-color')), float(s.get('stop-opacity', 1))]
                         for s in e if tag(s) == 'stop']
                user = e.get('gradientUnits') == 'userSpaceOnUse'
                if t == 'linearGradient':
                    a = [float(e.get(k, dflt)) for k, dflt in (('x1', 0), ('y1', 0), ('x2', 1), ('y2', 0))]
                    self.gradients[e.get('id')] = dict(k='l', u=user, a=a, s=stops)
                else:
                    a = [float(e.get(k, 0.5)) for k in ('cx', 'cy', 'r')]
                    self.gradients[e.get('id')] = dict(k='r', u=user, a=a, s=stops)
            elif t == 'clipPath':
                segs = []
                for p in e:
                    segs += shape_segs(p)
                self.clips[e.get('id')] = segs

    def element(self, e):
        """A list of nodes for this element, in drawing order."""
        t = tag(e)
        if t in ('defs', 'clipPath', 'desc'):
            return []
        if t == 'g':
            kids = []
            name = None
            for c in e:
                if tag(c) == 'desc':
                    name = c.text
                else:
                    kids += self.element(c)
            node = {}
            if e.get('transform'):
                node['m'] = [num(v) for v in parse_transform(e.get('transform'))]
            if e.get('clip-path'):
                cid = re.search(r'#([^)]+)', e.get('clip-path')).group(1)
                node['clip'] = path_string(self.clips[cid])
            if name:
                node['id'] = name
            if not node:
                return kids          # a plain group adds nothing
            node['g'] = kids
            return [node]
        segs = shape_segs(e)
        if not segs:
            return []
        node = {'d': path_string(segs)}
        if e.get('transform'):
            node['m'] = [num(v) for v in parse_transform(e.get('transform'))]
        fill = e.get('fill', '#000000')
        op = float(e.get('opacity', 1))
        if fill != 'none':
            if fill.startswith('url('):
                gid = re.search(r'#([^)]+)', fill).group(1)
                node['f'] = '@' + gid
                if not self.gradients[gid]['u']:
                    node['bb'] = bbox(segs)
            else:
                node['f'] = colour(fill)
            fo = float(e.get('fill-opacity', 1))*op
            if fo != 1:
                node['fo'] = num(fo)
        if e.get('stroke'):
            node['s'] = colour(e.get('stroke'))
            node['sw'] = num(float(e.get('stroke-width', 1)))
            so = float(e.get('stroke-opacity', 1))*op
            if so != 1:
                node['so'] = num(so)
            if e.get('stroke-linecap') == 'round':
                node['cap'] = 'round'
            if e.get('stroke-linejoin') == 'round':
                node['join'] = 'round'
        if 'f' not in node and 's' not in node:
            return []
        return [node]


def shape_segs(e):
    t = tag(e)
    f = lambda k, d=0: float(e.get(k, d))
    if t == 'rect':
        x, y, w, h = f('x'), f('y'), f('width'), f('height')
        rx = f('rx')
        if rx:
            r = rx
            return (parse_path(f'M{x+r} {y} L{x+w-r} {y} A{r} {r} 0 0 1 {x+w} {y+r} L{x+w} {y+h-r} '
                               f'A{r} {r} 0 0 1 {x+w-r} {y+h} L{x+r} {y+h} A{r} {r} 0 0 1 {x} {y+h-r} '
                               f'L{x} {y+r} A{r} {r} 0 0 1 {x+r} {y} Z'))
        return [('M', x, y), ('L', x + w, y), ('L', x + w, y + h), ('L', x, y + h), ('Z',)]
    if t == 'circle':
        return ellipse_path(f('cx'), f('cy'), f('r'), f('r'))
    if t == 'ellipse':
        return ellipse_path(f('cx'), f('cy'), f('rx'), f('ry'))
    if t == 'line':
        return [('M', f('x1'), f('y1')), ('L', f('x2'), f('y2'))]
    if t == 'polygon':
        pts = [tuple(map(float, p.split(','))) for p in e.get('points').split()]
        return [('M', *pts[0])] + [('L', *p) for p in pts[1:]] + [('Z',)]
    if t == 'path':
        return parse_path(e.get('d'))
    raise SystemExit(f'element {t}')


def read(svg_text):
    return ET.fromstring(svg_text)


def main():
    name = 'Eichhörnchen'
    s, layout, cubes, cams = build(name, arrived=0)
    scale = SIZE[name]
    view = cams['weit']                      # the widest framing: nothing beyond it is ever seen
    ex = Exporter()

    root = read(s.svg(view, width=None))
    ex.read_defs(root)
    scene_ops = []
    for e in root:
        scene_ops += ex.element(e)

    fig = ET.fromstring('<svg xmlns="http://www.w3.org/2000/svg"><defs>' + ''.join(figure_defs()) + '</defs>'
                        + '<g>' + squirrel_body({'tail': '<desc>tail</desc>', 'nut': '<desc>nut</desc>',
                                                 'eye': '<desc>eye</desc>'}, shadow=False) + '</g></svg>')
    ex.read_defs(fig)
    squirrel_ops = []
    for e in fig:
        squirrel_ops += ex.element(e)

    house = s.b.pos(*cubes[0])
    tree = s.b.pos(*next(c for c, v in layout.items() if v.startswith('Baum')))
    a = anchors(house, tree, scale, [s.b.pos(*c) for c in cubes])
    used = set()
    def collect(ops):
        for o in ops:
            if o.get('f', '').startswith('@'):
                used.add(o['f'][1:])
            collect(o.get('g', []))
    collect(scene_ops)
    collect(squirrel_ops)
    ex.gradients = {k: v for k, v in ex.gradients.items() if k in used}   # not the other animals' shades
    out = dict(
        view=[num(v) for v in view],
        background='#22313A',
        gradients=ex.gradients,
        scene=scene_ops,
        squirrel=dict(ops=squirrel_ops, scale=scale, feet=list(SQUIRREL_FEET),
                      tailRoot=list(SQUIRREL_TAIL_ROOT), eye=list(SQUIRREL_EYE)),
        anchors={k: ([[num(x) for x in p] for p in v] if k == 'crown_path' else [num(x) for x in v])
                 for k, v in a.items()},
    )
    os.makedirs(APP, exist_ok=True)
    p = os.path.join(APP, 'szene-eichhoernchen.json')
    with open(p, 'w') as fh:
        json.dump(out, fh, separators=(',', ':'), ensure_ascii=False)
    n = lambda ops: sum(1 + (n(o['g']) if 'g' in o else 0) for o in ops)
    print(p, os.path.getsize(p)//1024, 'KB,', n(scene_ops), 'Knoten Szene,', n(squirrel_ops), 'Knoten Tier')


if __name__ == '__main__':
    main()
