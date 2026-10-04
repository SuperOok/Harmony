"""The eagle in flight, seen from the side and a little from above, the way
a soaring eagle looks: the body level, the head thrust forward, the tail a
white fan, and two broad wings that reach out to either side, five
splayed feathers at each tip.

The wings are not rotated sprites. Each is a flat shape that is turned
about the body in space and flattened onto the picture, frame by frame,
so that it foreshortens the way a real wing does: level, the near wing
reaches down towards us and the far one up and away; raised, both go up;
on the downstroke the near one sweeps down past the belly. The story
hands over, per frame, two angles (the arm's and the hand's, the hand
trailing on the stroke, bending at the wrist) and gets the outlines as
paths from wing_paths(). The figure's `wingN`, `wingNl`, `wingF`, `wingFl`
parts are those paths, animated with the SVG `d` attribute.

Facing right. FLIGHT_FEET is where the talons hang, which is where the
figure is turned upright for the landing (see story_eagle.py).
"""
import math

from figures_more import _f, scaled_about

FLIGHT_FEET = (44, 70)
FLIGHT_PARTS = {
    'wingN':  ('path', None), 'wingNl': ('path', None),
    'wingF':  ('path', None), 'wingFl': ('path', None),
    'head':   ('rotate', (70, 46)),
    'tail':   ('rotate', (30, 50)),
    'fan':    ('scale', (30, 50)),
    'legs':   ('rotate', (45, 57)),
    'beak':   ('rotate', (85, 45)),
    'eye':    ('scale', (82, 41.5)),
    'preyhide': ('scale', (50, 66)),
}
FLIGHT_SHADOW = (1.5, 0.36)

SPAN = 76.0                    # one wing, shoulder to tip
SHOULDER = (60.0, 46.0)        # where the near wing joins the body, in the figure's picture
CAMERA = (0.95, 0.5)          # how up and how towards-us show on the picture: the board is seen from above
FINGERS = (                    # (how far out, how far behind the leading edge), tip then notch
    (1.000, 6), (0.972, 11), (0.952, 17), (0.926, 15), (0.903, 23), (0.874, 20),
    (0.852, 26), (0.822, 23), (0.792, 28), (0.758, 24),
)


def _lead(s):
    """The leading edge's way back from the shoulder: swept back, a little forward at the wrist."""
    return 6 - 0.34*s + 5.0*math.sin(math.pi*s/SPAN)


def _chord(s):
    """How far the trailing edge lies behind the leading one on the arm, scalloped at the secondaries."""
    f = min(1.0, s/(0.62*SPAN))
    return 34 - 11*f + 1.6*math.sin(s*0.9)


def _project(s, d, e_arm, e_hand, side, shoulder):
    """A point of the wing, s out along it and d behind its leading edge, as a point of the picture."""
    a = min(s, 0.5*SPAN)
    h = max(0.0, s - 0.5*SPAN)
    e1, e2 = math.radians(e_arm), math.radians(e_hand)
    up = a*math.sin(e1) + h*math.sin(e2)
    toward = side*(a*math.cos(e1) + h*math.cos(e2))
    return (shoulder[0] + _lead(s) - d, shoulder[1] - CAMERA[0]*up + CAMERA[1]*toward)


