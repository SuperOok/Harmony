"""A nest of twigs on a peak, in two halves so that what sits in it can be
drawn between them: the back rim and the floor first, the animals, then
the front rim over their lower parts. Both are SVG in the world's
coordinates, drawn round the middle of the nest (cx, cy), seen at the
board's slant (SQUASH)."""
import math
import random

from style import SQUASH

RIM = 6.4                     # radius of the nest
TWIGS = ('#6B4A2B', '#8A6540', '#A88256', '#523820', '#77562F')


def _twig(rnd, cx, cy, a, lift):
    """One twig on the rim at angle a, lying roughly along it."""
    r = RIM*rnd.uniform(0.88, 1.12)
    x, y = cx + r*math.cos(a), cy + r*math.sin(a)*SQUASH*1.0 - lift
    tangent = a + math.pi/2 + rnd.uniform(-0.55, 0.55)
    length = rnd.uniform(1.8, 3.4)
    dx, dy = math.cos(tangent)*length, math.sin(tangent)*length*SQUASH
    w = rnd.uniform(0.3, 0.55)
    return (f'<path d="M{x - dx/2:.2f} {y - dy/2:.2f} L{x + dx/2:.2f} {y + dy/2:.2f}" stroke="{rnd.choice(TWIGS)}" '
            f'stroke-width="{w:.2f}" stroke-linecap="round" fill="none"/>')


def nest_back(cx, cy, seed=4):
    """The floor and the far half of the rim."""
    rnd = random.Random(seed)
    o = [f'<ellipse cx="{cx:.2f}" cy="{cy + 0.4:.2f}" rx="{RIM + 1.6:.2f}" ry="{(RIM + 1.6)*SQUASH:.2f}" fill="#000" opacity="0.28"/>',
         f'<ellipse cx="{cx:.2f}" cy="{cy:.2f}" rx="{RIM:.2f}" ry="{RIM*SQUASH:.2f}" fill="#3A2A1A"/>',
         f'<ellipse cx="{cx:.2f}" cy="{cy:.2f}" rx="{RIM*0.75:.2f}" ry="{RIM*0.75*SQUASH:.2f}" fill="#53402A" opacity="0.8"/>']
    for k in range(46):
        a = math.pi + math.pi*(k + rnd.uniform(0, 1))/46
        o.append(_twig(rnd, cx, cy, a, rnd.uniform(0, 1.3)))
    return '\n'.join(o)


def nest_front(cx, cy, seed=5):
    """The near half of the rim, two courses of twigs, a few sticking out."""
    rnd = random.Random(seed)
    o = []
    for course, lift in ((0, 0.0), (1, 0.9)):
        n = 40
        for k in range(n):
            a = math.pi*(k + rnd.uniform(0, 1))/n
            o.append(_twig(rnd, cx, cy + 0.4, a, lift + rnd.uniform(0, 0.4)))
    for k in range(7):                     # sticks standing out over the edge
        a = rnd.uniform(0.15, math.pi - 0.15)
        x, y = cx + RIM*1.02*math.cos(a), cy + RIM*1.02*math.sin(a)*SQUASH
        o.append(f'<path d="M{x:.2f} {y:.2f} L{x + math.cos(a)*rnd.uniform(1.5, 3):.2f} {y + rnd.uniform(-0.8, 1.2):.2f}" '
                 f'stroke="{rnd.choice(TWIGS)}" stroke-width="{rnd.uniform(0.3, 0.5):.2f}" stroke-linecap="round"/>')
    return '\n'.join(o)
