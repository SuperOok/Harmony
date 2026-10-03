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

def duck():
    S = Setup('Ente')
    length = 12.5
    spot = S.spot
    start = (spot[0] - 15, spot[1] + 1.2)
    close = S.close(0.35, 3.6)
    wide = frame(spot[0], spot[1] - 3, 22)
    habitat = S.habitat
    events = []
    frames = []
    for i in range(int(length*FPS)):
        t = i/FPS
        f = base_frame(close)
        p = f['parts']
        f['airborne'] = True                       # no shadow on water
        feet = spot
        bob = 0.12*math.sin(t*2.1)                 # floating
        if t < 0.4:                                # empty water
            feet, f['alpha'] = start, 0
        elif t < 2.6:                              # paddles in from the left, slowing
            u = (t - 0.4)/2.2
            x, y = lerp2(start, spot, 1 - (1 - u)**2.2)
            feet = (x, y + bob)
            f['alpha'] = clamp((t - 0.4)/0.3)
            p['tail'] = 5*math.sin(t*9)*(1 - u)
            p['head'] = 4*math.sin(t*4.5)
            if i % 9 == 0 and u < 0.95:
                events.append((t, x - 1.5, y + 0.2, 3.2, 1.3))
        elif t < 3.8:                              # glides to a stop, looks round
            u = (t - 2.6)/1.2
            feet = (spot[0], spot[1] + bob)
            p['head'] = -14*math.sin(u*math.pi*1.4)*(1 - u*0.3)
            p['tail'] = 4*math.sin(t*6)*(1 - u)
            f['face'] = 1
            if 2.6 <= t < 2.64:
                events.append((t, spot[0] - 1.5, spot[1] + 0.2, 3.5, 1.6))
        elif t < 5.4:                              # the camera pulls back, it drifts and turns its head
            u = ease((t - 3.8)/1.6)
            f['view'] = lerp_view(close, wide, u)
            feet = (spot[0] + 0.4*math.sin(t), spot[1] + bob)
            p['head'] = 10*math.sin((t - 3.8)*2.6)
            blink = 0.1 if 4.5 < t < 4.62 else 1
            p['eye'] = (1, blink)
        elif t < 8.2:                              # dabbles: tips forward, tail up, comes up shaking
            f['view'] = wide
            u = (t - 5.4)/2.8
            if u < 0.25:      tip = 72*ease(u/0.25)
            elif u < 0.6:     tip = 72 + 4*math.sin((u - 0.25)*40)      # tail wiggles
            elif u < 0.8:     tip = 72*(1 - ease((u - 0.6)/0.2))
            else:             tip = 0
            p['tip'] = tip
            p['tail'] = 10*math.sin(t*14)*(1 if 0.25 < u < 0.65 else 0.2)
            p['head'] = -10*math.sin((u - 0.8)*60)*math.exp(-(u - 0.8)*9) if u > 0.8 else 0
            feet = (spot[0], spot[1] + bob*(1 if tip < 10 else 0.2))
            if abs(t - (5.4 + 0.25*2.8)) < 0.02 or abs(t - (5.4 + 0.62*2.8)) < 0.02:
                events.append((t, spot[0] + 1.0, spot[1] + 0.3, 4.2, 1.8))
        elif t < 9.4:                              # settles, shakes its tail, blinks
            f['view'] = wide
            u = (t - 8.2)/1.2
            feet = (spot[0], spot[1] + bob)
            p['tail'] = 12*math.sin(t*16)*(1 - u)
            p['head'] = 6*math.sin(t*3)
            p['eye'] = (1, 0.1 if 9.0 < t < 9.12 else 1)
        else:                                      # second pull-back: the whole lake
            u = ease(clamp((t - 9.0)/2.4))
            f['view'] = lerp_view(wide, habitat, u)
            feet = (spot[0], spot[1] + bob)
            p['head'] = 5*math.sin(t*2.2)
            if t > length - 0.5:
                f['alpha'] = (length - t)/0.5
        f['feet'] = feet
        frames.append(f)
    # the figure's own water ring and the rings it makes
    events += [(5.4 + 0.25*2.8, spot[0] + 1.0, spot[1] + 0.3, 4.6, 1.8)]
    return dict(S=S, length=length, frames=frames, body=fm.duck_body, parts=fm.DUCK_PARTS,
                feet=fm.DUCK_FEET, shadow=None, below=ripples(events, length), file='ente-animation.svg')


# ------------------------------------------------------------- ladybird

