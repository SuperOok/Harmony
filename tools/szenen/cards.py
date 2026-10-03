"""A scene per animal card: its pattern as often as the card has cubes,
an animal on every cube space.

    python3 tools/szenen/cards.py Eichhörnchen
    python3 tools/szenen/cards.py Eichhörnchen --getrennt   # no stone shared

Patterns may share stones, as in the game, but no two cubes share a
space. Which way round each copy lies and where it goes is searched for;
see place() for what makes one layout better than another.
"""
import json
import math
import os
import sys

import random

from landscapes import Board, COL, ROW, R, H, NEIGHBOURS, cells_in
from style import HOUSE_H, ROOF_RISE, MOUNTAIN_STONE_H, FIELD
from scene import Scene
from figures import FIGURES, SIZE, FIGURE_SCALE, marker

CARDS = os.path.join(os.path.dirname(__file__), '..', '..', 'HarmonyRules', 'Sources', 'HarmonyRules', 'Resources', 'animals.json')

# How the field reads for each animal (docs/szenen.md).
FIELD_KIND = {
    'Maus': 'korn', 'Rabe': 'korn', 'Biene': 'korn', 'Marienkäfer': 'korn', 'Echse': 'korn', 'Waschbär': 'korn',
    'Wolf': 'praerie', 'Panther': 'praerie', 'Lama': 'praerie', 'Flamingo': 'praerie', 'Adler': 'praerie',
    'Wüstenfuchs': 'steppe', 'Erdmännchen': 'steppe', 'Eisfuchs': 'praerie',
}

TALL = {'Baum2': 2, 'Baum3': 3, 'Berg2': 2, 'Berg3': 3, 'Gebäude': 1.5}


def load(name):
    with open(CARDS) as f:
        for c in json.load(f)['cards']:
            if c['name'] == name:
                return c
    raise SystemExit(f'Keine Karte {name}')


def axial(cell):
    """Card template cell "<column><row>" to axial: flat-top, the even
    columns half a cell lower (docs/kartennotation.md)."""
    col, row = int(cell[0]) - 1, int(cell[1]) - 1
    return col, row - (col - (col & 1))//2


def rotations(pattern, cube):
    """The six turns of a pattern, each moved so its cube lies at (0, 0)."""
    cells = {axial(k): v for k, v in pattern.items()}
    cq, cr = axial(cube)
    cells = {(q - cq, r - cr): v for (q, r), v in cells.items()}
    out = []
    for _ in range(6):
        out.append(cells)
        cells = {(-r, q + r): v for (q, r), v in cells.items()}
    return out


def score(layout, cubes, b):
    """Lower is better."""
    s = 10*len(layout)                                     # share stones where it fits
    xs = [b.pos(*c)[0] for c in layout]
    s += 40*sum(1 for x in xs if not 12 < x < 88)          # everything in view
    depths = [Board.depth(*c) for c in layout]
    s += 3*max(0, -min(depths))                            # not too deep
    s += 40*max(0, -min(depths) - 3.5)
    for cube in cubes:                                     # nothing tall in front of an animal
        cx, cy = b.pos(*cube)
        for cell, kind in layout.items():
            if cell == cube or kind not in TALL:
                continue
            x, y = b.pos(*cell)
            if y > cy and abs(x - cx) < COL*0.95 and y - cy < 2.5*ROW:
                s += 15*TALL[kind]
    backs = cubes[1:]
    if backs:                                              # the others behind, spread to the sides
        s += 6*abs(sum(b.pos(*c)[0] - 50 for c in backs))/COL
        s += 20*sum(1 for c in backs if Board.depth(*c) > -0.9)
    return s


