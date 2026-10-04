"""The ladybirds: two crawl slowly through the grass; a third crawls over a
bush, stops, opens its wing cases, unfolds its wings and flies down to
join them.

    python3 tools/szenen/stories.py Marienkäfer

Told here, in a file of its own, and handed over by stories.py. The
camera starts closer, on the bush and the meadow, but not as close as the
first try; it pulls back once, to show the meadow, and stays there. The
three keep to patches of their own, so that they do not crawl over one
another.
"""
import math

from anim import FPS, ease, clamp, lerp, lerp_view, lerp2, frame, base_frame
import fig_bug as fb
from stories import Setup, bezier


def ladybirds():
    S = Setup('Marienkäfer')
    length = 14.5
    n = int(length*FPS)
    b = S.s.b
    bush_cell = (-1, 0)                                  # the bush beside the first cube's meadow
    bx, by = b.pos(*bush_cell)
    sx0, sy0 = S.spot
    close = frame(sx0 - 9, sy0 - 5.0, 25)
    wide = frame(sx0 - 3, sy0 - 4.5, 36)

    land = (sx0 + 1.5, sy0 - 0.4)                        # where the third comes down, between the other two
    over = lambda u: (bx - 4.0 + 8.2*u, by - 3.4 - 1.4*math.sin(math.pi*u))   # over the bush, left to right
    top = over(1.0)

    def heading(a, b_):                                  # degrees clockwise from straight up the screen
        return math.degrees(math.atan2(b_[0] - a[0], -(b_[1] - a[1])))

    def legs(p, t, speed, phase=0.0, rate=16.0):
        w = math.sin(t*rate + phase)*min(1.0, speed)
        p['legsA'], p['legsB'] = 9*w, -9*w

    def feelers(p, t, a=1.0, k=7.0, phase=0.0):
        p['antL'] = a*9*math.sin(t*k + phase)
        p['antR'] = a*9*math.sin(t*k + 2.1 + phase)

    # ---- the third: over the bush, off the bush, down to the meadow
    def third():
        out = []
        t_stop, t_open, t_fly, t_land = 3.7, 5.0, 6.0, 8.6
        lift = lambda u: bezier(top, (top[0] + 5, top[1] - 7), (land[0] - 8, land[1] - 8), land, u)
        for i in range(n):
            t = i/FPS
            f = base_frame(close)
            f['sy'] = 0.9
            p = f['parts']
            p['wings'] = fb.CLOSED
            p['elytraL'] = p['elytraR'] = 0.0
            feet, rot = top, 90.0
            f['ground'] = (bx, by + 0.6)
            f['shadow'] = 0.0
            if t < 0.4:
                f['alpha'] = 0
                feet = over(0.0)
                rot = 80.0
            elif t < t_stop:                             # crawls over the top of the bush
                u = (t - 0.4)/(t_stop - 0.4)
                e = ease(u)*0.5 + u*0.5
                feet = over(e)
                nxt = over(min(1, e + 0.02))
                rot = heading(feet, nxt) + 7*math.sin(t*5)
                f['alpha'] = clamp((t - 0.4)/0.4)
                legs(p, t, 1.0)
                feelers(p, t, 1.0, 9)
                f['shadow'] = 0.0
            elif t < t_open:                             # stops at the edge, feelers feel the air
                feet, rot = top, 90.0
                feelers(p, t, 1.5, 6)
                if t < t_stop + 0.3:
                    legs(p, t, 0.5)
            elif t < t_fly:                              # opens its wing cases, unfolds the wings, whirrs
                u = (t - t_open)/(t_fly - t_open)
                op = ease(clamp(u/0.4))
                p['elytraL'], p['elytraR'] = 62*op, -62*op
                flutter = 1 + 0.2*math.sin(t*50)*op
                p['wings'] = (max(0.04, ease(clamp((u - 0.1)/0.4))*flutter), 1)
                feelers(p, t, 0.6, 5)
            elif t < t_land:                             # flies down to the meadow
                u = (t - t_fly)/(t_land - t_fly)
                e = ease(u)
                feet = lift(e)
                nxt = lift(min(1, e + 0.02))
                rot = heading(feet, nxt)*0.9
                p['elytraL'], p['elytraR'] = 62, -62
                p['wings'] = (1 + 0.2*math.sin(t*50), 1)
                f['sy'] = 0.9 + 0.1*math.sin(math.pi*u)
                f['ground'] = lerp2((bx, by + 0.6), (land[0], land[1] + 0.1), e)
                f['shadow'] = 0.9
                feelers(p, t, 0.5, 5)
                if u > 0.88:                             # touching down: the cases close, the wings fold
                    k = ease((u - 0.88)/0.12)
                    p['elytraL'], p['elytraR'] = 62*(1 - k), -62*(1 - k)
                    p['wings'] = (max(0.04, 1 - k), 1)
                    rot = lerp(rot, 20.0, k)
            else:                                        # on the meadow: crawls slowly, like the others
                u = t - t_land
                feet = (land[0] + 0.6*math.sin(u*0.5), land[1] - 0.4*(1 - math.cos(u*0.5)))
                rot = 20 + 25*math.sin(u*0.5)
                legs(p, t, 0.4 + 0.3*math.sin(u*0.9))
                feelers(p, t, 0.8, 5)
                f['ground'] = feet
                f['shadow'] = 0.9
            f['feet'], f['rot'] = feet, rot
            if t > length - 0.6:
                f['alpha'] = min(f['alpha'], (length - t)/0.6)
            out.append(f)
        return out

    # ---- the two in the meadow: slow, with pauses, feelers busy
    def crawler(centre, radius, phase, rate, tilt):
        out = []
        for i in range(n):
            t = i/FPS
            f = base_frame(close)
            f['sy'] = 0.9
            p = f['parts']
            p['wings'] = fb.CLOSED
            p['elytraL'] = p['elytraR'] = 0.0
            def at(tt):
                th = phase + rate*(0.55*tt + 0.55*math.sin(0.9*tt + phase))   # nearly stops now and then
                return th, (centre[0] + radius[0]*math.cos(th), centre[1] + radius[1]*math.sin(th))
            th, pos = at(t)
            th2, pos2 = at(t + 0.04)
            speed = math.hypot(pos2[0] - pos[0], (pos2[1] - pos[1])/0.42)/0.04
            f['feet'] = pos
            f['rot'] = heading(pos, pos2) + tilt
            f['ground'] = pos
            f['shadow'] = 0.9
            legs(p, t, speed/0.5, phase)
            feelers(p, t, 1.0 if speed < 0.25 else 0.5, 6 + phase, phase)
            if t > length - 0.6:
                f['alpha'] = (length - t)/0.6
            out.append(f)
        return out

    third_frames = third()
    for i, f in enumerate(third_frames):                 # the camera is the third one's
        t = i/FPS
        if t < 4.6:
            f['view'] = close
        elif t < 7.8:
            f['view'] = lerp_view(close, wide, ease((t - 4.6)/3.2))
        else:
            f['view'] = wide                             # ends here: no second pull-back

    b_frames = crawler((sx0 - 4.8, sy0 + 1.2), (2.2, 0.8), 0.6, 1.0, 0)      # each keeps to a patch of its own
    c_frames = crawler((sx0 + 7.6, sy0 - 0.8), (2.2, 0.8), 2.5, -1.0, 0)
    for fr in (b_frames, c_frames):
        for i, f in enumerate(fr):
            f['view'] = third_frames[i]['view']
    extra = lambda frames: dict(frames=frames, body=fb.bug_body, parts=fb.BUG_PARTS, scale=S.scale,
                                feet=fb.BUG_FEET, shadow=fb.BUG_SHADOW)
    depth = max(sy0, by) + 1.0                           # among the grass: the blades in front hide them a little
    return dict(S=S, length=length, frames=third_frames, body=fb.bug_body, parts=fb.BUG_PARTS,
                feet=fb.BUG_FEET, shadow=fb.BUG_SHADOW, below=None, file='marienkaefer-animation.svg',
                depth=depth, others=[extra(b_frames), extra(c_frames)])
