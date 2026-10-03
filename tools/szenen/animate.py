"""The first squirrel's animation as an animated SVG (SMIL), for looking at
in a browser before it goes to SwiftUI.

    python3 tools/szenen/animate.py

The camera starts close on the tree's crown. The squirrel jumps in, stops,
the camera pulls back, once; it runs across the crown, leaps down onto the
roof, runs down the ridge and settles on its house, the landscape the cube
lies on, and nibbles its nut; then the camera pulls back a second time, to
show all three houses of the habitat.

Every moving value is computed frame by frame here and written as a list
of values with linear timing, so the SVG holds no logic of its own and
the same timeline can drive SwiftUI later.
"""
import math
import os

from cards import build, PORTRAIT
from scene import OUT
from figures import squirrel_body, SIZE, SQUIRREL_FEET, SQUIRREL_TAIL_ROOT
from style import HOUSE_H, ROOF_RISE, EAVE_RX, STONE_RX, STONE_RY, STONE_H, CROWN

FPS = 25
LENGTH = 13.5            # seconds, then it starts again


def ease(u): return u*u*(3 - 2*u)
def lerp(a, b, u): return a + (b - a)*u


def frame(cx, cy, w):
    h = w*PORTRAIT
    return (cx - w/2, cy - h/2, w, h)


def lerp_view(a, b, u): return tuple(lerp(p, q, u) for p, q in zip(a, b))


def timeline(house, tree, scale, cube_feet):
    """The squirrel's feet, which way it faces, how it is squashed, where its
    nut is, the tail's swing, the blink and the camera, for every frame."""
    hx, hy = house
    eave_ry = EAVE_RX*STONE_RY/STONE_RX
    yb = hy - HOUSE_H
    ridge_mid = (hx, yb - ROOF_RISE + 0.6)
    ridge_back = (hx, yb - ROOF_RISE - eave_ry*0.75 + 0.6)
    tx, ty = tree
    crown_foot = ty - 2*STONE_H
    def on_clump(k):                            # standing on top of a clump of the crown
        dx, dy, r, _ = CROWN[k]
        return (tx + dx, crown_foot + dy - r + 0.5)
    perch = on_clump(5)                          # front left
    crown_path = [perch, on_clump(7), on_clump(6)]   # over the top to the front right
    start = (perch[0] - 9, perch[1] + 3)

    body = 70*scale
    close = frame(perch[0], perch[1] - body*0.6, body*3.4)
    wide = frame((hx + tx)/2 - 1, (perch[1] + hy)/2 + 1.5, 26)

    # the last pull-back: all three houses of the habitat, the outer two a
    # little more than half in the picture
    xs = [x for x, _ in cube_feet]
    span = max(xs) - min(xs) + 3
    habitat = frame((max(xs) + min(xs))/2, hy - 0.42*span*PORTRAIT + 6, span)

    def jump(a, b, u, height):
        x = lerp(a[0], b[0], u)
        y = lerp(a[1], b[1], u) - height*4*u*(1 - u)
        return x, y

    frames = []
    for i in range(int(LENGTH*FPS)):
        t = i/FPS
        face, sx, sy, nut, tail, blink, airborne = 1, 1.0, 1.0, (0, 0), 0.0, 1.0, False
        view, alpha = close, 1
        if t < 0.4:                                  # the empty crown
            feet, alpha = start, 0
        elif t < 1.2:                                # jumps in from the left onto the crown
            u = (t - 0.4)/0.8
            feet = jump(start, perch, ease(u), 5)
            airborne = 0.1 < u < 0.95
            sx, sy = (0.92, 1.1) if airborne else (1, 1)
            alpha = min(1, (t - 0.4)/0.15)
        elif t < 1.45:                               # lands: squash and back
            feet = perch
            sq = math.sin(math.pi*(t - 1.2)/0.25)
            sx, sy = 1 + 0.14*sq, 1 - 0.16*sq
        elif t < 2.6:                                # stops, looks, blinks, flicks its tail
            feet = perch
            tail = 8*math.sin((t - 1.45)*7)*math.exp(-(t - 1.45)*1.5)
            blink = 0.1 if 2.0 < t < 2.12 else 1
        elif t < 4.2:                                # the camera pulls back: there is the house
            feet = perch
            view = lerp_view(close, wide, ease((t - 2.6)/1.6))
            tail = 3*math.sin((t - 2.6)*4)
        elif t < 5.8:                                # runs across the crown from clump to clump
            view = wide
            u = (t - 4.2)/1.6*(len(crown_path) - 1)
            k = min(int(u), len(crown_path) - 2)
            a_, b_ = crown_path[k], crown_path[k + 1]
            v = u - k
            hop = abs(math.sin(v*math.pi*2))
            x, y = lerp(a_[0], b_[0], v), lerp(a_[1], b_[1], v)
            feet = (x, y - 0.9*hop)
            sx, sy = 1 + 0.06*(1 - hop), 1 - 0.06*(1 - hop)
            tail = 10*hop
        elif t < 6.05:                               # crouches at the edge of the crown, turns to the roof
            view, feet, face = wide, crown_path[-1], -1
            sq = math.sin(math.pi*(t - 5.8)/0.25*0.5)
            sx, sy = 1 + 0.12*sq, 1 - 0.18*sq
        elif t < 6.85:                               # leaps down onto the back of the roof
            view, face = wide, -1
            u = (t - 6.05)/0.8
            feet = jump(crown_path[-1], ridge_back, ease(u), 4)
            sx, sy, tail, airborne = 0.9, 1.12, -12, True
        elif t < 7.15:                               # lands on the ridge
            view, face, feet = wide, -1, ridge_back
            sq = math.sin(math.pi*(t - 6.85)/0.3)
            sx, sy = 1 + 0.16*sq, 1 - 0.18*sq
        elif t < 8.0:                                # runs down the ridge in little hops
            view, face = wide, -1
            u = (t - 7.15)/0.85
            x, y = lerp(ridge_back[0], ridge_mid[0], u), lerp(ridge_back[1], ridge_mid[1], u)
            hop = abs(math.sin(u*math.pi*3))
            feet = (x, y - 0.7*hop)
            sx, sy = 1 + 0.06*(1 - hop), 1 - 0.06*(1 - hop)
            tail = 10*hop
        else:                                        # turns round on its house, settles and nibbles
            feet = ridge_mid
            view = lerp_view(wide, habitat, ease(min(1, max(0, (t - 9.0)/2.2))))
            face = 1 if t > 8.3 else -1
            tail = 4*math.sin((t - 8.0)*2.2)
            n = t - 8.7
            if n > 0:
                lift = min(1, n/0.35)
                nibble = 0.9*abs(math.sin(n*14)) if n > 0.35 else 0
                nut = (-1.5*lift, -6*lift + nibble)
            blink = 0.1 if 10.5 < t < 10.62 else 1
            if t > LENGTH - 0.5:
                alpha = (LENGTH - t)/0.5
        frames.append(dict(feet=feet, face=face, sx=sx, sy=sy, nut=nut, tail=tail,
                           blink=blink, view=view, alpha=alpha, airborne=airborne))
    return frames, wide


