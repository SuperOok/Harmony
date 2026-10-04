"""The first animation of more animals, each a little story told in
frames (anim.py writes them as animated SVG).

    python3 tools/szenen/stories.py Ente
    python3 tools/szenen/stories.py Marienkäfer Adler Rabe

Every story: the camera starts close on where the first animal ends up, the
animal arrives and does what its kind does, the camera pulls back once to
show where it is and a second time to show the habitat; then it fades and
starts again. Like animate.py (the squirrel), only the numbers are here.
"""
import math
import sys

from anim import (FPS, ease, lerp, clamp, lerp_view, lerp2, frame, jump, write, base_frame)
from cards import build, feet as feet_of, PORTRAIT
from figures import SIZE
import figures_more as fm
import fig_bug as fb
import fig_duck as fm_duck


class Setup:
    """The scene of a card with the first animal's cube space and the
    camera framings every story starts from."""
    def __init__(self, name):
        self.name = name
        self.s, self.layout, self.cubes, self.cams = build(name, arrived=0)
        self.scale = SIZE[name]
        self.cube = self.cubes[0]
        self.kind = self.layout[self.cube]
        self.spot = feet_of(self.kind, self.s.b, *self.cube)    # where the animal ends up
        self.body = 70*self.scale                                # its height
        # where the animals will stand (on a peak, high above their cell's middle)
        spots = [feet_of(self.layout[c], self.s.b, *c) for c in self.cubes]
        self.xs = [x for x, _ in spots]
        span = max(max(self.xs) - min(self.xs) + 3, 36)
        ys = [y for _, y in spots]
        h = span*PORTRAIT
        # the animals a little below the middle for ground animals; on a peak
        # they stand high, so the mountains below them are shown
        k = 0.12 if self.kind.startswith('Berg') else -0.18
        self.habitat = frame((max(self.xs) + min(self.xs))/2, sum(ys)/len(ys) + k*h, span)

    def close(self, dy=0.5, k=3.4):
        return frame(self.spot[0], self.spot[1] - self.body*dy, self.body*k)


def ripples(events, length, colour='#BFE0F5', width=0.22):
    """Rings spreading on the water. events: (t0, x, y, radius, seconds)."""
    n = int(length*FPS)
    def below(frames):
        out = []
        for t0, x, y, r, dur in events:
            cx, cy, rx, ry, op = [], [], [], [], []
            for i in range(n):
                u = (i/FPS - t0)/dur
                if 0 <= u <= 1:
                    cx.append(f'{x:.2f}'); cy.append(f'{y:.2f}')
                    rx.append(f'{r*(0.25 + 0.75*math.sqrt(u)):.2f}')
                    ry.append(f'{r*(0.25 + 0.75*math.sqrt(u))*0.42:.2f}')
                    op.append(f'{0.7*(1 - u):.2f}')
                else:
                    cx.append(f'{x:.2f}'); cy.append(f'{y:.2f}'); rx.append('0.01'); ry.append('0.01'); op.append('0')
            from anim import smil
            out.append(f'<ellipse fill="none" stroke="{colour}" stroke-width="{width}">'
                       + smil(cx, length, attr='cx') + smil(cy, length, attr='cy')
                       + smil(rx, length, attr='rx') + smil(ry, length, attr='ry')
                       + smil(op, length, attr='stroke-opacity') + '</ellipse>')
        return '\n'.join(out)
    return below


# ------------------------------------------------------------- duck
# A pair: the drake leads, the hen follows. They swim in, look round, dabble
# one after the other, and as the camera pulls back to the lake they take
# off and fly away over it, climbing and growing small.

TINY = 0.001                                   # a part "scaled to nothing"


def flap(t, lag=0.0, rate=4.4):
    """How wide the near and far wing stand open (1 = straight up, below 0 =
    down past the body), the way a wing turning about the body looks from
    the side: its length is foreshortened by the cosine."""
    a = 2*math.pi*rate*t
    return 0.25 + 0.8*math.cos(a - lag), 0.25 + 0.8*math.cos(a - lag - 0.8)


