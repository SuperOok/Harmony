"""The raven in flight: the eagle's flight build (fig_eagle_flight, wings
turned in space and flattened per frame) in black, smaller across the
wings, narrower, with the thick straight bill, a wedge of a tail and thin
black legs. Parts as there, minus the fish.

Facing right. FLIGHT_FEET is where the feet hang.
"""
from figures_more import _f, scaled_about
from fig_eagle_flight import wing_paths as _wing_paths

RAVEN_FEET = (44, 70)
RAVEN_PARTS = {
    'wingN':  ('path', None), 'wingNl': ('path', None),
    'wingF':  ('path', None), 'wingFl': ('path', None),
    'head':   ('rotate', (70, 46)),
    'tail':   ('rotate', (30, 50)),
    'fan':    ('scale', (30, 50)),
    'legs':   ('rotate', (45, 57)),
    'beak':   ('rotate', (84, 45)),
    'eye':    ('scale', (81, 42)),
}
RAVEN_SPAN, RAVEN_CHORD = 62.0, 0.72


def raven_wing_paths(e_arm, e_hand, near=True, spread=1.0):
    return _wing_paths(e_arm, e_hand, near, spread, span=RAVEN_SPAN, chord=RAVEN_CHORD)


def raven_flight_body(anim=None, shadow=False, pose=(10, 4)):
    """`pose` (arm, hand) angles for a figure that stands still (no animation)."""
    anim = anim or {}
    def wing(name, near):
        sil, lines = raven_wing_paths(pose[0], pose[1], near)
        shade = 'raven' if near else 'bug-black'
        return (f'<path d="{sil}" fill="{_f(shade)}" stroke="#000" stroke-opacity="0.35" stroke-width="0.5" stroke-linejoin="round">{anim.get(name, "")}</path>'
                f'<path d="{lines}" fill="none" stroke="#9FB0D0" stroke-opacity="0.22" stroke-width="0.7" stroke-linecap="round">{anim.get(name + "l", "")}</path>')
    o = [wing('wingF', False)]
    tail = ('<path d="M31 49 L3 45 L-2 50 L3 55 L31 54 Z" fill="url(#fig-raven)" stroke="#000" stroke-opacity="0.3" '
            'stroke-width="0.5" stroke-linejoin="round"/>'
            '<path d="M29 50 L4 47 M29 52 L2 50 M29 53.5 L4 53" stroke="#9FB0D0" stroke-opacity="0.25" stroke-width="0.6" fill="none"/>')
    o.append('<g>' + anim.get('tail', '') + scaled_about(anim.get('fan', ''), RAVEN_PARTS['fan'][1], tail) + '</g>')
    o.append(f'<ellipse cx="52" cy="49" rx="25" ry="8.5" fill="{_f("raven")}"/>')
    o.append(f'<ellipse cx="55" cy="46" rx="18" ry="3.5" fill="{_f("raven-sheen")}" opacity="0.45"/>')
    # thin black legs, hanging at rest; the story tucks them back
    o.append('<g>' + anim.get('legs', '')
             + f'<ellipse cx="45" cy="57" rx="4.6" ry="3.8" fill="{_f("bug-black")}"/>'
             + '<path d="M45 59 L44 68" stroke="#15171B" stroke-width="2" stroke-linecap="round" fill="none"/>'
             + '<path d="M38 70 L44 68 L50 71" stroke="#15171B" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" fill="none"/></g>')
    # the head thrust forward, a heavy bill
    o.append('<g>' + anim.get('head', ''))
    o.append(f'<ellipse cx="72" cy="46" rx="9" ry="7" fill="{_f("raven")}"/>')
    o.append(f'<circle cx="79" cy="43.5" r="7" fill="{_f("raven")}"/>')
    o.append(f'<path d="M83.5 39.5 Q96 38.5 101.5 46 Q93 48 84 47 Z" fill="{_f("bug-black")}"/>')
    o.append('<path d="M85 41 Q93 40.5 98 44" fill="none" stroke="#9FB0D0" stroke-opacity="0.35" stroke-width="0.8" stroke-linecap="round"/>')
    o.append(f'<g>{anim.get("beak", "")}<path d="M85 47 Q93 48 97 47 Q92 51 85 49.5 Z" fill="{_f("bug-black")}"/></g>')
    o.append(scaled_about(anim.get('eye', ''), RAVEN_PARTS['eye'][1],
                          '<circle cx="81" cy="42" r="2.1" fill="#E8E2D0"/><circle cx="81.4" cy="42" r="1.05" fill="#15171B"/>'
                          '<circle cx="81.8" cy="41.4" r="0.4" fill="#fff"/>'))
    o.append('</g>')
    o.append(wing('wingN', True))
    return ''.join(o)
