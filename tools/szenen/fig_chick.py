"""An eagle chick begging, seen from the front: a ball of white down, a
big head, a wide yellow-rimmed mouth. Drawn small; it sits in a nest and
shows only head and shoulders over the rim.

Parts: gape (the mouth, scaled in height: open begging, shut swallowing).
"""
from figures_more import _f, scaled_about

CHICK_FEET = (50, 92)
CHICK_PARTS = {
    'gape': ('scale', (50, 56)),
}


def chick_body(anim=None, shadow=False):
    anim = anim or {}
    o = []
    # body: a round ball of down, tufts at its top
    o.append(f'<circle cx="50" cy="72" r="24" fill="{_f("chick-down")}"/>')
    # head: bigger than it should be, tufted
    tufts = ''.join(f'<path d="M{x} {y} L{x + dx} {y - 9} L{x + 4} {y} Z" fill="{_f("chick-down")}"/>'
                    for x, y, dx in ((34, 34, -3), (42, 28, -1), (50, 26, 1), (58, 28, 2), (65, 34, 4)))
    o.append(tufts)
    o.append(f'<circle cx="50" cy="48" r="22" fill="{_f("chick-down")}"/>')
    # eyes: dark, small, wide apart
    o.append('<circle cx="39" cy="41" r="2.6" fill="#15171B"/><circle cx="61" cy="41" r="2.6" fill="#15171B"/>'
             '<circle cx="39.8" cy="40.2" r="0.8" fill="#fff"/><circle cx="61.8" cy="40.2" r="0.8" fill="#fff"/>')
    # the beak: upper bill above, lower below, the pink mouth between
    o.append(f'<path d="M41 49 Q50 36 59 49 Q50 53 41 49 Z" fill="{_f("chick-beak")}"/>')
    mouth = ('<ellipse cx="50" cy="57" rx="11" ry="8" fill="#D1505C"/>'
             '<ellipse cx="50" cy="60" rx="6.5" ry="4" fill="#8E2B38"/>')
    o.append(scaled_about(anim.get('gape', ''), CHICK_PARTS['gape'][1], mouth))
    o.append(f'<path d="M37 56 Q50 74 63 56 Q50 61 37 56 Z" fill="{_f("chick-beak")}"/>')
    return ''.join(o)
