"""The ladybird: seen from behind and above, head up, an oval rather than a
ball (the first try was nearly round).

The wings are folded away under the wing cases until the cases open: the
`wings` part is scaled to nothing, so nothing shows beyond the dome.
"""
from figures_more import _f, scaled_about

BUG_FEET = (50, 62)                  # under the middle of the body
BUG_PARTS = {
    'elytraL': ('rotate', (45, 37)),
    'elytraR': ('rotate', (55, 37)),
    'wings':   ('scale', (50, 58)),
    'antL':    ('rotate', (46, 19)),
    'antR':    ('rotate', (54, 19)),
    'legsA':   ('rotate', (50, 58)),
    'legsB':   ('rotate', (50, 58)),
}
BUG_SHADOW = (0.95, 0.4)
CLOSED = (0.04, 1.0)                 # the `wings` value while they are folded away

RX, RY = 21, 30                      # the dome: oval, taller than wide


def _leg(x0, y0, x1, y1):
    return f'<path d="M{x0} {y0} L{x1} {y1}" stroke="#15171B" stroke-width="2.4" stroke-linecap="round" fill="none"/>'


def _half(side):
    """One of the two wing cases: half of the dome, three spots."""
    clip = f'bug-half-{side}'
    x = 0 if side == 'L' else 50
    spots = {'L': [(40, 52, 3.9), (37, 70, 3.6), (44, 63, 2.8)],
             'R': [(60, 52, 3.9), (63, 70, 3.6), (56, 63, 2.8)]}[side]
    s = [f'<defs><clipPath id="{clip}"><rect x="{x}" y="0" width="50" height="100"/></clipPath></defs>',
         f'<g clip-path="url(#{clip})"><ellipse cx="50" cy="60" rx="{RX}" ry="{RY}" fill="{_f("bug-red")}"/>']
    s += [f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{_f("bug-black")}"/>' for cx, cy, r in spots]
    s.append('</g>')
    return ''.join(s)


def bug_body(anim=None, shadow=False):
    """An oval red dome of two wing cases that open like doors, wings
    beneath, six legs walking in two alternating groups, two feelers."""
    anim = anim or {}
    o = []
    o.append('<g>' + anim.get('legsA', '') + _leg(31, 44, 18, 38) + _leg(69, 60, 83, 62) + _leg(32, 77, 21, 86) + '</g>')
    o.append('<g>' + anim.get('legsB', '') + _leg(69, 44, 82, 38) + _leg(31, 60, 17, 62) + _leg(68, 77, 79, 86) + '</g>')
    # wings under the cases: pale, veined, unfolding sideways
    wing = (f'<ellipse cx="50" cy="60" rx="46" ry="15" fill="{_f("bug-wing")}" fill-opacity="0.85"/>'
            '<path d="M8 60 Q50 54 92 60 M16 56 Q50 50 84 56 M16 64 Q50 66 84 64" stroke="#8A8368" stroke-width="0.6" fill="none" opacity="0.6"/>')
    o.append(scaled_about(anim.get('wings', ''), BUG_PARTS['wings'][1], wing))
    o.append(f'<g>{anim.get("antL", "")}<path d="M46 19 Q40 9 33 5" stroke="#15171B" stroke-width="1.6" stroke-linecap="round" fill="none"/>'
             '<circle cx="33" cy="5" r="1.7" fill="#15171B"/></g>')
    o.append(f'<g>{anim.get("antR", "")}<path d="M54 19 Q60 9 67 5" stroke="#15171B" stroke-width="1.6" stroke-linecap="round" fill="none"/>'
             '<circle cx="67" cy="5" r="1.7" fill="#15171B"/></g>')
    o.append(f'<ellipse cx="50" cy="26" rx="11.5" ry="9" fill="{_f("bug-black")}"/>')
    o.append('<ellipse cx="43.5" cy="24" rx="3.2" ry="4.2" fill="#F4F0E0" transform="rotate(-12 43.5 24)"/>'
             '<ellipse cx="56.5" cy="24" rx="3.2" ry="4.2" fill="#F4F0E0" transform="rotate(12 56.5 24)"/>')
    # the pronotum: black with two pale corners
    o.append(f'<ellipse cx="50" cy="37" rx="15" ry="8.5" fill="{_f("bug-black")}"/>')
    o.append('<ellipse cx="39" cy="35" rx="3.6" ry="4.6" fill="#F4F0E0" transform="rotate(-25 39 35)"/>'
             '<ellipse cx="61" cy="35" rx="3.6" ry="4.6" fill="#F4F0E0" transform="rotate(25 61 35)"/>')
    o.append('<g>' + anim.get('elytraL', '') + _half('L') + '</g>')
    o.append('<g>' + anim.get('elytraR', '') + _half('R') + '</g>')
    o.append('<path d="M50 38 L50 90" stroke="#15171B" stroke-width="1.1" opacity="0.9"/>')
    return ''.join(o)
