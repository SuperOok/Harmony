"""Puts landscapes on the board and writes the scene as SVG.

    python3 tools/szenen/scene.py                 # the sample scene
    python3 tools/szenen/scene.py --feld steppe   # with another field

Output goes to tools/szenen/out/ (not checked in). Look at it with
`qlmanage -t -s 1000 -o <dir> <file>.svg`, which renders a PNG.
Scenes per animal card come later, built on Scene.
"""
import argparse
import os

from style import BACKGROUND
from landscapes import (Board, NEIGHBOURS, defs, board, building, tree, mountain, ridge,
                        water, field)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')


class Scene:
    def __init__(self, board_=None):
        self.b = board_ or Board()
        self.things = {}       # (q, r): draw function
        self.peaks = {}        # (q, r): height
        self.waters = []       # (cells, name)
        self.fields = []       # (cells, kind)

    def building(self, q, r, base='stone'): self.things[(q, r)] = building(base)
    def tree(self, q, r, height): self.things[(q, r)] = tree(height)
    def water(self, cells, name): self.waters.append((cells, name))
    def field(self, cells, kind='korn'): self.fields.append((cells, kind))
    def mountain(self, q, r, height):
        self.peaks[(q, r)] = height
        self.things[(q, r)] = mountain(height, q*31 + r*7 + height)

    def svg(self):
        b = self.b
        fog = lambda r: f'far{-r}' if r < 0 else None      # behind the front row: in the haze
        o = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="1000" height="1000">']
        o += defs()
        o.append(f'<rect width="100" height="100" fill="{BACKGROUND}"/>')
        board(o, b)

        # Flat land lies on the board. A water group fades with its frontmost row.
        for cells, name in self.waters:
            f = fog(max(r for _, r in cells))
            o.append(f'<g filter="url(#{f})">' if f else '<g>')
            water(o, b, cells, name)
            o.append('</g>')
        items = []
        for cells, kind in self.fields:
            items += field(o, b, cells, kind)

        # Everything standing up, back to front. A ridge comes just before
        # the farther of its two mountains.
        for (q, r), draw in self.things.items():
            cx, cy = b.pos(q, r)
            g = []
            draw(g, cx, cy)
            items.append((cy + 0.001*q, g, fog(r)))
        done = set()
        for (q, r), h in self.peaks.items():
            for dq, dr in NEIGHBOURS.values():
                n = (q + dq, r + dr)
                if n in self.peaks and frozenset([(q, r), n]) not in done:
                    done.add(frozenset([(q, r), n]))
                    g = []
                    ridge(b, (q, r), n, h, self.peaks[n])(g)
                    far = min((q, r), n, key=lambda c: b.pos(*c)[1])
                    items.append((b.pos(*far)[1] - 0.01, g, fog(far[1])))
        for item in sorted(items, key=lambda e: e[0]):
            if isinstance(item[1], str):
                o.append(item[1])
                continue
            _, g, f = item
            o += ([f'<g filter="url(#{f})">'] if f else []) + g + (['</g>'] if f else [])

        o.append('<rect width="100" height="100" fill="url(#haze)"/>')
        o.append('</svg>')
        return '\n'.join(o)

    def write(self, name):
        os.makedirs(OUT, exist_ok=True)
        p = os.path.join(OUT, name + '.svg')
        with open(p, 'w') as f:
            f.write(self.svg())
        return p


def sample(kind='korn'):
    """Every landscape once: the scene the style was worked out on."""
    s = Scene()
    s.building(-1, 0); s.tree(0, 0, 3)
    s.tree(-1, -4, 3); s.tree(5, -4, 2)
    s.building(-3, -3, 'wood'); s.tree(0, -3, 2)
    s.tree(-2, -2, 3); s.tree(-3, -1, 2)
    for (q, r), h in {(1, -1): 2, (1, 0): 3, (2, -1): 2, (2, -3): 2, (3, -3): 3, (2, -2): 1}.items():
        s.mountain(q, r, h)
    s.water([(-2, 0), (-3, 1), (-2, 1), (-1, 1)], 'lake')
    s.water([(-1, -2), (0, -2)], 'pond')
    s.field([(0, 1), (1, 1)], kind)
    return s


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--feld', default='korn', choices=['korn', 'praerie', 'steppe'])
    a = ap.parse_args()
    print(sample(a.feld).write(f'beispiel-{a.feld}'))
