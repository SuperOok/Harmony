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
    'duck-back':   ('#8E8A7E', '#6C685C', '#46433A'),
    'duck-black':  ('#3A4250', '#1E242E', '#0B0E13'),
    'hen-body':    ('#D2B58C', '#A98458', '#6B4F2F'),
    'hen-head':    ('#C9A87C', '#9C7A50', '#5F462A'),
    'hen-wing':    ('#B79468', '#8A6A42', '#523C22'),
    'hen-bill':    ('#F5B35A', '#D88B2E', '#8E5414'),
    # ladybird
    'bug-red':     ('#F26A55', '#D63A2B', '#8F1F16'),
    'bug-black':   ('#4A4F57', '#272A30', '#0F1013'),
    'bug-wing':    ('#F4F0E0', '#D9D3BC', '#A9A184'),
    # birds of prey and crows
    'eagle-brown': ('#8A6A4A', '#5E4430', '#34261A'),
    'eagle-white': ('#FFFFFF', '#F2EDDB', '#BDB49A'),
    'eagle-yellow': ('#FBE27A', '#EFC230', '#B38A10'),
    'eagle-dark':  ('#6B5238', '#3F2F20', '#1E160E'),
    'eagle-gold':  ('#D2AB72', '#A27B48', '#6B4D2A'),
    'chick-down':  ('#FFFFFF', '#EAE5D5', '#B9B19A'),
    'chick-beak':  ('#F6D77A', '#E0B13A', '#A87C14'),
    'fish':        ('#EEF3F6', '#A5B8C6', '#5E7384'),
    'raven':       ('#5A6678', '#2E3846', '#12161D'),
    'raven-sheen': ('#7C8DB0', '#46567A', '#232C45'),
}


def _f(name): return f'url(#fig-{name})'


def scaled_about(anim, p, inner):
    """`inner` scaled around p by the SMIL in `anim` (SMIL scales around the origin)."""
    return (f'<g transform="translate({p[0]} {p[1]})"><g>{anim}'
            f'<g transform="translate({-p[0]} {-p[1]})">{inner}</g></g></g>')

