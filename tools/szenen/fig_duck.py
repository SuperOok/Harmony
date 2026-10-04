"""A mallard pair, drawn from paths rather than ovals: a boat-shaped body
with a raised stern, a neck that stands up from the breast, a flat bill.
One build draws drake and hen, swimming and flying; the parts `swim` and
`fly` are scaled to nothing when the other pose is on. Facing right, the
water line at y = 70 (DUCK_FEET)."""
from figures_more import _f, scaled_about

DUCK_FEET = (50, 70)                 # on the water line
DUCK_PARTS = {
    'tip':   ('rotate', (46, 66)),   # tips forward to dabble, tail in the air
    'head':  ('rotate', (74, 56)),   # looks about
    'tail':  ('rotate', (24, 52)),   # wags
    'eye':   ('scale', (78, 25)),
    'swim':  ('scale', (50, 70)),    # the swimming pose (1), or gone (0)
    'fly':   ('scale', (50, 60)),    # the flying pose
    'wingN': ('scale', (58, 54)),    # near wing, flattened by turning it edge-on
    'wingF': ('scale', (58, 54)),    # far wing
    'fhead': ('rotate', (68, 54)),
}

DRAKE = dict(body='duck-grey', back='duck-back', head='duck-green', neck='duck-green', bill='duck-bill',
             breast='duck-breast', wing='duck-wing', rump='duck-black', collar=True, spots=False)
HEN = dict(body='hen-body', back='hen-wing', head='hen-head', neck='hen-head', bill='hen-bill',
           breast='hen-body', wing='hen-wing', rump='hen-wing', collar=False, spots=True)

_SPOTS = [(34, 55, 2.2), (40, 52, 1.8), (46, 56, 2.4), (52, 53, 1.9), (58, 56, 2.2), (63, 52, 1.7),
          (30, 60, 1.8), (38, 62, 2.2), (45, 64, 1.8), (53, 62, 2.3), (60, 63, 1.9), (67, 61, 2.0),
          (72, 64, 1.7), (28, 52, 1.5), (49, 50, 1.4), (70, 56, 1.6), (35, 66, 1.4), (57, 67, 1.5)]

_HULL = ('M10 46 C 17 52, 23 61, 33 67 C 45 73, 69 74, 79 68 C 88 62, 89 54, 83 50 '
         'C 77 47, 67 49, 56 49 C 44 49, 28 50, 10 46 Z')
_FHULL = 'M20 58 C 30 51, 52 49, 66 52 C 74 54, 77 59, 73 63 C 64 69, 40 68, 24 63 Z'


def _spots(clip_id, hull):
    dots = ''.join(f'<ellipse cx="{x}" cy="{y}" rx="{r*1.25}" ry="{r*0.85}" fill="#4A3720" fill-opacity="0.5"/>'
                   for x, y, r in _SPOTS)
    return f'<clipPath id="{clip_id}"><path d="{hull}"/></clipPath><g clip-path="url(#{clip_id})">{dots}</g>'


