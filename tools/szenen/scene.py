"""Puts landscapes on the board and writes the scene as SVG.

    python3 tools/szenen/scene.py                 # the sample scene
    python3 tools/szenen/scene.py --feld steppe   # with another field

Output goes to tools/szenen/out/ (not checked in). Look at it with
`qlmanage -t -s 1000 -o <dir> <file>.svg`, which renders a PNG.
Scenes per animal card come later, built on Scene.
"""
import argparse
import math
import os

from style import BACKGROUND, HAZE_TOP, FADE_PER_ROW
from figures import figure_defs
from landscapes import (Board, NEIGHBOURS, ROW, defs, board, building, tree, mountain, ridge,
                        water, field, sky)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')


class Scene:
    def __init__(self, board_=None):
        self.b = board_ or Board()
        self.things = {}       # (q, r): draw function
        self.peaks = {}        # (q, r): height
        self.waters = []       # (cells, name)
        self.fields = []       # (cells, kind)
        self.animals = []      # ((q, r), draw function taking o, x, y of the feet)
        self.fade = FADE_PER_ROW
        self.horizon = HAZE_TOP

    def building(self, q, r, base='stone'): self.things[(q, r)] = building(base)
    def tree(self, q, r, height): self.things[(q, r)] = tree(height, q*13 + r*7)
    def water(self, cells, name): self.waters.append((cells, name))
    def field(self, cells, kind='korn'): self.fields.append((cells, kind))
    def mountain(self, q, r, height):
        self.peaks[(q, r)] = height
        self.things[(q, r)] = mountain(height, q*31 + r*7 + height)

    def svg(self, view=(0, 0, 100, 100), width=1000):
        """The scene through a camera: view is (x, y, w, h) in drawing units."""
        b = self.b
        vx, vy, vw, vh = view
        size = 'width="100%" height="100%"' if width is None else f'width="{width}" height="{round(width*vh/vw)}"'
        o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vx:.2f} {vy:.2f} {vw:.2f} {vh:.2f}" {size}>']
        o += defs(self.fade, self.horizon)
        o += ['<defs>'] + figure_defs() + ['</defs>']
        o.append(f'<rect x="{vx-1:.2f}" y="{vy-1:.2f}" width="{vw+2:.2f}" height="{vh+2:.2f}" fill="{BACKGROUND}"/>')
        board(o, b, view, self.fade, self.horizon)

        # Flat land lies on the board.
        for cells, name in self.waters:
            water(o, b, cells, name)
        items = []
        for cells, kind in self.fields:
            items += field(o, b, cells, kind)

        # Everything standing up, back to front. A ridge comes just before
        # the farther of its two mountains.
        for (q, r), draw in self.things.items():
            cx, cy = b.pos(q, r)
            g = []
            draw(g, cx, cy)
            items.append((cy + 0.001*q, g))
        for (q, r), (draw, x, y) in self.animals:
            g = []
            draw(g, x, y)
            items.append((b.pos(q, r)[1] + 0.005, g))
        done = set()
        for (q, r), h in self.peaks.items():
            for dq, dr in NEIGHBOURS.values():
                n = (q + dq, r + dr)
                if n in self.peaks and frozenset([(q, r), n]) not in done:
                    done.add(frozenset([(q, r), n]))
                    g = []
                    ridge(b, (q, r), n, h, self.peaks[n])(g)
                    far = min((q, r), n, key=lambda c: b.pos(*c)[1])
                    items.append((b.pos(*far)[1] - 0.01, g))

        # Haze without filters (WebKit gives up on filters at high zoom):
        # between the rows a veil of the background colour over everything
        # that lies farther up the screen. Whatever is drawn after a veil,
        # nearer, is spared it; whatever was drawn before gets one veil more
        # for every row it lies behind.
        top = min(vy, self.horizon[0]) - 60
        veil = 1 - math.sqrt(1 - self.fade)            # per half row
        y = b.oy - ROW/4
        while y > top:
            items.append((y, f'<rect x="{vx-1:.2f}" y="{top:.2f}" width="{vw+2:.2f}" height="{y-top:.2f}" fill="{BACKGROUND}" opacity="{veil:.3f}"/>'))
            y -= ROW/2
        for item in sorted(items, key=lambda e: e[0]):
            o += [item[1]] if isinstance(item[1], str) else item[1]

        top = min(vy, self.horizon[0]) - 1
        o.append(f'<rect x="{vx-1:.2f}" y="{top:.2f}" width="{vw+2:.2f}" height="{self.horizon[1]-top:.2f}" fill="url(#haze)"/>')
        sky(o, view, (self.horizon[0], self.horizon[0] + 6))   # stars stay above the haze
        o.append('</svg>')
        return '\n'.join(o)

    def write(self, name, view=(0, 0, 100, 100), width=1000):
        os.makedirs(OUT, exist_ok=True)
        p = os.path.join(OUT, name + '.svg')
        with open(p, 'w') as f:
            f.write(self.svg(view, width))
        return p


def sample(kind='korn'):
    """Every landscape once: the scene the style was worked out on."""
    s = Scene()
    s.building(-1, 0); s.tree(0, 0, 3)
    s.tree(-2, -3, 3); s.tree(3, -5, 2)
    s.building(-3, -2, 'wood'); s.tree(0, -3, 2)
    s.tree(-2, -1, 3); s.tree(-3, 0, 2)
    for (q, r), h in {(1, -1): 2, (2, -1): 3, (2, -2): 2, (2, -4): 2, (3, -4): 3, (3, -3): 1}.items():
        s.mountain(q, r, h)
    s.water([(-2, 1), (-1, 1), (-3, 2), (0, 1)], 'lake')
    s.water([(-1, -2), (0, -2)], 'pond')
    s.field([(1, 0), (2, 0)], kind)
    return s


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--feld', default='korn', choices=['korn', 'praerie', 'steppe'])
    a = ap.parse_args()
    print(sample(a.feld).write(f'beispiel-{a.feld}'))