def place(card, share=True, beam=300):
    """Lay the pattern once per cube: the first cube in front in the middle,
    the others behind. Returns the cells with their landscape, and the cube
    spaces in the order the animals arrive."""
    b = Board()
    turns = rotations(card['pattern'], card['cube'])
    n = len(card['points'])
    states = [({c: v for c, v in t.items()}, [(0, 0)]) for t in turns]
    spots = [(q, r) for q in range(-4, 5) for r in range(-6, 2) if -3.5 <= Board.depth(q, r) <= -0.5]
    for _ in range(n - 1):
        nxt = {}
        for layout, cubes in states:
            for spot in spots:
                if spot in cubes:
                    continue
                for t in turns:
                    merged = dict(layout)
                    ok = True
                    for (q, r), v in t.items():
                        c = (q + spot[0], r + spot[1])
                        if merged.get(c, v) != v or (not share and c in merged):
                            ok = False
                            break
                        merged[c] = v
                    if ok:
                        key = (frozenset(merged.items()), frozenset(cubes + [spot]))
                        nxt[key] = (merged, cubes + [spot])
        states = sorted(nxt.values(), key=lambda st: score(st[0], st[1], b))[:beam]
    layout, cubes = states[0]
    # the animals arrive front to back
    cubes = [cubes[0]] + sorted(cubes[1:], key=lambda c: -Board.depth(*c))
    return layout, cubes


def feet(kind, b, q, r):
    """Where an animal on this landscape stands."""
    x, y = b.pos(q, r)
    if kind == 'Gebäude':
        return x, y - HOUSE_H - ROOF_RISE + 0.8
    if kind.startswith('Baum'):
        return x, y - (int(kind[-1]) - 1)*H - 17.5
    if kind.startswith('Berg'):
        h = int(kind[-1])
        return x, y - h*MOUNTAIN_STONE_H - 2.0 - 0.8*h + 1.0
    return x, y


# The iPhone 15 Pro Max upright: 430 x 932 points.
PORTRAIT = 932/430
HORIZON = 0.16                 # of the wide framing's height, from the top

def views(layout, cubes, b, animal_scale):
    """Camera framings, close to wide: the first animal, the habitat, the
    habitat in its surroundings. Each is (x, y, w, h)."""
    fx, fy = feet(layout[cubes[0]], b, *cubes[0])
    body = 70*animal_scale                      # the figure's height
    xs = [b.pos(*c)[0] for c in layout]
    tops = [feet(v, b, *c)[1] - 6 for c, v in layout.items()]
    bottoms = [b.pos(*c)[1] + ROW for c in layout]
    hx, hy = (min(xs) + max(xs))/2, (min(tops) + max(bottoms))/2
    def frame(cx, cy, w, at=0.5):
        h = w*PORTRAIT
        return cx - w/2, cy - at*h, w, h
    return {
        'nah': frame(fx, fy - body/2, body*3.2),
        'mittel': frame(hx, hy, max(max(xs) - min(xs) + 2*R, 40), 0.55),
        'weit': frame(hx, hy, 100, 0.62),
    }


