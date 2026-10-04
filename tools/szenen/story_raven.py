"""Three ravens. The first sits on the rim of a chimney and flies off; a
second comes flying in from the right; the two circle once over the field
and land on it at once, where a third raven has been sitting all along.

    python3 tools/szenen/stories.py Rabe

Told here, in a file of its own, and handed over by stories.py. The camera
starts close on the house with the first raven, pulls back once to show the
field and both houses, and stays there: no second pull-back.

Every flying raven is two figures that take over from each other at
take-off or touchdown: the one in the air, on the flight pose of
fig_raven_flight (wings turned in space), and the one on the ground, folded
and leaning well forward (fig_bird). The two match where they hand over:
the flying figure is turned 45 degrees nose-up with its legs hanging, which
is how the standing one leans. Five figures in all: the first raven on the
chimney and in the air, the second in the air and on the ground, the third
only on the ground. The camera is the first raven's flying figure's.

The pair circles counter-clockwise on the screen: along the bottom to the
right, up the right side, back along the top to the left. That way the first
raven, leaving the chimney on the left, swoops down into the bottom of the
circle going right, and the second, coming in from the right, joins at the
top going left; both land coming along the bottom, moving right.
"""
import math

from anim import FPS, ease, clamp, lerp, lerp_view, lerp2, frame, jump, base_frame
import fig_bird as fbird
import fig_raven_flight as frf
from stories import Setup, bezier, bird_pose