def wing_paths(e_arm, e_hand, near=True, spread=1.0):
    """The outline and the feather lines of one wing, as SVG path data. Angles
    in degrees above level; `spread` below 1 draws the wing drawn in (a stoop)."""
    side = 1 if near else -1
    shoulder = SHOULDER if near else (SHOULDER[0] - 3, SHOULDER[1] - 2)
    S = SPAN*spread
    def P(frac, d):
        return _project(frac*SPAN*spread, d*spread, e_arm, e_hand, side, shoulder)
    pts = [P(k/14, 0) for k in range(15)]                          # leading edge, root to tip
    pts += [P(frac, d) for frac, d in FINGERS]                     # the fingers, tip to wrist
    frac = 0.758
    while frac > 0.02:                                             # the trailing edge back to the body
        frac -= 0.08
        pts.append(P(max(frac, 0.0), _chord(max(frac, 0.0)*SPAN)))
    pts.append(P(0.0, _chord(0.0)))
    sil = 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
    lines = []
    for share in (0.28, 0.55, 0.8):                                # feather lines along the arm
        seg = [P(f/12*0.74 + 0.04, share*_chord((f/12*0.74 + 0.04)*SPAN)) for f in range(13)]
        lines.append('M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in seg))
    for frac, d in FINGERS[0::2]:                                  # one line along each finger
        a = P(frac - 0.08, max(2, d - 12))
        b = P(frac, d - 3)
        lines.append(f'M{a[0]:.1f} {a[1]:.1f} L{b[0]:.1f} {b[1]:.1f}')
    return sil, ' '.join(lines)


def _fish(cx, cy):
    return (f'<ellipse cx="{cx}" cy="{cy}" rx="11" ry="3.2" fill="{_f("fish")}"/>'
            f'<path d="M{cx - 9} {cy} L{cx - 17} {cy - 5} L{cx - 17} {cy + 5} Z" fill="{_f("fish")}"/>'
            f'<circle cx="{cx + 7}" cy="{cy - 0.6}" r="0.8" fill="#15171B"/>')


def flight_body(anim=None, shadow=False, pose=(10, 4), carrying=False):
    """`pose` (arm, hand) angles for a figure that stands still (no animation)."""
    anim = anim or {}
    def wing(name, near):
        sil, lines = wing_paths(pose[0], pose[1], near)
        shade = 'eagle-brown' if near else 'eagle-dark'
        return (f'<path d="{sil}" fill="{_f(shade)}" stroke="#000" stroke-opacity="0.3" stroke-width="0.5" stroke-linejoin="round">{anim.get(name, "")}</path>'
                f'<path d="{lines}" fill="none" stroke="#fff" stroke-opacity="0.17" stroke-width="0.7" stroke-linecap="round">{anim.get(name + "l", "")}</path>')
    o = [wing('wingF', False)]
    # tail: a white fan behind
    tail = ('<path d="M32 48.5 L2 40 L0 46 L-1 52 L2 58 L32 54.5 Z" fill="url(#fig-eagle-white)" stroke="#000" '
            'stroke-opacity="0.2" stroke-width="0.5" stroke-linejoin="round"/>'
            '<path d="M30 50 L3 44 M30 52 L2 52 M30 53.5 L3 57" stroke="#8A7F68" stroke-opacity="0.45" stroke-width="0.6" fill="none"/>')
    o.append('<g>' + anim.get('tail', '') + scaled_about(anim.get('fan', ''), FLIGHT_PARTS['fan'][1], tail) + '</g>')
    # body: a long egg, a paler belly
    o.append(f'<ellipse cx="52" cy="49" rx="27" ry="9.5" fill="{_f("eagle-brown")}"/>')
    o.append(f'<ellipse cx="53" cy="53" rx="22" ry="5" fill="{_f("eagle-gold")}" opacity="0.55"/>')
    # the fish, under the belly, held in the feet
    if anim.get('preyhide') or carrying:
        o.append(scaled_about(anim.get('preyhide', ''), FLIGHT_PARTS['preyhide'][1], _fish(50, 66)))
    # legs: thighs, yellow legs, talons; they hang at rest and the story tucks them back
    o.append('<g>' + anim.get('legs', '')
             + f'<ellipse cx="45" cy="57" rx="5.5" ry="4.5" fill="{_f("eagle-dark")}"/>'
             + '<path d="M45 59 L44 68" stroke="#EFC230" stroke-width="3.2" stroke-linecap="round" fill="none"/>'
             + '<path d="M38 70 L44 68 L50 71" stroke="#EFC230" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>'
             + '<path d="M37 71 L38.5 73 M49.5 72 L50.5 74" stroke="#2A2118" stroke-width="1.3" stroke-linecap="round"/></g>')
    # white cape over the shoulders, then the head thrust forward
    o.append(f'<ellipse cx="73" cy="47" rx="10.5" ry="8" fill="{_f("eagle-white")}"/>')
    o.append('<g>' + anim.get('head', ''))
    o.append(f'<circle cx="80" cy="43" r="7.4" fill="{_f("eagle-white")}"/>')
    o.append(f'<path d="M85.5 39.5 Q96 38.5 97 46 Q96 50 92.5 47.5 Q91.5 44 85.5 44.5 Z" fill="{_f("eagle-yellow")}"/>')
    o.append('<path d="M85.5 40 Q88 39.5 89 42.5 Q87.5 44.5 85.5 44.5 Z" fill="#F2A22A" opacity="0.85"/>')
    o.append(f'<g>{anim.get("beak", "")}<path d="M86 45.2 Q91.5 46 93.5 48.4 Q89 49 86 47.8 Z" fill="{_f("eagle-yellow")}"/></g>')
    o.append('<path d="M74.5 38.5 Q80.5 36.2 87 40.5" fill="none" stroke="#2A2118" stroke-opacity="0.75" stroke-width="2.3" stroke-linecap="round"/>')
    o.append(scaled_about(anim.get('eye', ''), FLIGHT_PARTS['eye'][1],
                          '<circle cx="82" cy="42" r="2.1" fill="#F4C21B"/><circle cx="82.4" cy="42" r="1.05" fill="#15171B"/>'
                          '<circle cx="82.8" cy="41.4" r="0.4" fill="#fff"/>'))
    o.append('</g>')
    o.append(wing('wingN', True))
    return ''.join(o)


def flight_still(anim=None, shadow=False): return flight_body(anim, pose=(14, 6))