def ladybird():
    S = Setup('Marienkäfer')
    length = 13.0
    spot = S.spot
    start = (spot[0] - 2.2, spot[1] + 4.5)
    land = (spot[0] + 3.2, spot[1] - 0.4)            # where it comes down after its flight
    close = S.close(0.05, 4.2)
    wide = frame(spot[0] + 1.2, spot[1] - 0.8, 13)
    habitat = S.habitat
    frames = []
    def heading(a, b):                                # degrees clockwise from straight up the screen
        return math.degrees(math.atan2(b[0] - a[0], -(b[1] - a[1])))
    for i in range(int(length*FPS)):
        t = i/FPS
        f = base_frame(close)
        f['sy'] = 0.85                               # seen a little from the side
        p = f['parts']
        feet, rot = spot, 0.0
        def walk(speed=1.0):
            w = math.sin(t*20*speed)
            p['legsA'], p['legsB'] = 9*w, -9*w
        def feelers(a=1.0, k=7.0):
            p['antL'] = a*9*math.sin(t*k)
            p['antR'] = a*9*math.sin(t*k + 2.1)
        if t < 0.4:                                  # empty field
            feet, f['alpha'] = start, 0
            rot = heading(start, spot)
        elif t < 3.0:                                # crawls up from the lower left, weaving
            u = (t - 0.4)/2.6
            e = 1 - (1 - u)**1.8
            x, y = lerp2(start, spot, e)
            x += 0.35*math.sin(u*9)*(1 - u)
            feet = (x, y)
            rot = heading(start, spot) + 14*math.cos(u*9)*(1 - u)
            f['alpha'] = clamp((t - 0.4)/0.3)
            walk(1.0 if u < 0.97 else 0)
            feelers(1.2, 9)
            f['sy'] = 0.85 + 0.015*math.sin(t*20)
        elif t < 4.4:                                # stops, feelers feel the air
            feet = spot
            rot = 0.0
            feelers(1.4, 6)
            if t < 3.2:
                walk(0.4)
        elif t < 5.8:                                # the camera pulls back; it sits and cleans a feeler
            u = ease((t - 4.4)/1.4)
            f['view'] = lerp_view(close, wide, u)
            feelers(0.7, 4)
            p['antL'] = 18*math.sin((t - 4.4)*5)*(1 if t < 5.2 else 0.2)
        elif t < 7.4:                                # opens its wing cases, unfolds the wings, flutters
            f['view'] = wide
            u = (t - 5.8)/1.6
            open_ = ease(clamp(u/0.3))
            p['elytraL'] = 62*open_
            p['elytraR'] = -62*open_
            flutter = 1 + 0.18*math.sin(t*50)*open_
            p['wings'] = (0.2 + 0.8*ease(clamp((u - 0.1)/0.3)) if u < 1 else 1, 1)
            p['wings'] = (p['wings'][0]*flutter, 1)
            feelers(0.5, 5)
            feet = spot
        elif t < 9.0:                                # lifts off, hovers, drifts a little forward and sets down
            f['view'] = wide
            u = (t - 7.4)/1.6
            lift = math.sin(min(1, u)*math.pi)       # up and down again
            feet = lerp2(spot, land, ease(u))
            ground = feet
            feet = (feet[0], feet[1] - 2.6*lift)
            f['ground'] = ground
            f['shadow'] = 1 - 0.4*lift
            p['elytraL'], p['elytraR'] = 62, -62
            p['wings'] = (1 + 0.2*math.sin(t*50), 1)
            f['sy'] = 0.85 + 0.1*lift
            rot = heading(spot, land)*lift*0.6
            if u > 0.8:                              # touching down: folds
                k = ease((u - 0.8)/0.2)
                p['elytraL'], p['elytraR'] = 62*(1 - k), -62*(1 - k)
                p['wings'] = (max(0.2, 1 - 0.8*k), 1)
        elif t < 9.8:                                # closed up again, sits on its new place
            f['view'] = wide
            feet = land
            u = (t - 9.0)/0.8
            p['wings'] = (0.2, 1)
            feelers(0.6, 6)
        else:                                        # the second pull-back: all five places
            u = ease(clamp((t - 9.4)/2.6))
            f['view'] = lerp_view(wide, habitat, u)
            feet = land
            p['wings'] = (0.2, 1)
            feelers(0.5, 3)
            if t > length - 0.5:
                f['alpha'] = (length - t)/0.5
        f['feet'], f['rot'] = feet, rot
        frames.append(f)
    return dict(S=S, length=length, frames=frames, body=fb.bug_body, parts=fb.BUG_PARTS,
                feet=fb.BUG_FEET, shadow=fb.BUG_SHADOW, below=None, file='marienkaefer-animation.svg',
                depth=spot[1] + 0.8)       # among the stalks: the ones in front hide it


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