def smil(attr, values, kind=None, extra=''):
    vals = ';'.join(values)
    if kind:
        return (f'<animateTransform attributeName="transform" type="{kind}" values="{vals}" '
                f'dur="{LENGTH}s" repeatCount="indefinite" calcMode="linear"{extra}/>')
    return f'<animate attributeName="{attr}" values="{vals}" dur="{LENGTH}s" repeatCount="indefinite" calcMode="linear"{extra}/>'


def main():
    s, layout, cubes, cams = build('Eichhörnchen', arrived=0)
    scale = SIZE['Eichhörnchen']
    house = s.b.pos(*cubes[0])
    tree_cell = next(c for c, v in layout.items() if v.startswith('Baum'))
    tree = s.b.pos(*tree_cell)
    frames, wide = timeline(house, tree, scale, [s.b.pos(*c) for c in cubes])

    # the scene is drawn for the widest framing, then the camera moves in it
    svg = s.svg(cams['mittel'], width=None)
    head, tail_ = svg.rsplit('</svg>', 1)
    first = head.index('>') + 1
    views = [' '.join(f'{v:.3f}' for v in f['view']) for f in frames]
    head = head[:first] + smil('viewBox', views) + head[first:]

    fx, fy = SQUIRREL_FEET
    rx, ry = SQUIRREL_TAIL_ROOT
    anim = {
        'tail': smil(None, [f'{f["tail"]:.2f} {rx} {ry}' for f in frames], 'rotate'),
        'nut': smil(None, [f'{f["nut"][0]:.2f} {f["nut"][1]:.2f}' for f in frames], 'translate'),
        'eye': smil(None, [f'1 {f["blink"]:.2f}' for f in frames], 'scale'),
    }
    o = []
    # shadow under the feet while on something; gone in the air
    o.append('<ellipse rx="1.0" ry="0.25" fill="#000">'
             + smil('cx', [f'{f["feet"][0]:.3f}' for f in frames])
             + smil('cy', [f'{f["feet"][1] + 0.05:.3f}' for f in frames])
             + smil('opacity', [f'{0 if f["airborne"] else 0.3*f["alpha"]:.2f}' for f in frames]) + '</ellipse>')
    o.append('<g>' + smil(None, [f'{f["feet"][0]:.3f} {f["feet"][1]:.3f}' for f in frames], 'translate')
             + smil('opacity', [f'{f["alpha"]:.2f}' for f in frames]))
    o.append('<g>' + smil(None, [f'{f["face"]*f["sx"]*scale:.4f} {f["sy"]*scale:.4f}' for f in frames], 'scale'))
    o.append(f'<g transform="translate({-fx} {-fy})">' + squirrel_body(anim, shadow=False) + '</g></g></g>')
    out = head + '\n'.join(o) + '</svg>' + tail_
    os.makedirs(OUT, exist_ok=True)           # a fresh clone has no out/ yet
    p = os.path.join(OUT, 'eichhoernchen-animation.svg')
    with open(p, 'w') as fh:
        fh.write(out)
    print(p)


if __name__ == '__main__':
    main()