def duck():
    S = Setup('Ente')
    length = 16.0
    spot = S.spot
    body = S.body
    hen_spot = (spot[0] - 6.8, spot[1] + 1.0)
    cx = spot[0] - 3.4
    close = frame(cx, spot[1] - body*0.35, body*3.9)
    wide = frame(cx + 1.5, spot[1] - 3.5, 28)
    habitat = S.habitat
    n = int(length*FPS)
    events = []

    def view_at(t):
        if t < 4.0:  return close
        if t < 5.6:  return lerp_view(close, wide, ease((t - 4.0)/1.6))
        if t < 10.4: return wide
        return lerp_view(wide, habitat, ease(clamp((t - 10.4)/3.2)))

    def one(who, at, delay, dab, rate_lag, scale_k):
        """Frames of one duck. `dab` is when it dabbles, `delay` how much
        later than the drake it comes and goes."""
        out = []
        start = (at[0] - 15, at[1] + 0.8)
        take = 10.4 + delay                    # the run over the water begins
        for i in range(n):
            t = i/FPS
            f = base_frame(view_at(t))
            f['airborne'] = True               # no shadow on water, nor in the air
            p = f['parts']
            p['fly'] = (TINY, TINY)
            p['wingN'] = p['wingF'] = (1, 1)
            f['sx'] = f['sy'] = scale_k
            bob = 0.12*math.sin(t*2.1 + rate_lag)
            t0 = 0.4 + delay
            feet = at
            if t < t0:                                 # empty water
                feet, f['alpha'] = start, 0
            elif t < t0 + 2.4:                         # paddles in from the left, slowing
                u = (t - t0)/2.4
                x, y = lerp2(start, at, 1 - (1 - u)**2.2)
                feet = (x, y + bob)
                f['alpha'] = clamp((t - t0)/0.3)
                p['tail'] = 5*math.sin(t*9)*(1 - u)
                p['head'] = 4*math.sin(t*4.5)
                if i % 9 == 0 and u < 0.95:
                    events.append((t, x - 1.5, y + 0.2, 3.0, 1.3))
            elif t < dab:                              # swims in place, looks round
                feet = (at[0] + 0.4*math.sin(t*0.8 + rate_lag), at[1] + bob)
                u = (t - t0 - 2.4)
                p['head'] = 12*math.sin(u*1.7 + rate_lag)*min(1, u)
                p['tail'] = 4*math.sin(t*6)*max(0, 1 - u/1.2)
                p['eye'] = (1, 0.1 if int(t*7 + rate_lag*3) % 23 == 0 else 1)
            elif t < dab + 2.8:                        # dabbles: tips forward, tail up, comes up shaking
                u = (t - dab)/2.8
                if u < 0.25:   tip = 72*ease(u/0.25)
                elif u < 0.6:  tip = 72 + 4*math.sin((u - 0.25)*40)
                elif u < 0.8:  tip = 72*(1 - ease((u - 0.6)/0.2))
                else:          tip = 0
                p['tip'] = tip
                p['tail'] = 10*math.sin(t*14)*(1 if 0.25 < u < 0.65 else 0.2)
                p['head'] = -10*math.sin((u - 0.8)*60)*math.exp(-(u - 0.8)*9) if u > 0.8 else 0
                feet = (at[0], at[1] + bob*(1 if tip < 10 else 0.2))
                if abs(u - 0.25) < 0.01 or abs(u - 0.62) < 0.01:
                    events.append((t, at[0] + 1.0, at[1] + 0.3, 4.2, 1.8))
            elif t < take:                             # settles, shakes the tail, blinks
                u = (t - dab - 2.8)
                feet = (at[0], at[1] + bob)
                p['tail'] = 12*math.sin(t*16)*max(0, 1 - u/1.0)
                p['head'] = 6*math.sin(t*3)
                p['eye'] = (1, 0.1 if int(t*9) % 17 == 0 else 1)
            else:                                      # takes off
                w = t - take
                run = 0.9
                if w < run:                            # runs over the water, beating the wings
                    u = w/run
                    x = at[0] + 6.5*u*u
                    feet = (x, at[1] + 0.1)
                    f['rot'] = -9*u
                    p['tail'] = 10*math.sin(t*22)
                    p['head'] = 8*u
                    if w > 0.45:                       # wings out, still on the water
                        p['swim'] = (TINY, TINY)
                        p['fly'] = (1, 1)
                        p['wingN'], p['wingF'] = [(1, c) for c in flap(t, rate_lag)]
                    if i % 4 == 0:
                        events.append((t, x - 1.0, at[1] + 0.2, 2.6 + 1.4*u, 0.9))
                else:                                  # in the air
                    w -= run
                    xe = at[0] + 6.5
                    feet = (xe + 6.0*w, at[1] + 0.1 - 2.5*w - 1.6*w*w)
                    f['rot'] = -math.degrees(math.atan2(2.5 + 3.2*w, 6.0)) + 2*math.sin(t*3)
                    k = 1 + 0.45*w                     # it passes over the camera, nearer and bigger
                    f['sx'] = f['sy'] = scale_k*k
                    p['swim'] = (TINY, TINY)
                    p['fly'] = (1, 1)
                    p['wingN'], p['wingF'] = [(1, c) for c in flap(t, rate_lag)]
            if t > length - 0.6:
                f['alpha'] = min(f['alpha'], (length - t)/0.6)
            f['feet'] = feet
            out.append(f)
        return out

    drake = one('drake', spot, 0.0, 5.6, 0.0, 1.0)
    hen = one('hen', hen_spot, 0.25, 7.2, 1.7, 0.93)
    # the rings the drake makes where it dabbles, and the figure's own
    events += [(5.6 + 0.25*2.8, spot[0] + 1.0, spot[1] + 0.3, 4.6, 1.8)]
    return dict(S=S, length=length, frames=drake, body=fm_duck.duck_body, parts=fm_duck.DUCK_PARTS,
                feet=fm_duck.DUCK_FEET, shadow=None, below=ripples(events, length), file='ente-animation.svg',
                others=[dict(frames=hen, body=fm_duck.hen_body, parts=fm_duck.DUCK_PARTS, scale=S.scale,
                             feet=fm_duck.DUCK_FEET, shadow=None)])


