"""The ladybird: seen from behind and above, head up."""
from figures_more import _f, scaled_about

BUG_FEET = (50, 62)                  # under the middle of the body
BUG_PARTS = {
    'elytraL': ('rotate', (43, 36)),
    'elytraR': ('rotate', (57, 36)),
    'wings':   ('scale', (50, 58)),
    'antL':    ('rotate', (46, 21)),
    'antR':    ('rotate', (54, 21)),
    'legsA':   ('rotate', (50, 58)),
    'legsB':   ('rotate', (50, 58)),
}
BUG_SHADOW = (0.7, 0.28)


def _leg(x0, y0, x1, y1):
    return f'<path d="M{x0} {y0} L{x1} {y1}" stroke="#15171B" stroke-width="2.4" stroke-linecap="round" fill="none"/>'


def _half(side):
    """One of the two wing cases: half of the dome, three spots."""
    clip = f'bug-half-{side}'
    x = 0 if side == 'L' else 50
    spots = {'L': [(37, 55, 4.6), (33, 72, 4.2), (43, 66, 3.2)],
             'R': [(63, 55, 4.6), (67, 72, 4.2), (57, 66, 3.2)]}[side]
    s = [f'<defs><clipPath id="{clip}"><rect x="{x}" y="0" width="50" height="100"/></clipPath></defs>',
         f'<g clip-path="url(#{clip})"><ellipse cx="50" cy="60" rx="25" ry="28" fill="{_f("bug-red")}"/>']
    s += [f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{_f("bug-black")}"/>' for cx, cy, r in spots]
    s.append('</g>')
    return ''.join(s)


def bug_body(anim=None, shadow=False):
    """Round red wing cases that open like doors, wings beneath, six legs
    walking in two alternating groups, two feelers."""
    anim = anim or {}
    o = []
    o.append('<g>' + anim.get('legsA', '') + _leg(28, 44, 14, 38) + _leg(72, 60, 87, 62) + _leg(29, 76, 17, 86) + '</g>')
    o.append('<g>' + anim.get('legsB', '') + _leg(72, 44, 86, 38) + _leg(28, 60, 13, 62) + _leg(71, 76, 83, 86) + '</g>')
    # wings under the cases: pale, veined, unfolding sideways
    wing = (f'<ellipse cx="50" cy="60" rx="46" ry="15" fill="{_f("bug-wing")}" fill-opacity="0.85"/>'
            '<path d="M8 60 Q50 54 92 60 M16 56 Q50 50 84 56 M16 64 Q50 66 84 64" stroke="#8A8368" stroke-width="0.6" fill="none" opacity="0.6"/>')
    o.append(scaled_about(anim.get('wings', ''), BUG_PARTS['wings'][1], wing))
    o.append(f'<g>{anim.get("antL", "")}<path d="M46 21 Q40 10 33 6" stroke="#15171B" stroke-width="1.6" stroke-linecap="round" fill="none"/>'
             '<circle cx="33" cy="6" r="1.7" fill="#15171B"/></g>')
    o.append(f'<g>{anim.get("antR", "")}<path d="M54 21 Q60 10 67 6" stroke="#15171B" stroke-width="1.6" stroke-linecap="round" fill="none"/>'
             '<circle cx="67" cy="6" r="1.7" fill="#15171B"/></g>')
    o.append(f'<ellipse cx="50" cy="27" rx="13" ry="10" fill="{_f("bug-black")}"/>')
    o.append('<ellipse cx="42.5" cy="25" rx="3.6" ry="4.6" fill="#F4F0E0" transform="rotate(-12 42.5 25)"/>'
             '<ellipse cx="57.5" cy="25" rx="3.6" ry="4.6" fill="#F4F0E0" transform="rotate(12 57.5 25)"/>')
    # the pronotum: black with two pale corners
    o.append(f'<ellipse cx="50" cy="38" rx="17" ry="9" fill="{_f("bug-black")}"/>')
    o.append('<ellipse cx="37" cy="36" rx="4" ry="5" fill="#F4F0E0" transform="rotate(-25 37 36)"/>'
             '<ellipse cx="63" cy="36" rx="4" ry="5" fill="#F4F0E0" transform="rotate(25 63 36)"/>')
    o.append('<g>' + anim.get('elytraL', '') + _half('L') + '</g>')
    o.append('<g>' + anim.get('elytraR', '') + _half('R') + '</g>')
    o.append('<path d="M50 34 L50 88" stroke="#15171B" stroke-width="1.1" opacity="0.9"/>')
    return ''.join(o)
