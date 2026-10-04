"""Three ravens. The first sits on a chimney and flies off; a second comes
flying in from the right; the two circle once or twice over the field; then
both land on the field, where a third raven has been sitting all along.

    python3 tools/szenen/stories.py Rabe

Told here, in a file of its own, and handed over by stories.py. The camera
starts close on the house with the first raven, pulls back once to show the
field and both houses, and stays there: no second pull-back.

Every flying raven is two figures that take over from each other at
touchdown (or at take-off): the one in the air, on the flight pose of
fig_raven_flight (wings turned in space), and the one on the ground, folded
and leaning well forward (fig_bird). So five figures in all: the first
raven twice, the second twice, the third only on the ground. The camera is
the first raven's flying figure's.
"""
import math

from anim import FPS, ease, clamp, lerp, lerp_view, lerp2, frame, jump, base_frame
import fig_bird as fbird
import fig_raven_flight as frf
from stories import Setup, bezier, bird_pose


def ravens():
    S = Setup('Rabe')
    length = 20.5
    n = int(length*FPS)
    b = S.s.b
    hx, hy = b.pos(-1, 0)                                  # the left house
    chim = (hx + 3.86, hy - 11.4)                          # the top of its chimney
    sx0, sy0 = S.spot                                      # the field between the houses
    tiny = 0.01

    close = frame(chim[0] + 2.0, chim[1] - 1.5, 19)
    wide = frame(sx0, sy0 - 9, 44)

    # the circle over the field, seen at the board's slant: an ellipse
    centre, rad = (sx0, sy0 - 15.0), (17.0, 6.0)
    omega = 2*math.pi/5.0                                  # one lap in five seconds, clockwise on the screen
    ep = lambda th: (centre[0] + rad[0]*math.cos(th), centre[1] + rad[1]*math.sin(th))
    th1_0, t1_circle = math.pi, 4.4                        # the first enters on the left, at the chimney
    th2_0, t2_circle = 0.25*math.pi, 7.0                   # the second on the bottom right
    th1 = lambda t: th1_0 + omega*(t - t1_circle)
    th2 = lambda t: th2_0 + omega*(t - t2_circle)

    spots = {'r1': (sx0 - 5.8, sy0 - 0.6), 'r2': (sx0 + 0.0, sy0 - 0.4), 'r3': (sx0 + 5.8, sy0 + 0.0)}
    t_off = 3.0                                            # first raven leaves the chimney
    t2_in = 4.0                                            # second raven appears at the right edge
    r1_dive, r1_land = 13.15, 15.0
    r2_dive, r2_land = 12.0, 13.9
    fold = 0.4                                             # touchdown to the hand-over
    s2_start = (sx0 + 40, sy0 - 26)

    # ---- the paths, as functions of time
    def r1_pos(t):
        if t < t_off:
            return chim
        if t < t1_circle:
            u = (t - t_off)/(t1_circle - t_off)
            return jump(chim, ep(th1_0 + omega*0.0), ease(u), 3.0)
        if t < r1_dive:
            return ep(th1(t))
        u = (t - r1_dive)/(r1_land - r1_dive)
        return bezier(ep(th1(r1_dive)), (sx0 - 3, sy0 - 8.5), (spots['r1'][0] + 0.5, sy0 - 4.0), spots['r1'], min(1, u**0.9))

    def r2_pos(t):
        if t < t2_in:
            return s2_start
        if t < t2_circle:
            u = (t - t2_in)/(t2_circle - t2_in)
            return bezier(s2_start, (sx0 + 30, sy0 - 32), (sx0 + 20, sy0 - 22), ep(th2_0), ease(u)*0.5 + u*0.5)
        if t < r2_dive:
            return ep(th2(t))
        u = (t - r2_dive)/(r2_land - r2_dive)
        return bezier(ep(th2(r2_dive)), (sx0 + 8, sy0 - 13.5), (sx0 + 2, sy0 - 6.0), spots['r2'], min(1, u**0.9))

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
        if t < 2.4:
            return close
        if t < 6.4:
            return lerp_view(close, wide, ease((t - 2.4)/4.0))
        return wide

    def velocity(path, t):
        a, c = path(t - 0.03), path(t + 0.03)
        return ((c[0] - a[0])/0.06, (c[1] - a[1])/0.06)

    # ---- one flying figure: the frames of a raven in the air between two times
    def flight(path, t_from, t_to, kind, phase, take_off=None, land=None):
        """kind: how it moves. take_off: when it pushes off upright; land: (dive, touchdown) times."""
        out = []
        for i in range(n):
            t = i/FPS
            f = base_frame(views(t))
            p = f['parts']
            f['alpha'] = 0
            f['feet'] = path(min(max(t, t_from), t_to + fold))
            fly_pose(p, (14, 6))
            end = (land[1] + fold) if land else t_to
            if t_from <= t < end:
                f['alpha'] = clamp((t - t_from)/0.3) if take_off is None else 1
                pos = path(t)
                vx, vy = velocity(path, t if not (land and t >= land[1]) else land[1] - 0.1)
                turn = math.tanh(vx/6.0)                   # +1 flying right, -1 left, 0 head-on: it turns
                if take_off is not None and t < take_off + 0.9:
                    turn = 1.0                             # pushing off to the right
                pitch = max(-22, min(22, math.degrees(math.atan2(vy, max(abs(vx), 3.0)))*0.6))
                f['feet'] = pos
                f['sx'] = turn if abs(turn) > 0.02 else 0.02
                rot = pitch*(1 if turn >= 0 else -1)*abs(turn)
                amp = 14 + 24*(0.5 + 0.5*math.sin(t*1.9 + phase))
                arm, hand = flap(t, 3.0, 12, amp)
                legs, fan, spread = 82.0, 1.0, 1.0
                if take_off is not None and t < take_off + 0.9:       # pushes off upright, wings up, then levels out
                    k = ease(clamp((t - take_off)/0.9))
                    arm, hand = lerp(70, flap(t, 3.2, 12, 40)[0], k), lerp(58, flap(t, 3.2, 12, 40)[1], k)
                    legs = lerp(-22, 82, ease(clamp((t - take_off - 0.1)/0.5)))
                    fan = 1.3 - 0.3*k
                    rot = lerp(-75.0*(1 if turn >= 0 else -1), rot, k)
                    spread = 0.4 + 0.6*ease(clamp((t - take_off)/0.3))
                if land and t >= land[0]:                              # the descent, the flare, the wings folding in
                    u = clamp((t - land[0])/(land[1] - land[0]))
                    flare = ease(clamp((u - 0.7)/0.3))
                    arm, hand = flap(t, 3.4, 12, 34)
                    arm, hand = lerp(arm, 70, flare), lerp(hand, 58, flare)
                    legs, fan = lerp(82, -22, flare), 1 + 0.3*flare
                    rot = rot*(1 - flare) + 78*flare*(1 if turn >= 0 else -1)
                    if t >= land[1]:
                        k = ease((t - land[1])/fold)
                        arm, hand = lerp(70, 80, k), lerp(58, 72, k)
                        spread = lerp(1.0, 0.18, k)
                fly_pose(p, (arm, hand), legs=legs, fan=fan, spread=spread)
                f['rot'] = rot
                f['ground'] = (pos[0], min(pos[1] + 12, sy0 + 2))   # the shadow lies on the field below it
                f['shadow'] = 0.5 if (t < (land[1] if land else 1e9)) else 0.9
            out.append(f)
        return out

    # ---- one ground figure: standing, pecking, looking
    def ground(spot, t_from, t_to, face, label, phase=0.0):
        out = []
        for i in range(n):
            t = i/FPS
            f = base_frame(views(t))
            p = f['parts']
            on = t_from <= t < t_to
            f['alpha'] = 1 if on else 0
            feet = spot
            f['face'] = face
            f['shadow'] = 1.0
            head, tail, beak, blink = 0.0, 0.0, 0.0, 1.0
            if label == 'r1' and t < t_off:                     # on the chimney: a look about, a blink, getting ready
                head = -10*math.sin(t*2.3) + 6
                blink = 0.1 if 1.4 < t < 1.52 else 1
                if t > t_off - 0.7:
                    c = ease(clamp((t - (t_off - 0.7))/0.7))
                    f['sy'] = 1 - 0.12*c
                    head = lerp(head, 8, c)
                f['shadow'] = 0.0
            elif label == 'r3':                                # pecks in the field, looks up at the others
                peck = max(0.0, math.sin(t*1.9 + phase))**3
                head = 24*peck - 6
                tail = 3*math.sin(t*3 + phase)
                if r2_dive - 1.0 < t < r1_land + 1.5:             # looks up at them
                    head = lerp(head, -16, ease(clamp((t - (r2_dive - 1.0))/0.6)))*(1 if t < r1_land + 1.0 else 1 - clamp((t - r1_land - 1.0)/0.5))
                if 16.6 < t < 17.8:                            # a caw in greeting
                    k = math.sin(clamp((t - 16.6)/1.2)*math.pi)
                    head, beak = -18*k, 24*k
                    f['sy'] = 1 + 0.04*k
            else:                                              # landed: a look at the third, a little hop, looks about
                since = t - (r1_land if label == 'r1' else r2_land) - fold
                head = 8*math.sin(t*2.1 + phase)
                tail = 3*math.sin(t*4 + phase)
                if since > 0.6:                                # turns to face the third
                    k = ease(clamp((since - 0.6)/0.5))
                    f['sx'] = lerp(1.0, -1.0, k)               # face -1 flipped through the middle to face right
                if since > 2.2 and label == 'r1' and since < 3.0:   # one hop towards it
                    v = (since - 2.2)/0.8
                    feet = jump(spot, (spot[0] + 1.0, spot[1] + 0.1), ease(v), 1.0)
                    f['ground'] = lerp2(spot, (spot[0] + 1.0, spot[1] + 0.1), ease(v))
                elif since >= 3.0 and label == 'r1':
                    feet = (spot[0] + 1.0, spot[1] + 0.1)
            bird_pose(p, 0, 1, 1, head=head, tail=tail, beak=beak, blink=blink)
            if t > length - 0.6:
                f['alpha'] = min(f['alpha'], (length - t)/0.6)
            f['feet'] = feet
            f['rot'] = 0.0
            out.append(f)
        return out

    r1_air = flight(r1_pos, t_off, r1_land, 'r1', 0.0, take_off=t_off, land=(r1_dive, r1_land))
    r2_air = flight(r2_pos, t2_in, r2_land, 'r2', 2.0, land=(r2_dive, r2_land))
    r1_chimney = ground(chim, 0.0, t_off, 1, 'r1')
    r1_down = ground(spots['r1'], r1_land + fold, length + 1, -1, 'r1', 0.4)
    r2_down = ground(spots['r2'], r2_land + fold, length + 1, -1, 'r2', 1.7)
    r3_down = ground(spots['r3'], 0.0, length + 1, -1, 'r3', 0.9)
    # the chimney raven, the ground figures and the second flier, at the back of the cast first
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
