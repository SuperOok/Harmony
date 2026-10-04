"""The raven: flies in low over the field on the new flight pose
(fig_raven_flight), rears up to land, folds its wings, hops twice, caws
three times and looks about.

    python3 tools/szenen/stories.py Rabe

Told here, in a file of its own, and handed over by stories.py. As with the
eagle there are two figures that take over from each other at touchdown: the
one in the air (wings turned in space) and the one on the ground (folded).
"""
import math

from anim import FPS, ease, clamp, lerp, lerp_view, lerp2, frame, jump, base_frame
import fig_bird as fbird
import fig_raven_flight as frf
from stories import Setup, bezier, bird_pose


def ravens():
    S = Setup('Rabe')
    length = 14.0
    n = int(length*FPS)
    spot = S.spot
    start = (spot[0] - 28, spot[1] - 17)
    hop1 = (spot[0] + 1.4, spot[1] + 0.3)
    hop2 = (spot[0] + 2.6, spot[1] - 0.3)
    close = S.close(0.2, 5.0)
    wide = frame(spot[0] + 1, spot[1] - 2, 20)
    habitat = S.habitat
    c1, c2 = (spot[0] - 14, spot[1] - 20), (spot[0] - 8, spot[1] - 8)
    land_at, cut_in = 2.8, 3.2
    tiny = 0.01
    approach = lambda e: bezier(start, c1, c2, spot, e)

    def flap(t, rate, base, amp, lag=0.55):
        ph = 2*math.pi*rate*t
        arm = base + amp*math.cos(ph)
        return arm, arm + lag*amp*math.sin(ph)

    def fly_pose(p, e, legs=82.0, fan=1.0, tail=0.0, head=0.0, spread=1.0):
        arm, hand = e
        p['wingN'], p['wingNl'] = frf.raven_wing_paths(arm, hand, True, spread)
        p['wingF'], p['wingFl'] = frf.raven_wing_paths(arm - 4, hand - 2, False, spread)
        p['legs'], p['tail'], p['fan'], p['head'] = legs, tail, (1, fan), head
        p['beak'], p['eye'] = 0.0, (1, 1)

    def views(t):                                          # close, then wide, then the farm
        if t < 5.0:
            return close
        if t < 6.0:
            return lerp_view(close, wide, ease(t - 5.0))
        if t < 10.0:
            return wide
        return lerp_view(wide, habitat, ease(clamp((t - 10.0)/3.0)))

    # ---- in the air
    flying = []
    for i in range(n):
        t = i/FPS
        f = base_frame(views(t))
        p = f['parts']
        f['alpha'] = 0
        feet, rot = spot, 0.0
        fly_pose(p, (14, 6))
        if 0.4 <= t < land_at:                             # flies in over the field, quick wingbeats, then the flare
            u = (t - 0.4)/(land_at - 0.4)
            e = u**0.85
            feet = approach(e)
            ahead = approach(min(1, e + 0.02))
            pitch = max(-22, min(22, math.degrees(math.atan2(ahead[1] - feet[1], ahead[0] - feet[0]))*0.6))
            f['alpha'] = clamp((t - 0.4)/0.3)
            flare = ease(clamp((u - 0.72)/0.28))
            arm, hand = flap(t, 3.4 if u < 0.7 else 4.2, 12, 38)
            e1 = (lerp(arm, 70, flare), lerp(hand, 58, flare))
            fly_pose(p, e1, legs=lerp(82, -22, flare), fan=1 + 0.3*flare, tail=-6*flare)
            rot = pitch*(1 - flare) - 80*flare
            f['ground'] = (feet[0], spot[1])             # the shadow runs along the ground below it
            f['shadow'] = clamp((u - 0.1)/0.5)*0.6 + 0.2*u
        elif land_at <= t < cut_in:                        # touches down, the wings fold in
            u = ease((t - land_at)/(cut_in - land_at))
            f['alpha'] = 1
            feet, rot = spot, -80.0 + 4*u
            fly_pose(p, (lerp(70, 80, u), lerp(58, 72, u)), legs=-22, fan=1.3, spread=lerp(1.0, 0.18, u))
        f['feet'], f['rot'] = feet, rot
        flying.append(f)

    # ---- on the ground
    walking = []
    for i in range(n):
        t = i/FPS
        f = base_frame(views(t))
        p = f['parts']
        f['alpha'] = 1 if t >= cut_in else 0
        feet = spot
        if t < 4.0:                                        # stands, a first look about
            bird_pose(p, 0, 1, 1, head=-8*math.sin((t - cut_in)*4), tail=3*math.sin(t*6))
        elif t < 6.0:                                      # hops forward twice, head cocked
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
        elif t < 9.0:                                      # it caws, three times
            feet = hop2
            cry_n = (t - 6.0)/3.0*3
            k = cry_n - int(cry_n)
            caw = math.sin(min(1, k/0.5)*math.pi) if k < 0.5 and cry_n < 3 else 0
            bird_pose(p, 0, 1, 1, head=-18*caw + 4*math.sin(t*2), tail=-8*caw, beak=24*caw,
                      blink=0.1 if 8.3 < t < 8.42 else 1)
            f['sy'] = 1 + 0.04*caw
        elif t < 10.4:                                     # looks about
            feet = hop2
            bird_pose(p, 0, 1, 1, head=14*math.sin((t - 9.0)*3)*(1 - (t - 9.0)/1.4))
        else:                                              # and the farm below it, the second pull-back
            feet = hop2
            bird_pose(p, 0, 1, 1, head=5*math.sin(t*2))
        if t > length - 0.5:
            f['alpha'] = min(f['alpha'], (length - t)/0.5)
        f['feet'], f['rot'] = feet, 0.0
        walking.append(f)
    perched = dict(frames=walking, body=fbird.raven_body, parts=fbird.BIRD_PARTS, scale=S.scale,
                   feet=fbird.BIRD_FEET, shadow=fbird.RAVEN_SHADOW)
    return dict(S=S, length=length, frames=flying, body=frf.raven_flight_body, parts=frf.RAVEN_PARTS,
                feet=frf.RAVEN_FEET, shadow=fbird.RAVEN_SHADOW, below=None, file='rabe-animation.svg',
                others=[perched])