def eagle():
    import fig_bird as fbird
    S = Setup('Adler')
    length = 15.0
    spot = S.spot
    start = (spot[0] - 36, spot[1] - 22)
    close = S.close(0.35, 4.6)
    wide = frame(spot[0] - 1, spot[1] + 8, 28)
    habitat = S.habitat
    # the approach: a long glide down from the upper left, a flare over the peak
    c1, c2 = (spot[0] - 18, spot[1] - 28), (spot[0] - 12, spot[1] - 9)
    frames = []
    for i in range(int(length*FPS)):
        t = i/FPS
        f = base_frame(close)
        p = f['parts']
        feet, rot = spot, 0.0
        if t < 0.4:                                  # the empty peak
            feet, f['alpha'] = start, 0
            bird_pose(p, 1, 0, 0.3, -25)
            f['airborne'] = True
        elif t < 3.3:                                # glides in, flapping slowly, flares over the peak
            u = (t - 0.4)/2.9
            e = u**0.8
            feet = bezier(start, c1, c2, spot, e)
            nxt = bezier(start, c1, c2, spot, min(1, e + 0.02))
            rot = max(-25, min(25, math.degrees(math.atan2(nxt[1] - feet[1], nxt[0] - feet[0]))*0.7))
            f['alpha'] = clamp((t - 0.4)/0.3)
            glide = 1 if u < 0.55 else 0
            flap = -20 + 45*math.sin(t*2*math.pi*(1.3 if u < 0.75 else 2.6))
            if glide and u > 0.2 and u < 0.5:
                flap = -28 + 6*math.sin(t*3)          # soars with the wings out
            bird_pose(p, 1, 0, 0.3 + 0.7*clamp((u - 0.7)/0.3), flap, tail=-8 + 10*math.sin(t*3))
            f['airborne'] = u < 0.97
            f['sy'] = 1.0
            if u > 0.7:                              # braking: it rears up, wings pulled forward
                rot = -35*ease(clamp((u - 0.7)/0.3))
        elif t < 4.1:                                # lands, wings still out for balance
            u = (t - 3.3)/0.8
            feet = spot
            flap = -10 + 30*math.sin(t*2*math.pi*2.4)*(1 - u)
            bird_pose(p, 1, 0, 1, flap)
            rot = -35*(1 - ease(u))
            f['sy'] = 1 - 0.06*math.sin(u*math.pi)
        elif t < 4.6:                                # folds the wings
            u = ease((t - 4.1)/0.5)
            bird_pose(p, 1 - u, u, 1, -25*(1 - u))
        elif t < 6.4:                                # perched: looks left and right, blinks
            u = t - 4.6
            bird_pose(p, 0, 1, 1, head=-12*math.sin(u*2.4) + 6, tail=2*math.sin(t*3),
                      blink=0.1 if 5.4 < t < 5.52 else 1)
        elif t < 8.2:                                # the camera pulls back: the mountains
            f['view'] = lerp_view(close, wide, ease((t - 6.4)/1.8))
            bird_pose(p, 0, 1, 1, head=8*math.sin((t - 6.4)*2), tail=2*math.sin(t*3))
        elif t < 10.2:                               # throws its head back and screams, wings half out
            f['view'] = wide
            u = (t - 8.2)/2.0
            s = ease(clamp(u/0.2))*(1 - ease(clamp((u - 0.8)/0.2)))
            cry = abs(math.sin(u*math.pi*3)) if 0.2 < u < 0.8 else 0
            bird_pose(p, 0.95*s, 1 - 0.9*s, 1, -38*s + 8*math.sin(t*14)*s, head=-22*s,
                      tail=-6*s, beak=20*cry*s)
            f['sy'] = 1 + 0.03*s
        elif t < 11.0:                               # settles
            f['view'] = wide
            u = (t - 10.2)/0.8
            bird_pose(p, 0, 1, 1, head=5*math.sin(u*6)*(1 - u))
        else:                                        # the second pull-back: the whole range
            u = ease(clamp((t - 10.6)/3.0))
            f['view'] = lerp_view(wide, habitat, u)
            bird_pose(p, 0, 1, 1, head=6*math.sin(t*1.6), blink=0.1 if 12.2 < t < 12.32 else 1)
            if t > length - 0.5:
                f['alpha'] = (length - t)/0.5
        f['feet'], f['rot'] = feet, rot
        frames.append(f)
    return dict(S=S, length=length, frames=frames, body=fbird.eagle_body, parts=fbird.BIRD_PARTS,
                feet=fbird.BIRD_FEET, shadow=fbird.EAGLE_SHADOW, below=None, file='adler-animation.svg')


