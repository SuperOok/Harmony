"""The eagle, a white-headed sea eagle: sleeker than fig_bird's first try,
which read as a vulture (big bare head on a neck, drooping bill). Here the
head is small and feathered, the neck short, the brow heavy, the bill
short and hooked, the thighs shaggy, the folded wings long and pointed.

Facing right, feet at EAGLE_FEET. Parts as in fig_bird (spread, wingN,
wingF, fold, head, tail, legs, beak, eye) and two more for what it carries
and feeds: prey (moves) and preyhide (shrinks away as it is eaten).
"""
from figures_more import _f, scaled_about

EAGLE_FEET = (46, 92)
EAGLE_PARTS = {
    'spread':   ('scale', (52, 45)),
    'wingN':    ('rotate', (52, 45)),
    'wingF':    ('rotate', (50, 43)),
    'fold':     ('scale', (48, 48)),
    'head':     ('rotate', (54, 36)),
    'tail':     ('rotate', (40, 74)),
    'legs':     ('scale', (46, 78)),
    'beak':     ('rotate', (65, 28.5)),
    'eye':      ('scale', (61, 23.5)),
    'prey':     ('translate', None),
    'preyhide': ('scale', (46, 96)),
}
EAGLE_SHADOW = (1.4, 0.36)


def _wing(shade, edge):
    """A spread wing pointing up from the shoulder at (52, 45): a broad
    arm, five finger feathers at the tip, a scalloped trailing edge."""
    return (f'<path d="M55 45 C62 30 68 8 73 -26 L66 -15 L68 -12 L59 -3 L61 1 L52 8 L53 13 L45 18 L45 24 '
            f'L37 28 L37 35 L30 40 L33 48 Z" fill="{_f(shade)}" stroke="#000" stroke-opacity="0.3" stroke-width="0.5" stroke-linejoin="round"/>'
            f'<path d="M58 44 C63 28 68 6 73 -26 L66 -15 L66 -8 Q62 20 58 44 Z" fill="{_f(edge)}" opacity="0.8"/>'
            '<path d="M55 38 Q56 14 64 -8 M48 40 Q49 22 55 4 M41 42 Q42 28 47 14 M35 44 Q36 34 40 24" '
            'fill="none" stroke="#fff" stroke-opacity="0.16" stroke-width="0.7"/>')


def _fish():
    return (f'<ellipse cx="46" cy="100" rx="10" ry="3.2" fill="{_f("fish")}" transform="rotate(-8 46 100)"/>'
            f'<path d="M36 99 L28 94 L29 103 Z" fill="{_f("fish")}"/>'
            '<circle cx="53" cy="99" r="0.8" fill="#15171B"/>')


