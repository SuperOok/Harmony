"""Two big birds, an eagle and a raven, drawn from one build: a perched
body, a folded wing, and a spread wing pair that flaps. Facing right,
feet at BIRD_FEET."""
from figures_more import _f, scaled_about

BIRD_FEET = (46, 92)
BIRD_PARTS = {
    'spread': ('scale', (52, 47)),     # both wings out (scaled to nothing when perched)
    'wingN': ('rotate', (52, 47)),     # near wing, spread
    'wingF': ('rotate', (50, 45)),     # far wing
    'fold':  ('scale', (50, 50)),      # the folded wing; scaled to nothing when the wings are out
    'head':  ('rotate', (60, 42)),
    'tail':  ('rotate', (38, 74)),
    'legs':  ('scale', (46, 78)),      # tucked up in flight
    'beak':  ('rotate', (70, 29)),     # the lower bill drops open when it calls
    'eye':   ('scale', (66, 26)),
}
EAGLE_SHADOW = (1.1, 0.3)
RAVEN_SHADOW = (0.8, 0.22)

EAGLE = dict(body='eagle-brown', head='eagle-white', wing='eagle-brown', wingfar='eagle-brown', tail='eagle-white',
             bill='eagle-yellow', legs='#EFC230', iris='#F4C21B', hook=True, brow=True, size=1.0)
RAVEN = dict(body='raven', head='raven', wing='raven', wingfar='raven', tail='raven',
             bill='bug-black', legs='#15171B', iris='#E8E2D0', hook=False, brow=False, size=0.82)


def _wing(shade, tipcolour=None):
    """A spread wing pointing up from the shoulder at (52, 47): a straight
    leading edge, finger feathers at the tip, a scalloped trailing edge."""
    return (f'<path d="M54 47 Q60 20 66 -18 L60 -10 L61 -3 L53 1 L54 9 L46 13 L46 23 L39 27 L40 37 L34 41 L36 50 Z" '
            f'fill="{_f(shade)}" stroke="#000" stroke-opacity="0.25" stroke-width="0.5" stroke-linejoin="round"/>'
            '<path d="M56 40 Q57 18 63 -10 M50 40 Q51 20 56 0 M44 42 Q45 28 49 12" fill="none" stroke="#fff" stroke-opacity="0.18" stroke-width="0.7"/>')


def bird_body(p, anim=None, perched=False):
    """`perched` leaves the spread wings out, for a figure that stands still."""
    anim = anim or {}
    k = p['size']
    o = []
    # far wing behind everything, a little darker through the shade of the body
    far = '<g>' + anim.get('wingF', '') + f'<g transform="translate(-5 2)" opacity="0.85">{_wing(p["wingfar"])}</g></g>'
    if not perched:
        o.append(scaled_about(anim.get('spread', ''), BIRD_PARTS['spread'][1], far))
    # legs and talons
    o.append('<g>' + anim.get('legs', '') + (
        f'<path d="M42 78 L40 90 M52 78 L52 90" stroke="{p["legs"]}" stroke-width="4.2" stroke-linecap="round" fill="none"/>'
        f'<path d="M36 93 L40 90 L45 94 M48 94 L52 90 L57 93" stroke="{p["legs"]}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" fill="none"/>'
        '</g>'))
    # tail
    o.append(f'<g>{anim.get("tail", "")}<path d="M38 70 L26 99 L38 96 L44 100 L48 90 Z" fill="{_f(p["tail"])}" stroke="#000" stroke-opacity="0.2" stroke-width="0.5"/></g>')
    # body, leaning forward
    o.append(f'<ellipse cx="48" cy="57" rx="{17*k:.1f}" ry="{25*k:.1f}" fill="{_f(p["body"])}" transform="rotate(-12 48 60)"/>')
    # the folded wing laid along it
    fold = (f'<path d="M52 44 Q64 58 54 84 Q44 88 38 76 Q34 60 44 46 Z" fill="{_f(p["wing"])}" stroke="#000" stroke-opacity="0.25" stroke-width="0.5"/>'
            '<path d="M50 52 Q55 66 50 80 M44 54 Q46 66 44 76" fill="none" stroke="#fff" stroke-opacity="0.15" stroke-width="0.7"/>')
    o.append(scaled_about(anim.get('fold', ''), BIRD_PARTS['fold'][1], fold))
    # head
    o.append('<g>' + anim.get('head', '') + '<g transform="translate(-3 7)">')      # sits down on the shoulders: no neck
    o.append(f'<circle cx="64" cy="29" r="{11*k + 1:.1f}" fill="{_f(p["head"])}"/>')
    bill = (f'M70 24 Q85 22 86 36 Q84 41 80 36 Q77 32 70 34 Z' if p['hook']
            else 'M70 25 Q88 24 92 31 Q80 34 70 35 Z')
    o.append(f'<path d="{bill}" fill="{_f(p["bill"])}"/>')
    o.append(f'<g>{anim.get("beak", "")}<path d="{"M71 34 Q78 36 80 39 Q76 40 71 38 Z" if p["hook"] else "M71 34 Q82 35 88 33 Q80 39 71 38 Z"}" fill="{_f(p["bill"])}"/></g>')
    if p['brow']:
        o.append('<path d="M60 23 Q69 19 76 25" fill="none" stroke="#B5A98A" stroke-width="2.6" stroke-linecap="round"/>')
    o.append(scaled_about(anim.get('eye', ''), BIRD_PARTS['eye'][1],
                          f'<circle cx="68" cy="27.5" r="2.7" fill="{p["iris"]}"/><circle cx="68.4" cy="27.5" r="1.4" fill="#15171B"/>'
                          '<circle cx="68.9" cy="26.8" r="0.5" fill="#fff"/>'))
    o.append('</g></g>')
    # near wing last, over the body
    near = '<g>' + anim.get('wingN', '') + _wing(p['wing']) + '</g>'
    if not perched:
        o.append(scaled_about(anim.get('spread', ''), BIRD_PARTS['spread'][1], near))
    return ''.join(o)


def eagle_body(anim=None, shadow=False): return bird_body(EAGLE, anim)
def raven_body(anim=None, shadow=False): return bird_body(RAVEN, anim)


def eagle_still(anim=None, shadow=False): return bird_body(EAGLE, anim, perched=True)
def raven_still(anim=None, shadow=False): return bird_body(RAVEN, anim, perched=True)