def _swim(p, anim):
    o = []
    # tail: the drake's black curl; the hen's is a plain upturned point
    if p['collar']:
        curl, fill = 'M27 50 Q16 49 9 38 Q10 44 14 47 Q9 45 6 41 Q8 50 20 55 Z', _f('duck-black')
    else:
        curl, fill = 'M27 50 Q17 49 9 41 Q16 54 28 56 Z', _f('hen-wing')
    o.append(f'<g>{anim.get("tail", "")}<path d="{curl}" fill="{fill}" stroke="#0B0E13" stroke-opacity="0.35" stroke-width="0.5"/></g>')
    o.append(f'<path d="{_HULL}" fill="{_f(p["body"])}"/>')
    # the darker back, the black rear end
    o.append(f'<path d="M12 46 C 28 50, 44 49, 56 49 C 66 49, 74 48, 80 50 C 70 53, 52 54, 36 53 C 26 53, 17 51, 12 46 Z" fill="{_f(p["back"])}"/>')
    o.append(f'<path d="M10 46 C 17 52, 23 61, 33 67 L 36 60 C 28 56, 20 52, 10 46 Z" fill="{_f(p["rump"])}"/>')
    if p['spots']:
        o.append(_spots('hen-hull', _HULL))
    # the folded wing, pointed at the back, with the blue patch edged in white
    o.append(f'<path d="M62 52 C 52 49, 36 51, 24 56 C 36 63, 52 64, 62 60 C 67 58, 67 54, 62 52 Z" fill="{_f(p["wing"])}" stroke="#000" stroke-opacity="0.18" stroke-width="0.5"/>')
    o.append(f'<path d="M40 59 C 46 58, 52 58, 57 59.5 C 52 62, 46 62, 40 59 Z" fill="{_f("duck-blue")}"/>')
    o.append('<path d="M40 57.5 C 46 56.5, 52 56.5, 57 58" fill="none" stroke="#fff" stroke-opacity="0.8" stroke-width="0.8"/>')
    o.append('<path d="M33 58 Q42 61.5 54 62.5 M30 56.5 Q40 59.5 50 60.5" fill="none" stroke="#fff" stroke-opacity="0.16" stroke-width="0.6"/>')
    # head and neck turn together about the base of the neck
    o.append('<g>' + anim.get('head', ''))
    o.append(f'<path d="M64 62 C 66 52, 68 42, 70 34 L 80 33.5 C 80 42, 82 50, 88 59 Z" fill="{_f(p["neck"])}"/>')
    if p['collar']:
        o.append(f'<path d="M66.2 50.5 C 72 53, 78 53, 82 50 L 84.4 53.6 C 78 57.4, 72 57.4, 65.4 54 Z" fill="{_f("eagle-white")}"/>')
    o.append(f'<path d="M63 66 C 62 60, 69 57, 76 57 C 87 57, 91 63, 85 68 C 81 72, 68 72, 63 66 Z" fill="{_f(p["breast"])}"/>')
    if p['spots']:
        o.append('<g fill="#4A3720" fill-opacity="0.45"><ellipse cx="70" cy="62" rx="2.2" ry="1.4"/><ellipse cx="77" cy="64" rx="2.4" ry="1.5"/>'
                 '<ellipse cx="82" cy="61" rx="1.8" ry="1.2"/><ellipse cx="73" cy="68" rx="2" ry="1.3"/><ellipse cx="68" cy="45" rx="1.6" ry="1"/>'
                 '<ellipse cx="73" cy="48" rx="1.8" ry="1.1"/><ellipse cx="79" cy="46" rx="1.5" ry="1"/></g>')
    # the head: a rounded crown running down into the flat bill
    o.append(f'<path d="M64 29 C 64 19, 72 17, 79 19 C 84 21, 86 24, 87 27 L 86 33 C 80 37, 70 37, 66 34 Z" fill="{_f(p["head"])}"/>')
    o.append(f'<path d="M85 22.5 C 91 22.5, 98 26, 101 30 C 101 33.5, 96 35, 90 35 C 87 35, 84 33.5, 83 31 Z" fill="{_f(p["bill"])}"/>')
    o.append('<path d="M84 31 C 90 32.5, 95 32.5, 100 31" fill="none" stroke="#8A6A10" stroke-opacity="0.55" stroke-width="0.6"/>')
    o.append('<path d="M97.5 28 C 100 29, 101.5 30, 101 31.5 C 99.5 31.8, 98 30.5, 97.5 28 Z" fill="#8A6A10" fill-opacity="0.45"/>')
    o.append('<circle cx="92.5" cy="26.4" r="0.6" fill="#8A6A10" opacity="0.7"/>')
    if not p['collar']:
        o.append('<path d="M70 25 C 75 24, 80 25, 85 27" fill="none" stroke="#3A2812" stroke-opacity="0.55" stroke-width="1.4" stroke-linecap="round"/>')
    o.append(scaled_about(anim.get('eye', ''), DUCK_PARTS['eye'][1],
                          '<circle cx="78" cy="25.5" r="2" fill="#151B24"/><circle cx="78.7" cy="24.8" r="0.65" fill="#F2EDDB"/>'))
    o.append('</g>')
    return ''.join(o)