def raven():
    import fig_bird as fbird
    S = Setup('Rabe')
    length = 14.0
    spot = S.spot
    start = (spot[0] - 28, spot[1] - 17)
    hop1 = (spot[0] + 1.4, spot[1] + 0.3)
    hop2 = (spot[0] + 2.6, spot[1] - 0.3)
    close = S.close(0.2, 5.0)
    wide = frame(spot[0] + 1, spot[1] - 2, 20)
    habitat = S.habitat
    c1, c2 = (spot[0] - 14, spot[1] - 20), (spot[0] - 8, spot[1] - 8)
    frames = []
    for i in range(int(length*FPS)):
        t = i/FPS
        f = base_frame(close)
        p = f['parts']
        feet, rot = spot, 0.0
        if t < 0.4:
            feet, f['alpha'] = start, 0
            bird_pose(p, 1, 0, 0.3, -25)
            f['airborne'] = True
        elif t < 2.8:                                # flies in over the field, quick wingbeats, then flares
            u = (t - 0.4)/2.4
            e = u**0.85
            feet = bezier(start, c1, c2, spot, e)
            nxt = bezier(start, c1, c2, spot, min(1, e + 0.02))
            rot = max(-25, min(25, math.degrees(math.atan2(nxt[1] - feet[1], nxt[0] - feet[0]))*0.7))
            f['alpha'] = clamp((t - 0.4)/0.3)
            flap = -15 + 50*math.sin(t*2*math.pi*(3.2 if u < 0.7 else 4.0))
            bird_pose(p, 1, 0, 0.3 + 0.7*clamp((u - 0.7)/0.3), flap, tail=-6)
            f['ground'] = (feet[0], spot[1])           # the shadow runs along the ground below it
            f['shadow'] = clamp((u - 0.1)/0.5)*0.6 + 0.2*u
            if u > 0.72:
                rot = -32*ease(clamp((u - 0.72)/0.28))
        elif t < 3.5:                                # touches down
            u = (t - 2.8)/0.7
            flap = -5 + 35*math.sin(t*2*math.pi*3.5)*(1 - u)
            bird_pose(p, 1, 0, 1, flap)
            rot = -32*(1 - ease(u))
            f['sy'] = 1 - 0.07*math.sin(u*math.pi)
        elif t < 4.0:                                # folds
            u = ease((t - 3.5)/0.5)
            bird_pose(p, 1 - u, u, 1, -15*(1 - u))
        elif t < 6.0:                                # hops forward twice, head cocked
            u = (t - 4.0)/2.0
            if u < 0.4:    a, b, v = spot, hop1, u/0.4
            elif u < 0.55: a, b, v = hop1, hop1, 0
            elif u < 0.95: a, b, v = hop1, hop2, (u - 0.55)/0.4
            else:          a, b, v = hop2, hop2, 0
            if a == b:
                feet = a
            else:
                feet = jump(a, b, ease(v), 1.1)
                f['ground'] = lerp2(a, b, ease(v))
                f['sy'] = 1.06 if 0.1 < v < 0.9 else 1
            bird_pose(p, 0, 1, 1, head=-12 + 10*math.sin(t*5), tail=6*math.sin(t*9))
            f['view'] = lerp_view(close, wide, ease(clamp((t - 5.0)/1.0)))
        elif t < 9.0:                                # the camera has pulled back; it caws, three times
            f['view'] = wide
            feet = hop2
            u = (t - 6.0)/3.0
            cry_n = u*3
            k = cry_n - int(cry_n)
            caw = math.sin(min(1, k/0.5)*math.pi) if k < 0.5 and cry_n < 3 else 0
            bird_pose(p, 0, 1, 1, head=-18*caw + 4*math.sin(t*2), tail=-8*caw, beak=24*caw,
                      blink=0.1 if 8.3 < t < 8.42 else 1)
            f['sy'] = 1 + 0.04*caw
        elif t < 10.4:                               # looks about
            f['view'] = wide
            feet = hop2
            bird_pose(p, 0, 1, 1, head=14*math.sin((t - 9.0)*3)*(1 - (t - 9.0)/1.4))
        else:                                        # the second pull-back: the farm
            u = ease(clamp((t - 10.0)/3.0))
            f['view'] = lerp_view(wide, habitat, u)
            feet = hop2
            bird_pose(p, 0, 1, 1, head=5*math.sin(t*2))
            if t > length - 0.5:
                f['alpha'] = (length - t)/0.5
        f['feet'], f['rot'] = feet, rot
        frames.append(f)
    return dict(S=S, length=length, frames=frames, body=fbird.raven_body, parts=fbird.BIRD_PARTS,
                feet=fbird.BIRD_FEET, shadow=fbird.RAVEN_SHADOW, below=None, file='rabe-animation.svg')


# ------------------------------------------------------------- the registry

STORIES = {'Ente': duck, 'Marienkäfer': ladybird, 'Adler': eagle, 'Rabe': raven}


def render(name):
    story = STORIES[name]()
    S = story['S']
    from anim import write
    return write(story['file'], S.s, S.cams['weit'], story['frames'], story['length'], story['body'],
                 story['parts'], S.scale, story['feet'],
                 shadow=story['shadow'], below=story['below'], depth=story.get('depth'))


if __name__ == '__main__':
    for name in sys.argv[1:] or list(STORIES):
        print(render(name))
