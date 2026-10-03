"""More animals, drawn like the squirrel: every part a round body, lit from
the upper left, darker towards its lower right edge.

Each `*_body(anim, shadow=False)` draws in its own 100 x 100 design space,
feet at the point given with it, and puts `anim[name]` (SMIL from anim.py)
into the parts that move. `PARTS` says what each part is, for anim.write().
"""
import math

# (light, base, dark), used as gradients `fig-<name>` (figures.figure_defs)
SHADES_MORE = {
    # duck
    'duck-grey':   ('#D6D2C6', '#A9A496', '#6F6B5E'),
    'duck-green':  ('#4BAF7C', '#2A7F58', '#175238'),
    'duck-breast': ('#B8683F', '#8B4B2E', '#5A2F1C'),
    'duck-wing':   ('#A89880', '#7E705A', '#53483A'),
    'duck-bill':   ('#F8D866', '#E8B923', '#B5870F'),
    'duck-dark':   ('#4A5766', '#2C3744', '#151B24'),
    'duck-blue':   ('#6FA8E8', '#3E78C4', '#25508F'),
    # ladybird
    'bug-red':     ('#F26A55', '#D63A2B', '#8F1F16'),
    'bug-black':   ('#4A4F57', '#272A30', '#0F1013'),
    'bug-wing':    ('#F4F0E0', '#D9D3BC', '#A9A184'),
    # birds of prey and crows
    'eagle-brown': ('#8A6A4A', '#5E4430', '#34261A'),
    'eagle-white': ('#FFFFFF', '#F2EDDB', '#BDB49A'),
    'eagle-yellow': ('#FBE27A', '#EFC230', '#B38A10'),
    'raven':       ('#5A6678', '#2E3846', '#12161D'),
    'raven-sheen': ('#7C8DB0', '#46567A', '#232C45'),
}


def _f(name): return f'url(#fig-{name})'


def scaled_about(anim, p, inner):
    """`inner` scaled around p by the SMIL in `anim` (SMIL scales around the origin)."""
    return (f'<g transform="translate({p[0]} {p[1]})"><g>{anim}'
            f'<g transform="translate({-p[0]} {-p[1]})">{inner}</g></g></g>')


# ------------------------------------------------------------- duck

DUCK_FEET = (50, 70)                 # on the water line
DUCK_PARTS = {
    'tip':  ('rotate', (46, 66)),    # tips forward to dabble, tail in the air
    'head': ('rotate', (69, 50)),    # looks about
    'tail': ('rotate', (26, 58)),    # wags
    'eye':  ('scale', (77, 28.5)),
}
DUCK_SHADOW = None                   # nothing under it: it floats


def duck_body(anim=None, shadow=False):
    """A drake floating, facing right. Below the water line (y = 70) it is
    cut off; a ring on the water goes in front."""
    anim = anim or {}
    o = ['<defs><clipPath id="duck-water"><rect x="-300" y="-300" width="700" height="370"/></clipPath></defs>',
         '<g clip-path="url(#duck-water)">']
    o.append('<g>' + anim.get('tip', ''))
    # tail: a short upturned point, the drake's black curl
    o.append(f'<g>{anim.get("tail", "")}<path d="M27 58 Q17 56 11 46 Q21 47 31 51 Z" fill="{_f("raven-sheen")}" stroke="#151B24" stroke-width="0.5"/></g>')
    # body, the folded wing on it with its blue patch, the chestnut breast
    o.append(f'<ellipse cx="47" cy="60" rx="28" ry="14.5" fill="{_f("duck-grey")}"/>')
    o.append(f'<ellipse cx="40" cy="57.5" rx="18" ry="8.5" fill="{_f("duck-wing")}" transform="rotate(-6 40 57.5)"/>')
    o.append(f'<path d="M28 62.5 Q36 60.5 45 63 Q36 66 28 62.5 Z" fill="{_f("duck-blue")}"/>')
    o.append(f'<ellipse cx="68" cy="59" rx="10.5" ry="11.5" fill="{_f("duck-breast")}"/>')
    # neck with the white ring, then the head
    o.append('<g>' + anim.get('head', ''))
    o.append(f'<ellipse cx="70" cy="45" rx="6.8" ry="10.5" fill="{_f("duck-green")}" transform="rotate(8 70 44)"/>')
    o.append(f'<ellipse cx="69.5" cy="53" rx="7.4" ry="2.1" fill="{_f("eagle-white")}" transform="rotate(8 69.5 53)"/>')
    o.append(f'<path d="M81 28.5 Q96 28.5 97.5 33.5 Q96 38.5 82.5 36 Z" fill="{_f("duck-bill")}"/>')
    o.append('<path d="M82.5 36 Q90 37.5 97 34.5" fill="none" stroke="#8A6A10" stroke-opacity="0.5" stroke-width="0.6"/>')
    o.append('<circle cx="90" cy="31.2" r="0.7" fill="#8A6A10" opacity="0.7"/>')
    o.append(f'<circle cx="73.5" cy="30.5" r="9.6" fill="{_f("duck-green")}"/>')
    o.append(f'<ellipse cx="79.5" cy="32.5" rx="5.5" ry="4.6" fill="{_f("duck-green")}"/>')
    o.append(scaled_about(anim.get('eye', ''), DUCK_PARTS['eye'][1],
                          '<circle cx="77" cy="28.5" r="2" fill="#151B24"/><circle cx="77.7" cy="27.8" r="0.65" fill="#F2EDDB"/>'))
    o.append('</g>')
    o.append('</g></g>')
    # the ring where it meets the water, in front of it
    o.append('<ellipse cx="50" cy="70.4" rx="31" ry="4" fill="none" stroke="#BFE0F5" stroke-opacity="0.55" stroke-width="0.9"/>')
    o.append('<ellipse cx="50" cy="70.4" rx="31" ry="4" fill="#2A64A0" fill-opacity="0.25"/>')
    return ''.join(o)
