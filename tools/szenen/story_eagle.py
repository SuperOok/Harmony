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
import fig_eagle_flight as ff
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
    lift_off = (perch[0] - 0.4, perch[1] - 0.4)      # where the push-off ends and the flight begins

    # ---- the father: two figures that take over from each other, the one in the air
    # (fig_eagle_flight, wings turned in space) and the one on the rim (fig_eagle, folded)
    cut_in = land_at + 0.4                       # the flying figure hands over to the perched one
    cut_out = leave_at + 0.8                     # and takes over again for the take-off
    tiny = 0.01

    def flap(t, rate, base, amp, lag=0.55):
        """Angles of arm and hand: the arm beats between base - amp and base + amp, the hand trails it."""
        ph = 2*math.pi*rate*t
        arm = base + amp*math.cos(ph)
        return arm, arm + lag*amp*math.sin(ph)

    def fly_pose(p, e, legs=82.0, fan=1.0, tail=0.0, head=0.0, spread=1.0, hide=1.0, blink=1.0):
        arm, hand = e
        p['wingN'], p['wingNl'] = ff.wing_paths(arm, hand, True, spread)
        p['wingF'], p['wingFl'] = ff.wing_paths(arm - 4, hand - 2, False, spread)
        p['legs'], p['tail'], p['fan'], p['head'] = legs, tail, (1, fan), head
        p['beak'], p['eye'], p['preyhide'] = 0.0, (1, blink), (max(tiny, hide),)*2

    def lean_of(path, e):
        ahead = path(min(1, e + 0.02))
        here = path(e)
        return math.degrees(math.atan2(ahead[1] - here[1], -(ahead[0] - here[0])))

    def father_flight():
        out = []
        approach = lambda e: bezier(start, (cx + 22, cy - 30), (cx + 12, cy - 9), perch, e)
        leave = lambda e: bezier(lift_off, (cx + 1, cy - 12), (cx - 16, cy - 28), gone, e)
        for i in range(n):
            t = i/FPS
            f = base_frame(close)
            f['face'] = -1
            p = f['parts']
            f['alpha'] = 0
            feet, rot = perch, 0.0
            fly_pose(p, (14, 6))
            if 5.0 <= t < land_at:                           # glides in, a few slow beats, then the flare
                u = (t - 5.0)/(land_at - 5.0)
                e = u**0.85
                feet = approach(e)
                f['alpha'] = clamp((t - 5.0)/0.4)
                f['airborne'] = True
                pitch = max(-20, min(20, lean_of(approach, e)*0.6))
                if u < 0.2:
                    e1 = flap(t, 1.5, 12, 36)
                elif u < 0.55:
                    e1 = (14 + 3*math.sin(t*2), 6 + 2*math.sin(t*2 + 1))   # soaring: wings out and still
                elif u < 0.78:
                    e1 = flap(t, 2.2, 14, 38)
                else:                                        # the flare: wings up, body upright, feet forward
                    k = ease(clamp((u - 0.78)/0.22))
                    arm, hand = flap(t, 3.0, 14, 38)
                    e1 = (lerp(arm, 70, k), lerp(hand, 58, k))
                flare = ease(clamp((u - 0.74)/0.26))
                rot = -pitch*(1 - flare) + 80*flare
                fly_pose(p, e1, legs=lerp(82, -22, flare), fan=1 + 0.35*flare, tail=-8*flare)
            elif land_at <= t < cut_in:                      # touches down and folds the wings in
                u = ease((t - land_at)/(cut_in - land_at))
                f['alpha'] = 1
                feet, rot = perch, 80.0 - 4*u
                fly_pose(p, (lerp(70, 80, u), lerp(58, 72, u)), legs=-22, fan=1.35, spread=lerp(1.0, 0.18, u))
            elif cut_out <= t:                               # the push-off: up, then level and away
                u = clamp((t - cut_out)/3.2)
                f['alpha'] = 1 - clamp((t - 17.4)/0.6)
                f['airborne'] = True
                e = u**1.2
                feet = leave(e)
                pitch = max(-30, min(30, lean_of(leave, e)*0.6))
                k = ease(clamp(u/0.18))
                rot = lerp(80.0, -pitch, k)
                arm, hand = flap(t, 2.2, 14, 40)
                grow = ease(clamp((t - cut_out)/0.25))
                fly_pose(p, (lerp(75, arm, k), lerp(62, hand, k)), legs=lerp(-22, 82, ease(clamp((u - 0.05)/0.2))),
                         fan=1.3 - 0.3*k, spread=0.35 + 0.65*grow, hide=0.0)
            f['feet'], f['rot'] = feet, rot
            out.append(f)
        return out

    def father_perched():
        out = []
        fish_at_bill = (27, -69)                         # from the feet to the bill, in design units
        for i in range(n):
            t = i/FPS
            f = base_frame(close)
            f['face'] = -1
            p = f['parts']
            f['alpha'] = 1 if cut_in <= t < cut_out else 0
            def pose(head=0.0, tail=0.0, prey=(0, 0), hide=1.0, blink=1.0):
                p['spread'], p['fold'] = (tiny,)*2, (1, 1)
                p['wingN'], p['wingF'] = -25, -20
                p['head'], p['tail'], p['beak'] = head, tail, 0.0
                p['prey'], p['preyhide'] = prey, (max(tiny, hide),)*2
                p['eye'] = (1, blink)
            feet = perch
            if t < lift_at:                              # stands on the rim; the fish comes up to its bill
                u = ease(clamp((t - fold_at)/(lift_at - fold_at)))
                pose(prey=(fish_at_bill[0]*u, fish_at_bill[1]*u))
            elif t < leave_at:                           # holds the fish out, dips to each chick in turn
                dip = 0.0
                eaten = 0.0
                for k, t0 in enumerate(feed_at):
                    u = (t - t0)/1.0
                    if 0 <= u <= 1:
                        dip = math.sin(u*math.pi)**0.8
                    eaten += clamp((t - t0 - 0.2)/0.4)/3.0      # a third of the fish for each chick
                look_up = ease(clamp((t - 13.0)/0.4))*(1 - ease(clamp((t - 13.6)/0.3)))
                pose(head=24*dip - 8*look_up, tail=2*math.sin(t*2), prey=fish_at_bill, hide=max(tiny, 1.0 - eaten),
                     blink=0.1 if 12.2 < t < 12.32 else 1)
                f['sy'] = 1 - 0.03*dip
            else:                                        # crouches to push off
                u = clamp((t - leave_at)/0.8)
                crouch = math.sin(u*math.pi*0.5)
                pose(hide=0.0, tail=4*crouch)
                f['sy'] = 1 - 0.12*crouch
                f['sx'] = 1 + 0.04*crouch
                p['wingN'], p['wingF'] = -25, -20
            f['feet'], f['rot'] = feet, 0.0
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
    dad_perched = dict(frames=father_perched(), body=fe.eagle_body, parts=fe.EAGLE_PARTS, scale=scale,
                       feet=fe.EAGLE_FEET, shadow=None)
    dad_flying = dict(frames=father_flight(), body=ff.flight_body, parts=ff.FLIGHT_PARTS, scale=scale,
                      feet=ff.FLIGHT_FEET, shadow=None)
    # the father's frames are followed by the camera as well, though the mother's carry the view
    return dict(S=S, length=length, frames=mom, body=fe.eagle_brooding, parts=fe.EAGLE_PARTS,
                feet=fe.EAGLE_FEET, shadow=None, below=lambda frames: nest.nest_back(cx, cy),
                file='adler-horst-animation.svg', others=chicks() + [rim_front, dad_perched, dad_flying])


def render():
    story = eagle_nest()
    S = story['S']
    return write(story['file'], S.s, S.cams['weit'], story['frames'], story['length'], story['body'],
                 story['parts'], S.scale, story['feet'], shadow=story['shadow'], below=story['below'],
                 others=story['others'])


if __name__ == '__main__':
    print(render())