def ravens():
    S = Setup('Rabe')
    length = 16.5
    n = int(length*FPS)
    b = S.s.b
    hx, hy = b.pos(-1, 0)                                  # the left house
    chim = (hx + 3.86 - 0.95, hy - 11.4 + 0.2)             # the rim of its chimney, not the hole
    sx0, sy0 = S.spot                                      # the field between the houses

    close = frame(chim[0] + 2.4, chim[1] - 1.5, 19)
    wide = frame(sx0, sy0 - 9, 44)

    # the circle over the field, seen at the board's slant: an ellipse, counter-clockwise on the screen
    centre, rad = (sx0, sy0 - 21.0), (17.0, 6.0)      # up so that the first raven climbs away from the chimney
    omega = 2*math.pi/5.0                                  # a lap in five seconds
    ep = lambda ph: (centre[0] + rad[0]*math.cos(ph), centre[1] - rad[1]*math.sin(ph))
    ph1_0, ph2_0 = 1.2*math.pi, 0.35*math.pi               # where they join: bottom left, top right
    t_off, t1_circle = 2.4, 3.6                            # the first leaves the chimney, and is on the circle
    t2_in, t2_circle = 3.0, 5.4                            # the second appears at the right edge, and joins
    ph1 = lambda t: ph1_0 + omega*(t - t1_circle)
    ph2 = lambda t: ph2_0 + omega*(t - t2_circle)
    r1_dive = t1_circle + 5.0                              # one lap, back at the bottom left
    r2_dive = t2_circle + (1.5*math.pi - ph2_0)/omega      # round to the bottom middle
    r1_land, r2_land = r1_dive + 1.8, r2_dive + 1.8
    fold = 0.4                                             # touchdown to the hand-over

    spots = {'r3': (sx0 - 5.8, sy0 + 0.0), 'r1': (sx0 + 0.0, sy0 - 0.4), 'r2': (sx0 + 5.8, sy0 - 0.6)}
    s2_start = (sx0 + 40, sy0 - 27)

    # ---- the paths, as functions of time
    def r1_pos(t):
        if t < t_off:
            return chim
        if t < t1_circle:                                  # a hop off the rim and a swoop down into the circle
            u = (t - t_off)/(t1_circle - t_off)
            e = ep(ph1_0)
            return bezier(chim, (chim[0] + 3.5, chim[1] - 5.0), (e[0] - 4.0, e[1] - 2.0), e, u)
        if t < r1_dive:
            return ep(ph1(t))
        u = min(1, (t - r1_dive)/(r1_land - r1_dive))
        start = ep(ph1(r1_dive))
        return bezier(start, (start[0] + 5.0, start[1]), (spots['r1'][0] - 4.0, sy0 - 6.0), spots['r1'], u**0.9)

    def r2_pos(t):
        if t < t2_in:
            return s2_start
        if t < t2_circle:
            u = (t - t2_in)/(t2_circle - t2_in)
            e = ep(ph2_0)
            return bezier(s2_start, (sx0 + 30, sy0 - 34), (e[0] + 9.0, e[1] - 1.0), e, ease(u)*0.5 + u*0.5)
        if t < r2_dive:
            return ep(ph2(t))
        u = min(1, (t - r2_dive)/(r2_land - r2_dive))
        start = ep(ph2(r2_dive))
        return bezier(start, (start[0] + 4.0, start[1] + 0.3), (spots['r2'][0] - 1.5, sy0 - 5.5), spots['r2'], u**0.9)

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

    def views(t):                                          # close on the house, then wide, and it stays
        if t < 2.2:
            return close
        if t < 5.8:
            return lerp_view(close, wide, ease((t - 2.2)/3.6))
        return wide

    def velocity(path, t):
        a, c = path(t - 0.03), path(t + 0.03)
        return ((c[0] - a[0])/0.06, (c[1] - a[1])/0.06)

    STAND = 45.0        # the flying figure's nose-up turn that matches the standing raven's lean
    HANG = 40.0         # and its legs, turned back so that they hang straight down in the world

    # ---- one flying figure: the frames of a raven in the air
    def flight(path, t_from, phase, take_off=None, land=None):
        """take_off: when it pushes off the perch; land: (dive, touchdown) times."""
        out = []
        touch = land[1]
        for i in range(n):
            t = i/FPS
            f = base_frame(views(t))
            p = f['parts']
            f['alpha'] = 0
            f['feet'] = path(t_from)
            fly_pose(p, (14, 6))
            if t_from <= t < touch + fold:
                f['alpha'] = 1 if take_off is not None else clamp((t - t_from)/0.3)
                pos = path(t)
                vx, vy = velocity(path, t if t < touch else touch - 0.1)
                # it turns round at the circle's ends, going thin and fat again, instead of flipping
                turn = math.tanh(vx/6.0)
                if take_off is not None and t < t1_circle:
                    turn = 1.0
                if t >= land[0]:
                    turn = 1.0              # coming in to land, it flies right; the path ends nearly straight down,
                                            # where vx falls to 0 and the figure would be squeezed thin
                if abs(turn) < 0.03:
                    turn = 0.03
                sgn = 1 if turn > 0 else -1
                pitch = max(-22, min(22, math.degrees(math.atan2(vy, max(abs(vx), 3.0)))*0.6))
                rot = sgn*pitch*abs(turn)
                amp = 14 + 24*(0.5 + 0.5*math.sin(t*1.9 + phase))
                arm, hand = flap(t, 3.0, 12, amp)
                legs, fan, spread = 82.0, 1.0, 1.0
                if take_off is not None and t < take_off + 1.0:        # leaves the rim: nose up, legs down, wings up
                    k = ease(clamp((t - take_off)/1.0))
                    fl = flap(t, 3.2, 12, 40)
                    arm, hand = lerp(70, fl[0], k), lerp(58, fl[1], k)
                    legs = lerp(HANG, 82, ease(clamp((t - take_off - 0.1)/0.5)))
                    fan = 1.25 - 0.25*k
                    rot = lerp(-STAND, rot, k)
                    spread = 0.5 + 0.5*ease(clamp((t - take_off)/0.25))
                if t >= land[0]:                                       # the descent, the flare, the wings folding in
                    u = clamp((t - land[0])/(touch - land[0]))
                    flare = ease(clamp((u - 0.6)/0.4))
                    arm, hand = flap(t, 3.4, 12, 34)
                    arm, hand = lerp(arm, 70, flare), lerp(hand, 58, flare)
                    legs, fan = lerp(82, HANG, flare), 1 + 0.25*flare
                    rot = rot*(1 - flare) + (-sgn*STAND)*flare
                    if t >= touch:
                        k = ease((t - touch)/fold)
                        arm, hand = lerp(70, 82, k), lerp(58, 74, k)
                        spread = lerp(1.0, 0.18, k)
                fly_pose(p, (arm, hand), legs=legs, fan=fan, spread=spread)
                f['feet'], f['sx'], f['rot'] = pos, turn, rot
                f['ground'] = (pos[0], min(pos[1] + 12, sy0 + 2))   # the shadow lies on the field below it
                f['shadow'] = 0.5 if t < touch else 0.9
            out.append(f)
        return out

    # ---- one ground figure: standing, pecking, looking
    def ground(spot, t_from, t_to, face, label, phase=0.0):
        out = []
        for i in range(n):
            t = i/FPS
            f = base_frame(views(t))
            p = f['parts']
            f['alpha'] = 1 if t_from <= t < t_to else 0
            feet = spot
            f['face'] = face
            f['shadow'] = 1.0
            head, tail, beak, blink = 0.0, 0.0, 0.0, 1.0
            if label == 'r1' and t < t_off:                     # on the rim of the chimney: a look about, a blink, getting ready
                head = -10*math.sin(t*2.3) + 6
                blink = 0.1 if 1.2 < t < 1.32 else 1
                if t > t_off - 0.6:
                    c = ease(clamp((t - (t_off - 0.6))/0.6))
                    f['sy'] = 1 - 0.1*c
                    head = lerp(head, 8, c)
                f['shadow'] = 0.0
            elif label == 'r3':                                # pecks in the field, looks up at the others
                peck = max(0.0, math.sin(t*1.9 + phase))**3
                head = 24*peck - 6
                tail = 3*math.sin(t*3 + phase)
                look = ease(clamp((t - (r1_dive - 1.0))/0.6))*(1 - ease(clamp((t - (r2_land + 0.8))/0.5)))
                head = lerp(head, -16, look)
                if r2_land + 1.8 < t < r2_land + 3.0:          # a caw in greeting
                    k = math.sin(clamp((t - r2_land - 1.8)/1.2)*math.pi)
                    head, beak = -18*k, 24*k
                    f['sy'] = 1 + 0.04*k
            else:                                              # landed: turns to the third, looks about
                since = t - (r1_land if label == 'r1' else r2_land) - fold
                head = 8*math.sin(t*2.1 + phase)
                tail = 3*math.sin(t*4 + phase)
                if since > 0.5:                                # faces left, towards the third: through the middle
                    k = ease(clamp((since - 0.5)/0.5))
                    f['sx'] = lerp(1.0, -1.0, k)
            bird_pose(p, 0, 1, 1, head=head, tail=tail, beak=beak, blink=blink)
            if t > length - 0.6:
                f['alpha'] = min(f['alpha'], (length - t)/0.6)
            f['feet'] = feet
            f['rot'] = 0.0
            out.append(f)
        return out

    r1_air = flight(r1_pos, t_off, 0.0, take_off=t_off, land=(r1_dive, r1_land))
    r2_air = flight(r2_pos, t2_in, 2.0, land=(r2_dive, r2_land))
    r1_chimney = ground(chim, 0.0, t_off, 1, 'r1')
    r1_down = ground(spots['r1'], r1_land + fold, length + 1, 1, 'r1', 0.4)
    r2_down = ground(spots['r2'], r2_land + fold, length + 1, 1, 'r2', 1.7)
    r3_down = ground(spots['r3'], 0.0, length + 1, 1, 'r3', 0.9)

    def fig(frames, air):
        if air:
            return dict(frames=frames, body=frf.raven_flight_body, parts=frf.RAVEN_PARTS, scale=S.scale,
                        feet=frf.RAVEN_FEET, shadow=fbird.RAVEN_SHADOW)
        return dict(frames=frames, body=fbird.raven_body, parts=fbird.BIRD_PARTS, scale=S.scale,
                    feet=fbird.BIRD_FEET, shadow=fbird.RAVEN_SHADOW)
    others = [fig(r1_chimney, False), fig(r3_down, False), fig(r1_down, False), fig(r2_down, False), fig(r2_air, True)]
    return dict(S=S, length=length, frames=r1_air, body=frf.raven_flight_body, parts=frf.RAVEN_PARTS,
                feet=frf.RAVEN_FEET, shadow=fbird.RAVEN_SHADOW, below=None, file='rabe-animation.svg',
                others=others)