def _wing(shade):
    """One wing out, pointing up from the shoulder at (58, 54), swept back."""
    return (f'<path d="M63 54 C 62 40, 57 26, 46 8 C 41 18, 36 28, 33 38 L 36 40 L 35 46 L 39 48 L 40 54 Z" '
            f'fill="{_f(shade)}" stroke="#000" stroke-opacity="0.22" stroke-width="0.5" stroke-linejoin="round"/>'
            f'<path d="M44 44 C 46 38, 49 34, 53 31 L 55 36 C 51 38, 48 42, 46 46 Z" fill="{_f("duck-blue")}"/>'
            '<path d="M44 44 C 46 38, 49 34, 53 31" fill="none" stroke="#fff" stroke-opacity="0.75" stroke-width="0.7"/>'
            '<path d="M58 50 Q57 32 47 14 M52 50 Q50 36 42 24" fill="none" stroke="#fff" stroke-opacity="0.15" stroke-width="0.6"/>')


def _fly(p, anim):
    o = []
    far = f'<g transform="translate(-4 -1)" opacity="0.9">{_wing(p["back"])}</g>'
    o.append(scaled_about(anim.get('wingF', ''), DUCK_PARTS['wingF'][1], far))
    # tail, body, the neck stretched out forward, head and bill
    o.append(f'<path d="M8 59 L 24 54 L 24 63 Z" fill="{_f(p["rump"])}"/>')
    o.append(f'<path d="{_FHULL}" fill="{_f(p["body"])}"/>')
    o.append(f'<path d="M24 58 C 36 54, 52 53, 66 55 C 52 57, 38 60, 24 62 Z" fill="{_f(p["back"])}"/>')
    if p['spots']:
        o.append(_spots('hen-fly', _FHULL))
    o.append(f'<path d="M64 60 C 70 62, 76 62, 78 58 C 76 54, 70 54, 66 54 Z" fill="{_f(p["breast"])}"/>')
    o.append('<g>' + anim.get('fhead', ''))
    o.append(f'<path d="M66 52 C 76 47, 84 46.5, 90 48 L 90 56 C 82 57, 74 60, 68 62 Z" fill="{_f(p["neck"])}"/>')
    if p['collar']:
        o.append(f'<path d="M71 49.5 L 74 49 L 75 59.5 L 72 60.5 Z" fill="{_f("eagle-white")}"/>')
    o.append(f'<ellipse cx="91" cy="52" rx="6.6" ry="5.6" fill="{_f(p["head"])}"/>')
    o.append(f'<path d="M95 49 C 100 49, 106 52, 107.5 54 C 106 56.5, 100 57, 95 56 Z" fill="{_f(p["bill"])}"/>')
    o.append('<circle cx="93" cy="50.8" r="1.5" fill="#151B24"/><circle cx="93.5" cy="50.3" r="0.5" fill="#F2EDDB"/>')
    o.append('</g>')
    o.append(scaled_about(anim.get('wingN', ''), DUCK_PARTS['wingN'][1], _wing(p['wing'])))
    return ''.join(o)


def _pair_body(p):
    def body(anim=None, shadow=False):
        """Facing right. Below the water line (y = 70) the swimming pose is
        cut off, a few wavelets in front; the flying pose is not."""
        anim = anim or {}
        o = ['<defs><clipPath id="duck-water"><rect x="-300" y="-300" width="700" height="370"/></clipPath></defs>']
        swim = ('<g clip-path="url(#duck-water)"><g>' + anim.get('tip', '') + _swim(p, anim) + '</g></g>'
                '<path d="M12 70.4 Q 22 68.6 32 70.6 T 52 70.6 T 72 70.4 T 90 70" fill="none" stroke="#DFF1FF" stroke-opacity="0.45" stroke-width="0.8" stroke-linecap="round"/>'
                '<path d="M20 72.4 Q 30 71 40 72.6 T 60 72.6 T 78 72.2" fill="none" stroke="#2A64A0" stroke-opacity="0.22" stroke-width="1.1" stroke-linecap="round"/>')
        o.append(scaled_about(anim['swim'], DUCK_PARTS['swim'][1], swim) if 'swim' in anim else swim)
        if 'fly' in anim:
            o.append(scaled_about(anim['fly'], DUCK_PARTS['fly'][1], _fly(p, anim)))
        return ''.join(o)
    return body


duck_body = _pair_body(DRAKE)
hen_body = _pair_body(HEN)