def eagle_figure(anim=None, perched=False, brood=False):
    """`perched` leaves the spread wings out, for a figure that stands
    still. `brood` hides its feet too: it sits down in a nest."""
    anim = anim or {}
    o = []
    if not perched:
        far = '<g>' + anim.get('wingF', '') + f'<g transform="translate(-5 2)" opacity="0.85">{_wing("eagle-dark", "eagle-dark")}</g></g>'
        o.append(scaled_about(anim.get('spread', ''), EAGLE_PARTS['spread'][1], far))
    # shaggy thighs, yellow legs and talons
    if not brood:
        o.append('<g>' + anim.get('legs', '')
                 + f'<ellipse cx="42" cy="79" rx="6" ry="9" fill="{_f("eagle-dark")}"/><ellipse cx="53" cy="80" rx="5.5" ry="8" fill="{_f("eagle-dark")}"/>'
                 + '<path d="M42 86 L41 92 M53 86 L53 92" stroke="#EFC230" stroke-width="3.6" stroke-linecap="round" fill="none"/>'
                 + '<path d="M36 94 L41 92 L45 95.5 M48 95.5 L53 92 L58 94.5" stroke="#EFC230" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" fill="none"/>'
                 + '<path d="M35 95 L36.5 97 M45.5 96.5 L45 98.5 M57.5 95.5 L59 97.5" stroke="#2A2118" stroke-width="1.4" stroke-linecap="round"/></g>')
    # tail: white fan
    tail_turn = ' transform="rotate(84 40 74)"' if brood else ''     # a brooding bird's tail lies back along the nest
    o.append(f'<g{tail_turn}><g>{anim.get("tail", "")}<path d="M42 70 L30 99 L37 96 L40 100 L45 96 L49 100 L52 84 Z" fill="{_f("eagle-white")}" '
             'stroke="#000" stroke-opacity="0.2" stroke-width="0.5" stroke-linejoin="round"/>'
             '<path d="M40 76 L37 96 M45 78 L45 95" stroke="#8A7F68" stroke-opacity="0.45" stroke-width="0.6" fill="none"/></g></g>')
    # body: upright egg, leaning a little forward, a golden mantle on it
    o.append(f'<ellipse cx="47" cy="57" rx="14.5" ry="26" fill="{_f("eagle-brown")}" transform="rotate(-9 47 57)"/>')
    o.append(f'<path d="M40 36 Q47 30 55 36 Q58 48 55 56 Q48 52 41 56 Q38 46 40 36 Z" fill="{_f("eagle-gold")}" opacity="0.8"/>')
    # folded wing: long, pointed, its tips crossing over the tail
    fold = (f'<path d="M51 36 Q62 52 55 78 L47 96 L43 80 Q37 58 44 38 Z" fill="{_f("eagle-brown")}" stroke="#000" stroke-opacity="0.28" stroke-width="0.5" stroke-linejoin="round"/>'
            f'<path d="M52 40 Q60 54 55 76 L47 96 L50 70 Q52 54 52 40 Z" fill="{_f("eagle-dark")}" opacity="0.7"/>'
            '<path d="M48 48 Q51 66 47 86 M44 52 Q46 66 44 80" fill="none" stroke="#fff" stroke-opacity="0.16" stroke-width="0.7"/>')
    o.append(scaled_about(anim.get('fold', ''), EAGLE_PARTS['fold'][1], fold))
    # head: small, round, feathered white, a short neck of white feathers merging into the mantle
    o.append('<g>' + anim.get('head', ''))
    o.append(f'<path d="M43 36 Q48 27 58 29 Q63 36 58 45 Q50 42 44 46 Q40 41 43 36 Z" fill="{_f("eagle-white")}"/>')
    o.append(f'<circle cx="57" cy="25" r="8.6" fill="{_f("eagle-white")}"/>')
    # a flat, heavy brow and a strong hooked bill; the cere at its root
    o.append(f'<path d="M62.5 21 Q72.5 20 74.5 28.5 Q73.8 32.5 70.8 30 Q69.5 27.5 63 27.5 Z" fill="{_f("eagle-yellow")}"/>')
    o.append('<path d="M62.5 21.5 Q65 21 66.5 24.5 Q64.5 26.5 62.5 26.5 Z" fill="#F2A22A" opacity="0.85"/>')
    o.append(f'<g>{anim.get("beak", "")}<path d="M63.5 28 Q69 28.5 71.5 31.2 Q67 32 63.5 30.6 Z" fill="{_f("eagle-yellow")}"/></g>')
    o.append('<path d="M52.5 19.5 Q59 17 66 22.5" fill="none" stroke="#2A2118" stroke-opacity="0.75" stroke-width="2.4" stroke-linecap="round"/>')
    o.append(scaled_about(anim.get('eye', ''), EAGLE_PARTS['eye'][1],
                          '<circle cx="61" cy="23.5" r="2.3" fill="#F4C21B"/><circle cx="61.4" cy="23.5" r="1.15" fill="#15171B"/>'
                          '<circle cx="61.9" cy="22.9" r="0.45" fill="#fff"/>'))
    o.append('</g>')
    # what it carries in its feet (a fish), which can be lifted to the bill
    prey = '<g>' + anim.get('prey', '') + scaled_about(anim.get('preyhide', ''), EAGLE_PARTS['preyhide'][1], _fish()) + '</g>'
    if anim.get('prey') and not brood:
        o.append(prey)
    if not perched:
        near = '<g>' + anim.get('wingN', '') + _wing('eagle-brown', 'eagle-dark') + '</g>'
        o.append(scaled_about(anim.get('spread', ''), EAGLE_PARTS['spread'][1], near))
    return ''.join(o)


def eagle_body(anim=None, shadow=False): return eagle_figure(anim)
def eagle_still(anim=None, shadow=False): return eagle_figure(anim, perched=True)
def eagle_brooding(anim=None, shadow=False): return eagle_figure(anim, perched=True, brood=True)
