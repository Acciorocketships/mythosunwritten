# P02 retained turf and boards

Current frame (-2,1), town cell (-43,45); native world transform X=(0,0,-2), Y=(0,2,0), Z=(2,0,0), O=(-1033.5,9.08,1095.5). The current source and payload reproduce the original photograph's raised turf block, crate/jar, vertical timber and underside timber.

- `masonry-joint/19/0/-9` and `/19/1/-9`: scaled `sfv.deck.pillar.001`, world bounds x -1047.664 to -1046.336, z 1066.336 to 1067.664, y 9.08 to 15.08. `masonry_corner_joints` uses this timber to close recessed diagonal/concave masonry contacts. `masonry_room_returns` shares the same treatment.
- `maze-soffit/10/0/-4/5` and `/11/0/-4/5`: `sfv.fabric.gallery.floor.m.001` at y 8.84 to 9.1621; bottom boards span x -1046.998 to -1040.998, z 1061 to 1067.
- Raised turf rims `maze-rim-corner/11/1/-3/3`, `/11/1/-4/1` and adjoining rim runs, backed by retained rock at y 8.98 to 14.98. The garden props reproduce the photograph.

Next repair must preserve complete joint closure and actual route/support footprints. Native-only views cannot adjudicate the surrounding painted road, and no repair is claimed. The render logs contain two existing material UID fallback warnings.