# What grows round a habitat, as weights: in front of it (only low things:
# water, fields, bushes), beside and behind it, and far off (behind row 6).
# The squirrel lives in woodland: trees close behind its tree, water and
# bushes in front of the houses, no open field.
MIX = {
    None: dict(front={'Wasser': 3, 'Feld': 3, 'Baum': 2},
               middle={'Baum': 4, 'Feld': 3, 'Wasser': 3, 'Gebäude': 2},
               far={'Berg': 3, 'Baum': 2, 'Wasser': 1, 'Feld': 1}),
    'Eichhörnchen': dict(front={'Wasser': 3, 'Baum': 2},
                         middle={'Baum': 8, 'Gebäude': 1},
                         far={'Baum': 4, 'Berg': 2, 'Wasser': 1}),
    # a duck lives on a lake: water all round, reeds (bushes) and trees on the banks
    'Ente': dict(front={'Wasser': 8, 'Baum': 1},
                 middle={'Wasser': 8, 'Baum': 3, 'Gebäude': 1},
                 far={'Berg': 3, 'Baum': 2, 'Wasser': 3}),
    # a ladybird lives in the grain: fields all round, a few bushes and trees at their edges
    'Marienkäfer': dict(front={'Feld': 8, 'Baum': 2},
                        middle={'Feld': 9, 'Baum': 2},
                        far={'Feld': 4, 'Berg': 2, 'Baum': 2}),
    # an eagle lives in the mountains: peaks behind and beside, grass and a few trees below
    'Adler': dict(front={'Feld': 5, 'Baum': 2, 'Wasser': 1},
                  middle={'Berg': 8, 'Feld': 2, 'Baum': 1},
                  far={'Berg': 8, 'Baum': 1}),
    # a raven: fields and farms, a few trees
    'Rabe': dict(front={'Feld': 6, 'Baum': 2},
                 middle={'Feld': 6, 'Gebäude': 2, 'Baum': 3},
                 far={'Feld': 3, 'Baum': 3, 'Berg': 2}),
}
BEHIND = {'Eichhörnchen': 'Baum', 'Ente': 'Wasser', 'Marienkäfer': 'Feld', 'Adler': 'Berg'}                # what stands right behind the habitat
TREE_SHARE = {None: 0.7, 'Eichhörnchen': 0.9}     # how densely a copse is planted
HIGH = ('Baum2', 'Baum3', 'Berg1', 'Berg2', 'Berg3', 'Gebäude')   # what can hide an animal