# ------------------------------------------------------------- ladybird

def ladybird():
    """Three ladybirds, one of them flying in from a bush; told in story_bug.py."""
    import story_bug
    return story_bug.ladybirds()


# ------------------------------------------------------------- birds

def bezier(p0, p1, p2, p3, u):
    a = (1 - u)**3, 3*(1 - u)**2*u, 3*(1 - u)*u*u, u**3
    return tuple(a[0]*p0[k] + a[1]*p1[k] + a[2]*p2[k] + a[3]*p3[k] for k in (0, 1))


def bird_pose(p, spread=0.0, fold=1.0, legs=1.0, flap=None, head=0.0, tail=0.0, beak=0.0, blink=1.0):
    """Sets a bird's parts. spread 0..1 is how far the wings are out (fold
    is the folded wing); flap is the near wing's angle, the far one follows."""
    tiny = 0.01
    p['spread'] = (max(tiny, spread), max(tiny, spread))
    p['fold'] = (max(tiny, fold), max(tiny, fold))
    p['legs'] = (1, legs)
    p['wingN'] = flap if flap is not None else -30
    p['wingF'] = (flap if flap is not None else -30) + 8
    p['head'], p['tail'], p['beak'], p['eye'] = head, tail, beak, (1, blink)


def raven():
    """The raven on the new flight pose; told in story_raven.py."""
    import story_raven
    return story_raven.ravens()


# ------------------------------------------------------------- the registry

def eagle():
    """The nest on the peak; told in story_eagle.py."""
    import story_eagle
    return story_eagle.eagle_nest()


STORIES = {'Ente': duck, 'Marienkäfer': ladybird, 'Adler': eagle, 'Rabe': raven}


def render(name):
    story = STORIES[name]()
    S = story['S']
    from anim import write
    return write(story['file'], S.s, S.cams['weit'], story['frames'], story['length'], story['body'],
                 story['parts'], S.scale, story['feet'],
                 shadow=story['shadow'], below=story['below'], depth=story.get('depth'), others=story.get('others', ()))


if __name__ == '__main__':
    for name in sys.argv[1:] or list(STORIES):
        print(render(name))
