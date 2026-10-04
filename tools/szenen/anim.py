"""Writes an animal's animation as an animated SVG (SMIL), the way
animate.py does for the squirrel but for any figure.

A story (stories.py) hands over one dict per frame: where the feet are,
which way it faces, how it is squashed, the camera and the values of the
figure's named parts. The same numbers can drive SwiftUI later.

    python3 tools/szenen/stories.py Ente
"""
import os

from cards import PORTRAIT
from scene import OUT

FPS = 25


def ease(u): return u*u*(3 - 2*u)
def lerp(a, b, u): return a + (b - a)*u
def clamp(u): return max(0.0, min(1.0, u))
def lerp_view(a, b, u): return tuple(lerp(p, q, u) for p, q in zip(a, b))
def lerp2(a, b, u): return (lerp(a[0], b[0], u), lerp(a[1], b[1], u))


def frame(cx, cy, w):
    """A phone-shaped camera framing, w wide."""
    h = w*PORTRAIT
    return (cx - w/2, cy - h/2, w, h)


def jump(a, b, u, height):
    """From a to b in an arc."""
    x, y = lerp2(a, b, u)
    return x, y - height*4*u*(1 - u)


def smil(values, length, attr=None, kind=None, extra=''):
    n = len(values)
    keys = ''
    if len(set(values)) == 1:              # nothing moves: two values do as well as hundreds
        values = values[:2]
    else:                                  # a long rest at either end needs no values
        a = next(i for i in range(n) if values[i] != values[0])
        b = next(i for i in range(n - 1, -1, -1) if values[i] != values[-1])
        if a > 2 or b < n - 3:
            lo, hi = max(a - 1, 0), min(b + 1, n - 1)
            idx = ([0] if lo > 0 else []) + list(range(lo, hi + 1)) + ([n - 1] if hi < n - 1 else [])
            keys = ' keyTimes="' + ';'.join(f'{i/(n - 1):.4f}' for i in idx) + '"'
            values = [values[i] for i in idx]
    vals = ';'.join(values)
    common = f'values="{vals}"{keys} dur="{length}s" repeatCount="indefinite" calcMode="linear"{extra}'
    if kind:
        return f'<animateTransform attributeName="transform" type="{kind}" {common}/>'
    return f'<animate attributeName="{attr}" {common}/>'


def part_values(kind, frames, name, pivot):
    """SMIL values for one part. rotate: degrees; translate: (x, y);
    scale: (sx, sy); path: the path data."""
    out = []
    for f in frames:
        v = f['parts'].get(name)
        if kind == 'path':
            out.append(v)
        elif kind == 'rotate':
            out.append(f'{(v or 0):.2f} {pivot[0]} {pivot[1]}')
        elif kind == 'translate':
            x, y = v or (0, 0)
            out.append(f'{x:.2f} {y:.2f}')
        else:
            sx, sy = v or (1, 1)
            out.append(f'{sx:.3f} {sy:.3f}')
    return out


def _figure(frames, length, body, parts, scale, feet, shadow):
    """One figure's moving SVG: its shadow on the ground and the figure
    itself, placed, turned and squashed by each frame."""
    fx, fy = feet
    # a part is a transform (rotate, translate, scale) or, for a shape that
    # changes its outline from frame to frame, its path data (`path`)
    anim = {name: (smil(part_values(kind, frames, name, pivot), length, attr='d') if kind == 'path'
                   else smil(part_values(kind, frames, name, pivot), length, kind=kind))
            for name, (kind, pivot) in parts.items()}
    o = []
    # the shadow lies on what the animal stands on (`ground`), not under it
    # while it flies; `shadow` in a frame scales it, none at all on water
    if shadow:
        sx, sy = shadow
        ground = [f.get('ground', f['feet']) for f in frames]
        o.append(f'<ellipse rx="{sx}" ry="{sy}" fill="#000">'
                 + smil([f'{g[0]:.3f}' for g in ground], length, attr='cx')
                 + smil([f'{g[1] + 0.05:.3f}' for g in ground], length, attr='cy')
                 + smil([f'{(0 if f["airborne"] else 0.3)*f["alpha"]*f.get("shadow", 1):.2f}' for f in frames],
                        length, attr='opacity') + '</ellipse>')
    o.append('<g>' + smil([f'{f["feet"][0]:.3f} {f["feet"][1]:.3f}' for f in frames], length, kind='translate')
             + smil([f'{f["alpha"]:.2f}' for f in frames], length, attr='opacity'))
    # heading: the figure turned about its feet (the feet are the origin here)
    o.append('<g>' + smil([f'{f.get("rot", 0):.2f} 0 0' for f in frames], length, kind='rotate'))
    o.append('<g>' + smil([f'{f["face"]*f["sx"]*scale:.4f} {f["sy"]*scale:.4f}' for f in frames], length, kind='scale'))
    o.append(f'<g transform="translate({-fx} {-fy})">' + body(anim, shadow=False) + '</g></g></g></g>')
    return '\n'.join(o)


def write(filename, scene, drawn_view, frames, length, body, parts, scale, feet,
          shadow=(1.0, 0.25), below=None, depth=None, others=()):
    """The scene seen through the moving camera, the figure on top.

    body(anim, shadow=False) draws the figure in its design space with SMIL
    `anim[name]` put into each named part. `parts` says what each part is:
    {name: (kind, pivot)}. `below(frames)` may return SVG for the world
    (rings on water and the like), drawn under the figure. With `depth` (a
    y in the drawing) the figure is drawn among the things that stand there,
    so what lies nearer, grain say, is drawn over it; without, on top.
    `others` are further figures, each a dict(frames, body, parts, scale,
    feet, shadow), drawn over the first in the order given; the camera
    follows the first one's frames."""
    o = []
    if below:
        o.append(below(frames))
    o.append(_figure(frames, length, body, parts, scale, feet, shadow))
    for x in others:
        o.append(_figure(x['frames'], length, x['body'], x['parts'], x['scale'], x['feet'], x.get('shadow')))
    piece = '\n'.join(o)
    svg = scene.svg(drawn_view, width=None, inject=[(depth, piece)] if depth is not None else ())
    head, tail_ = svg.rsplit('</svg>', 1)
    first = head.index('>') + 1
    views = [' '.join(f'{v:.3f}' for v in f['view']) for f in frames]
    head = head[:first] + smil(views, length, attr='viewBox') + head[first:]
    out = head + ('' if depth is not None else piece) + '</svg>' + tail_
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, filename)
    with open(p, 'w') as fh:
        fh.write(out)
    return p


def base_frame(view):
    """What a frame holds unless a story says otherwise."""
    return dict(feet=(0, 0), face=1, sx=1.0, sy=1.0, alpha=1.0, airborne=False, view=view, parts={})
