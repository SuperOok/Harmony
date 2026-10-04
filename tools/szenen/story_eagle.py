"""The eagle's nest: on the peak a nest of twigs, the mother broods in it,
the father flies in with a fish, feeds the three chicks one after the
other and flies on.

    python3 tools/szenen/story_eagle.py

Told like the stories in stories.py (the camera starts close on the nest,
pulls back twice, only outwards); kept in a file of its own so that a
second session can work on stories.py meanwhile.

Cast, in drawing order: the mother (the first figure, the camera is hers),
the chicks, the nest's front rim, the father. The back of the nest and its
floor go under all of them.
"""
import math

from anim import FPS, ease, clamp, lerp, lerp_view, lerp2, frame, write, base_frame
import fig_chick as fc
import fig_eagle as fe
import nest
from stories import Setup, bezier


def _still_world(svg):
    """A body that draws world coordinates, for a piece of the scene that stands still."""
    return lambda anim=None, shadow=False: svg


def eagle_nest():
    S = Setup('Adler')
    length = 19.0
    n = int(length*FPS)
    spot = S.spot
    scale = S.scale
    cx, cy = spot[0], spot[1]                      # the middle of the nest, on the apex

    mother_feet = (cx - 1.5, cy + 3.0)             # sits down: body and legs behind the front rim
    chick_feet = [(cx + 1.0, cy + 3.5), (cx + 2.6, cy + 3.4), (cx + 4.1, cy + 3.5)]
    perch = (cx + 5.7, cy + 1.5)                   # the father lands on the right rim, facing left
    start = (cx + 38, cy - 20)
    gone = (cx - 44, cy - 34)

    close = frame(cx + 0.6, cy - 0.6, 17)
    wide = frame(cx + 3.0, cy - 2.5, 24)
    habitat = S.habitat

    # the feeding: one dip of the father's head per chick, each a second long
    feed_at = [10.6, 11.7, 12.8]
    land_at, fold_at, lift_at = 8.3, 9.0, 9.6
    leave_at = 14.0

    def wing(t, rate, amp=44, base=-22):
        a = 2*math.pi*rate*t
        return base + amp*math.sin(a), base + 6 + amp*math.sin(a - 0.7)

    # ---- the father
    def father():
        out = []
        for i in range(n):
            t = i/FPS
            f = base_frame(close)
            f['face'] = -1
            p = f['parts']
            def pose(spread=0.0, fold=1.0, flap=None, head=0.0, tail=0.0, beak=0.0, prey=(0, 0), hide=1.0, blink=1.0):
                tiny = 0.01
                p['spread'] = (max(tiny, spread),)*2
                p['fold'] = (max(tiny, fold),)*2
                p['wingN'], p['wingF'] = (flap if flap is not None else (-30, -24))
                p['head'], p['tail'], p['beak'] = head, tail, beak
                p['prey'], p['preyhide'] = prey, (max(tiny, hide),)*2
                p['eye'] = (1, blink)
            rot, feet = 0.0, perch
            fish_in_feet = (0, 0)
            fish_at_bill = (27, -69)                     # from the feet to the bill, in design units
            if t < 5.0:                                  # not yet there
                f['alpha'] = 0
                feet = start
                pose(1, 0, wing(t, 2.4))
            elif t < land_at:                            # glides in over the peak, flapping slowly, flares
                u = (t - 5.0)/(land_at - 5.0)
                e = u**0.85
                feet = bezier(start, (cx + 22, cy - 30), (cx + 12, cy - 9), perch, e)
                ahead = bezier(start, (cx + 22, cy - 30), (cx + 12, cy - 9), perch, min(1, e + 0.02))
                lean = max(-25, min(25, math.degrees(math.atan2(ahead[1] - feet[1], -(ahead[0] - feet[0])))*0.7))
                rot = -lean
                glide = 0.25 < u < 0.55
                fl = wing(t, 1.3 if u < 0.7 else 2.6, 44 if not glide else 6, -22 if not glide else -28)
                pose(1, 0, fl, tail=-6 + 8*math.sin(t*3))
                f['alpha'] = clamp((t - 5.0)/0.4)
                f['airborne'] = u < 0.97
                if u > 0.7:
                    rot = 36*ease(clamp((u - 0.7)/0.3))   # braking: it rears up, wings forward
            elif t < fold_at:                            # lands on the rim, wings still out for balance
                u = (t - land_at)/(fold_at - land_at)
                fl = wing(t, 2.6, 30*(1 - u), -10)
                pose(1, 0, fl)
                rot = 36*(1 - ease(u))
                f['sy'] = 1 - 0.06*math.sin(u*math.pi)
            elif t < lift_at:                            # folds the wings, brings the fish up to its bill
                u = ease((t - fold_at)/(lift_at - fold_at))
                pose(1 - u, u, (-25*(1 - u), -20*(1 - u)), prey=(fish_at_bill[0]*u, fish_at_bill[1]*u))
            elif t < leave_at:                           # holds the fish out, dips to each chick in turn
                dip = 0.0
                eaten = 0.0
                for k, t0 in enumerate(feed_at):
                    u = (t - t0)/1.0
                    if 0 <= u <= 1:
                        dip = math.sin(u*math.pi)**0.8
                    eaten += clamp((t - t0 - 0.2)/0.4)/3.0      # a third of the fish for each chick
                shrink = 1.0 - eaten
                look_up = ease(clamp((t - 13.0)/0.4))*(1 - ease(clamp((t - 13.6)/0.3)))
                pose(0, 1, (-25, -20), head=24*dip - 8*look_up, tail=2*math.sin(t*2),
                     prey=fish_at_bill, hide=max(0.01, shrink),
                     beak=14*dip*0.0, blink=0.1 if 12.2 < t < 12.32 else 1)
                f['sy'] = 1 - 0.03*dip
                if t < feed_at[0] - 0.3:
                    f['sy'] = 1
            elif t < 14.8:                               # crouches, spreads, pushes off
                u = (t - leave_at)/0.8
                crouch = math.sin(min(1, u)*math.pi*0.5)
                pose(ease(clamp(u*1.4)), 1 - ease(clamp(u*1.4)), wing(t, 3.0, 40*u, -20), hide=0.0)
                f['sy'] = 1 - 0.10*crouch*(1 - ease(clamp((u - 0.6)/0.4)))
                rot = 8*crouch
                feet = (perch[0] - 1.5*ease(clamp((u - 0.6)/0.4)), perch[1] - 1.5*ease(clamp((u - 0.6)/0.4)))
                f['airborne'] = u > 0.8
            else:                                        # flies off to the upper left, over the mountains
                u = clamp((t - 14.8)/3.6)
                e = u**1.25
                a = (perch[0] - 1.5, perch[1] - 1.5)
                feet = bezier(a, (cx + 1, cy - 12), (cx - 16, cy - 28), gone, e)
                ahead = bezier(a, (cx + 1, cy - 12), (cx - 16, cy - 28), gone, min(1, e + 0.02))
                lean = math.degrees(math.atan2(ahead[1] - feet[1], -(ahead[0] - feet[0])))*0.6
                rot = -max(-30, min(30, lean))
                pose(1, 0, wing(t, 2.3, 44, -22), hide=0.0)
                f['airborne'] = True
                f['alpha'] = 1 - clamp((t - 17.4)/0.6)
            f['feet'], f['rot'] = feet, rot
            out.append(f)
        return out

    # ---- the mother
    def mother():
        out = []
        for i in range(n):
            t = i/FPS
            f = base_frame(close)
            p = f['parts']
            p['head'] = 0.0
            p['eye'] = (1, 1)
            f['feet'] = mother_feet
            # looks round slowly, now and then at the sky, blinks
            look = 6*math.sin(t*0.9)
            if 6.4 < t < 9.5:                            # follows her mate in
                look = lerp(look, -8, ease(clamp((t - 6.4)/0.8)))*(1 - ease(clamp((t - 9.0)/0.5)))
            if 13.0 < t < 14.6:
                look = -6*math.sin((t - 13.0)/1.6*math.pi)
            p['head'] = look
            p['eye'] = (1, 0.1 if 1.9 < t < 2.02 or 10.9 < t < 11.02 else 1)
            lift = math.sin(math.pi*clamp((t - 2.5)/0.9))   # shifts her weight and settles
            big = 1.25                                   # the mother is the biggest in the nest
            f['sy'] = big*(0.93 + 0.04*lift)
            f['sx'] = big*(1 + 0.01*lift)
            if t > length - 0.6:
                f['alpha'] = (length - t)/0.6
            out.append(f)
        return out

    # ---- the chicks: down in the nest, up and begging when the father is near, down again
    def chicks():
        figs = []
        for k, feet in enumerate(chick_feet):
            out = []
            ups = 7.7 + 0.25*k
            downs = 14.6 + 0.2*k
            for i in range(n):
                t = i/FPS
                f = base_frame(close)
                p = f['parts']
                up = ease(clamp((t - ups)/0.5))*(1 - ease(clamp((t - downs)/0.5)))
                f['alpha'] = clamp(up*2.2)
                f['feet'] = (feet[0], feet[1] - 1.8*up)
                f['sx'] = f['sy'] = 1.0
                # begging: the mouth opens and shuts; wide when the father comes to it, shut as it swallows
                gape = 0.55 + 0.45*abs(math.sin(t*5 + k*1.7))
                t0 = feed_at[k]
                if t0 - 0.45 < t < t0 + 0.15:
                    gape = 1.0
                elif t0 + 0.15 <= t < t0 + 0.55:
                    gape = 0.12
                elif t >= t0 + 0.55 and t < downs - 0.8:
                    gape = 0.2 + 0.2*abs(math.sin(t*3 + k))
                p['gape'] = (1.0, max(0.1, gape))
                if t > length - 0.6:
                    f['alpha'] = min(f['alpha'], (length - t)/0.6)
                out.append(f)
            figs.append(dict(frames=out, body=fc.chick_body, parts=fc.CHICK_PARTS, scale=scale*0.9,
                             feet=fc.CHICK_FEET, shadow=None))
        return figs

    # ---- the camera: close, then wide, then the habitat; the mother's frames carry it
    mom = mother()
    for i, f in enumerate(mom):
        t = i/FPS
        if t < 3.4:
            v = close
        elif t < 5.2:
            v = lerp_view(close, wide, ease((t - 3.4)/1.8))
        elif t < 14.4:
            v = wide
        else:
            v = lerp_view(wide, habitat, ease(clamp((t - 14.4)/3.2)))
        f['view'] = v

    rim_front = dict(frames=[dict(base_frame(close), feet=(0, 0))]*2, body=_still_world(nest.nest_front(cx, cy)),
                     parts={}, scale=1.0, feet=(0, 0), shadow=None)
    dad = dict(frames=father(), body=fe.eagle_body, parts=fe.EAGLE_PARTS, scale=scale, feet=fe.EAGLE_FEET,
               shadow=fe.EAGLE_SHADOW)
    # the father's frames are followed by the camera as well, though the mother's carry the view
    return dict(S=S, length=length, frames=mom, body=fe.eagle_brooding, parts=fe.EAGLE_PARTS,
                feet=fe.EAGLE_FEET, shadow=None, below=lambda frames: nest.nest_back(cx, cy),
                file='adler-horst-animation.svg', others=chicks() + [rim_front, dad])


def render():
    story = eagle_nest()
    S = story['S']
    return write(story['file'], S.s, S.cams['weit'], story['frames'], story['length'], story['body'],
                 story['parts'], S.scale, story['feet'], shadow=story['shadow'], below=story['below'],
                 others=story['others'])


if __name__ == '__main__':
    print(render())
