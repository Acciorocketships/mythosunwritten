# Photo 13: open doorway return

The merged room already stops its perpendicular window wall at the complete
door panel's measured back. The same world planes match within source float
precision. However, ordinary axis clipping leaves the side panel's cut face
open. The photographed wood window 013 return fails all 15 native triangle
rays across this exposed thickness (red test, exit 1).

Options: move or overlap the neighboring wall, insert an unrelated pillar,
or finish the existing cut using its declared native joint stock. The third
option preserves the established room, door return plane and window relief.
The baker now applies the same closed-cut treatment used by facade miters to
actual nonzero doorway-return cuts when their manifest declares timber cap
stock. Uncut ends and panels without such stock retain their prior behavior.
All affected ordinary and floor-owned-cap derivatives must be rebaked; native
surface coverage, actual public collision and matched images decide acceptance.

All 14 initial related tests pass (661 assertions, 52.22 s, exit 0). All 132
walk cells and 188 crossings retain identical central clearance. The bake-wide
metadata census found a maximum 10.014-micrometre AABB change. A first vertex
containment test incorrectly treated the native source's stored AABB as its
actual decoded extent and failed on 434 of 674 variants. Inspection showed
native decoded vertices tens of micrometres outside that metadata. The corrected
reference uses actual native source vertices, without widening the one-micrometre
geometry tolerance. All 674 variants remain inside those original vertices'
bounds and the declared return planes. The three final targeted tests pass
1,131 assertions in 25.427 seconds, exit 0. The rejected test log is retained;
no production geometry changed to address that reference error.
