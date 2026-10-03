"""Every setting of the scene drawings in one place.

The reasons behind them are in docs/szenen.md. Change a value here and every
scene follows; change a shape in landscapes.py.

Units: the drawing is 100 x 100. Heights are measured upwards from the
middle of a hex.
"""

# Background and haze: the app icon's (MyApp/IconFlower.swift).
BACKGROUND = '#22313A'

# The board, seen at a slant.
HEX_RADIUS = 12.5
SQUASH = 0.42                 # how flat the board lies: 1 = from above
HEX_FILL = '#2F424C'
HEX_EDGE = '#3E5560'
HEX_GAP = 0.95                # a board hex is drawn this much of its size

# How things fade with distance. A row r < 0 lies -r rows behind the front.
FADE_PER_ROW = 0.22           # visibility lost per row back
SATURATION_FAR = 0.45         # colour left in anything behind the front row
HAZE_TOP = (0.22, 0.5)        # the sky: solid down to, then fading out by

# A stone: radius, its ellipse, its height.
STONE_RX, STONE_RY, STONE_H = 9, 3.5, 6.3

# Stone colours: base, light, dark. The stones' colours in the game view
# (MyApp/Game/SampleData.swift), with a light and a dark shade added.
STONES = {
    'stone':  ('#8C8C8C', '#A9A9A9', '#626262'),
    'brick':  ('#C74238', '#DA5A4D', '#8F2E25'),
    'wood':   ('#734F30', '#8C6442', '#4F3520'),
    'leaves': ('#408F4A', '#58AA62', '#2B6633'),
}
SHADOW_OPACITY = 0.28

# Building: smaller than its field, the stone under it narrower than the
# roof, so the eaves stand out. The roof has no wall of its own.
HOUSE_RX, HOUSE_H = 6.0, 5.6
EAVE_RX = 7.4
ROOF_RISE = 5.6               # ridge above the eaves
CHIMNEY = ('#7B7B7B', '#5E5E5E', '#3A3A3A')
DOOR = '#3B2A1E'
WINDOW = '#F4CF6B'

# Tree: a narrow trunk of wood stones, a crown of round clumps.
TRUNK_RX, TRUNK_RY = 5.2, 2.0
CROWN = [  # (dx, dy above the leaves' foot, radius, in the back)
    (-2.6, -15.2, 3.4, True), (2.8, -14.4, 3.3, True),
    (-5.2, -10.6, 4.0, True), (0.2, -11.6, 4.4, True), (5.4, -10.4, 3.9, True),
    (-7.0, -6.4, 3.7, False), (7.0, -6.2, 3.6, False), (0, -7.4, 4.4, False),
    (-3.8, -3.6, 3.9, False), (3.8, -3.4, 3.8, False),
]
CROWN_FRONT = ('#74C57B', '#46974F', '#2E6B36')    # light, base, dark
CROWN_BACK = ('#55A35D', '#357A3E', '#22552A')

# Mountain: a rocky cone stepping in at every stone. Its stones are drawn
# taller than the others so that a Berg3 is at least as high as a Baum3.
MOUNTAIN_STONE_H = STONE_H*1.45
MOUNTAIN_FOOT = 0.95          # radius at the foot, in hex radii
MOUNTAIN_FACES = 12
MOUNTAIN_TAPER = 1.7          # larger: steeper sides
MOUNTAIN_LEDGE = 1.4          # how far a ledge stands out
MOUNTAIN_LEDGE_LIGHT = 34     # how much lighter a ledge is
MOUNTAIN_GREY = (122, 62, 12)  # grey = a - b*(normal to the right) + c*(normal to the viewer)
SNOW_FROM = 3                 # height from which a mountain has snow
SNOW_DOWN = (0.62, 0.84)      # how far down the peak, ragged between
SNOW = ('#E9EEF1', '#BFC9CF')  # in light, in shade
RIDGE_HEIGHT = 0.85           # ridge between neighbours, of the lower one
RIDGE_DIP = 0.25              # how far it sags in the middle
RIDGE_WIDTH = 0.62            # in hex radii

# Water: one surface over neighbouring hexes, a bank only towards land.
WATER = ('#4C8FC8', '#2A64A0')  # far, near
RIPPLE = '#BFE0F5'
RIPPLES_PER_HEX = 7
BANK_WALL = '#1B3A55'
BANK_EDGE = '#8FC3E6'

# Field: three ways to read it, chosen per animal (see docs/szenen.md).
FIELD = {
    'korn':    dict(ground='#7A5F22', edge='#A88A3A', spacing=(1.9, 1.15),
                    height=(2.6, 3.5), stalk='#9C7A26',
                    ears=('#E2B743', '#D4A733', '#EDC85A', '#C99A2E')),
    'praerie': dict(ground='#4F5A26', edge='#7C8A3C', spacing=(2.2, 1.3),
                    height=(1.6, 2.9), blades=('#8FA845', '#A9AE4C', '#C2B65A', '#78953C', '#B9C46A'),
                    flowers=('#F2EDDB', '#C7A4E0', '#F2CF4C', '#E58C7A'), flower_share=0.12),
    'steppe':  dict(ground='#A98B52', edge='#C9AE72', spacing=(3.6, 2.2),
                    height=(1.0, 2.0), blades=('#CDB676', '#B9A15E', '#A89559', '#D9C88F'),
                    pebbles=('#8E7A5A', '#9C9384', '#7D6E57'), tuft_share=0.55),
}