def surroundings(layout, cubes, b, view, seed=1, animal=None):
    """Fill the board round the habitat so the scene is not empty. In front
    of the animals only low things; right behind the habitat what the animal
    lives among. Should that form another copy of the pattern, no matter:
    the scene is there to cheer, not to count."""
    rnd = random.Random(seed)
    mix = MIX.get(animal, MIX[None])
    free = [c for c in cells_in(b, view) if c not in layout]
    ring = {(q + dq, r + dr) for q, r in layout for dq, dr in NEIGHBOURS.values()} - set(layout)
    front_line = max(Board.depth(*c) for c in layout)

    def behind(c):
        y = b.pos(*c)[1]
        return all(y < b.pos(c[0] + dq, c[1] + dr)[1] for dq, dr in NEIGHBOURS.values() if (c[0] + dq, c[1] + dr) in layout)
    def blocks_view(c):
        x, y = b.pos(*c)
        return any(y > b.pos(*k)[1] and abs(x - b.pos(*k)[0]) < COL*1.1 and y - b.pos(*k)[1] < 4*ROW for k in cubes)
    def allowed(c, kind):
        if kind in HIGH and blocks_view(c):
            return False
        if c in ring and kind in HIGH and not behind(c):
            return False
        return True
    def with_height(c, kind, zone):
        if kind == 'Baum':
            options = ['Baum1'] if zone == 'front' else ['Baum1', 'Baum2', 'Baum3']
        elif kind == 'Berg':
            options = ['Berg1', 'Berg2', 'Berg2', 'Berg3'] if zone == 'far' else ['Berg1', 'Berg1', 'Berg2']
        else:
            options = [kind]
        options = [k for k in options if allowed(c, k)]
        return rnd.choice(options) if options else None

    def zone(c):
        d = Board.depth(*c)
        return 'front' if d > front_line else 'far' if d < -6 else 'middle'
    seeds = []
    for c in rnd.sample(free, max(1, len(free)//6)):
        weights = mix[zone(c)]
        seeds.append((c, rnd.choice([k for k, n in weights.items() for _ in range(n)])))
    def dist(a, c):
        dq, dr = a[0] - c[0], a[1] - c[1]
        return max(abs(dq), abs(dr), abs(dq + dr))

    out = {}
    # right in front of the two outer houses: water to the left, a field to
    # the right with bushes below it, so the closing shot (all houses) does not
    # show bare board
    outer = sorted(cubes[1:], key=lambda c: b.pos(*c)[0])
    if len(outer) >= 2:
        for k in (0, 1):
            c = (outer[0][0], outer[0][1] + 1 + k)
            if c not in layout:
                out[c] = 'Wasser'
        for k, kind in enumerate(('Feld', 'Baum1')):       # and bushes below the field
            c = (outer[-1][0], outer[-1][1] + 1 + k)
            if c not in layout:
                out[c] = kind
    if animal in BEHIND:                          # close behind the habitat, always
        for c in ring:
            if c in free and behind(c):
                k = with_height(c, BEHIND[animal], 'middle')
                if k:
                    out[c] = k
    for c in free:
        if c in out:
            continue
        (sc, kind), d = min(((s, dist(s[0], c)) for s in seeds), key=lambda e: e[1])
        reach = {'Gebäude': 0, 'Baum': 1, 'Berg': 1, 'Wasser': 1, 'Feld': 1}[kind]
        share = TREE_SHARE.get(animal, TREE_SHARE[None]) if kind == 'Baum' else 0.7
        if d > reach or (kind in ('Baum', 'Gebäude') and rnd.random() > share):
            continue
        k = with_height(c, kind, zone(c))
        if k:
            out[c] = k
    return out


def components(cells):
    cells, groups = set(cells), []
    while cells:
        stack, group = [cells.pop()], set()
        while stack:
            c = stack.pop()
            group.add(c)
            for dq, dr in NEIGHBOURS.values():
                n = (c[0] + dq, c[1] + dr)
                if n in cells:
                    cells.remove(n)
                    stack.append(n)
        groups.append(sorted(group))
    return groups


def build(name, arrived=None, share=True, filled=True):
    """The scene with the first `arrived` animals in it (all by default),
    and the camera framings for it."""
    card = load(name)
    layout, cubes = place(card, share)
    s = Scene()
    scale = SIZE.get(name, FIGURE_SCALE)
    cams = views(layout, cubes, s.b, scale)
    # The horizon is fixed in the world, so that zooming does not move it:
    # near the top of the wide framing, and the board fades out towards it.
    x, y, w, h = cams['weit']
    sky_line = y + HORIZON*h
    s.horizon = (sky_line, sky_line + 26)
    s.fade = 0.95/((s.b.oy - sky_line)/ROW)
    world = dict(layout)
    if filled:
        world.update(surroundings(layout, cubes, s.b, cams['weit'], animal=name))
    for i, group in enumerate(components([c for c, v in world.items() if v == 'Wasser'])):
        s.water(group, f'water{i}')
    for group in components([c for c, v in world.items() if v == 'Feld']):
        s.field(group, FIELD_KIND.get(name, 'praerie'))
    for (q, r), v in world.items():
        if v == 'Gebäude':
            s.building(q, r)
        elif v.startswith('Baum'):
            s.tree(q, r, int(v[-1]))
        elif v.startswith('Berg'):
            s.mountain(q, r, int(v[-1]))
    figure = FIGURES.get(name, marker)
    draw = lambda o, x, y: figure(o, x, y, scale)
    for cube in cubes[:arrived]:
        x, y = feet(layout[cube], s.b, *cube)
        s.animals.append((cube, (draw, x, y)))
    return s, layout, cubes, cams


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    share = '--getrennt' not in sys.argv
    name = args[0] if args else 'Eichhörnchen'
    s, layout, cubes, cams = build(name, share=share)
    print('Felder:', len(layout), ' Würfel in Reihenfolge:', cubes)
    for (q, r), v in sorted(layout.items(), key=lambda e: Board.depth(*e[0])):
        print(f'  ({q:2},{r:2}) Tiefe {Board.depth(q, r):5.1f}  {v}{"  ← Würfel" if (q, r) in cubes else ""}')
    base = name.lower().replace('ä', 'ae').replace('ö', 'oe').replace('ü', 'ue') + ('' if share else '-getrennt')
    for cam, view in cams.items():
        print(s.write(f"{base}-{cam}", view, width=None))
