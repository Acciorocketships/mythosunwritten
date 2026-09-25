# Quieter cliff faces and localized wider terraces

The owner rejected the previous gouges, high-contrast streaks and thin ledges. The selected local revision reduces overlapping cuts, softens fine shader relief, and restores substantial lower shelves in selected stretches. Overall cliff art is still open: native upper-course repetition, some soft broad faces, and angular turf endpoints remain visible. This is an improvement pass, not owner acceptance or a claim to match the gold-standard reference.

## Selected change

`CliffRockCrags.gd` now uses sparse shallower fractures between broad faces. It retains full-height variation, actual native attachment, independent rock masses and the existing conservative erosion budget. Shader grain/bevel depth and painted crack contrast are reduced; the shader-only study was insufficient because most large streaks came from geometry.

The former 2.2 m aggregate shoulder clamp flattened the contribution of subsequent lower shelves. Removing that intermediate clamp restores outward steps; the existing final soft projection bound remains 7.75 m. The generic lower bulge is reduced, while finite localized terraces take their horizontal outlines from three sections of four original CC0 Ultimate Nature moss rocks, in both front/back orientations. Lower sections are wider; heights and slopes vary, some locations are omitted, and some omit the upper tier. Their supports are part of the same closed stone skin, not separate placed mounds.

The source baker is `tools/mountain_art/build_nature_terrace_profiles.py`; it emits `terrain/cliff/nature_terrace_profiles.json` with source paths, original OBJ SHA-256 values and licensing. A repeated source bake exactly matches the checked-in numeric profiles: eight distinct profiles, each with three bounded 97-point rows. Resources prepare on the main thread; workers read detached numeric arrays. No source OBJ or scene loads occur during worker placement.

Turf requires at least 0.55 m of actual tread at both ends of a strip. Smaller remnants remain stone. Broad shelves keep the native turf material, collision triangles and biome ground tint.

## Red/green and regression evidence

The new photo-anchor test reproduced three failed assertions on the original production geometry: insufficient broad tread area, substantial narrow painted remnants, and too few projecting basal samples. The fourth assertion, retaining quiet wall sections, already passed. [Original red run](red.log), [selected candidate green run](restrained-test.log), [production focused run](focused.log).

Seed is 2697992464. Measurements cover the 31 frozen production anchors near the original Amber Heath photos, rather than invented placements.

| Actual geometric measurement | Before | Selected |
|---|---:|---:|
| Turf area on treads at least 0.8 m deep | 30.343 m² | 213.850 m² |
| Turf area on remnants narrower than 0.5 m | 69.296 m² | 0 m² |
| One-metre lateral foot samples projecting over 4 m | 89 | 112 |
| One-metre lateral foot samples projecting under 2.5 m | 235 | 204 |

These are geometric guards, not a beauty score. The existing turf check independently measures 275.405 m² of usable green area and zero hairline triangles. Real detached grass sampling finds 83 rooted patches with zero escaped/buried roots. Plant canopy checks find 167 placements and zero crowded pairs. Native root tangent, cut-through, closed straight/corner collision, full-height variation, chunk ownership, native grass and normal-fan checks pass.

The initial focused run passes 41/45 tests (1,137/1,163 assertions). Its four failures demand the old deep-cleft density, exact old caps, or exact old fracture inventory—the art that the owner explicitly rejected. Those four historical proofs now run against their frozen selected revisions, with names/comments stating that scope. Their numerical thresholds were not relaxed. Current physical integrity and new wider-tread guards still exercise production. The affected three-file rerun passes seven tests / 88 assertions, bringing the distinct focused set to 45 passing tests / 1,163 assertions across the two runs. [Historical art-control rerun](art-history.log). This is not a full-suite claim.

The headless runs include the existing macOS certificate-loader diagnostic before GUT. The selected geometry comparison exits zero and proves that all 31 production forms exactly match the rendered candidate's stone and green arrays: [comparison log](selected.log). The production corner generator uses the same unchanged wrapper around that generator. GPU context and tall-construction processes exit zero.

## Visual judgment

All 17 selected frozen game views were inspected: the reconstructed reported P05/P12/P17/P20 cameras, each with both neighboring offsets, plus five supplemental front/side/vine views. These use the saved world, lighting and ReviewCam-derived poses. The original terrain, ground grass and collision are frozen; current cliff meshes and crevice plants are rebuilt.

- [Head-on context](restrained/P20_oblique.png): larger quiet stone faces replace much of the overlapping dark cut pattern. Some native vertical/course repetition remains. [Matched previous production](../16-cliff-shoulder-union/final/P20_oblique.png).
- [Shelf and corner](restrained/P12_front.png): localized broad lower shelves are clearer; the large right face remains fairly soft. [Close reported view](restrained/P12_reported_0.png).
- [Long wall and base](restrained/P17_reported_0.png): foot projection varies along the wall, with broader shelves near the selected cluster. The convex join remains covered; diagonal cap endpoints remain somewhat angular.
- [Shaded wall](restrained/P05_vines.png): fewer overlapping cuts, but the shaded stone is still visually muddy. Plant relocation is a consequence of changed crevices, not evidence that stone detail improved.

A diagnostic on the identical P20 image rectangle x=250..1450, y=380..560 reports mean adjacent-pixel luminance gradient 0.00871 → 0.00611, and the fraction over 0.025 falls from 7.39% to 4.28%. The rectangle includes some relocated foliage; this is supporting image evidence only, not a stone-only acceptance test.

All five 64 m native studio views were inspected: [front](tall/front.png), [oblique](tall/oblique.png), [close](tall/close.png), [wide](tall/wide.png), [ledges](tall/ledges.png). Larger upright forms survive, localized bases expand, and no opened seams appeared. The native repeating pattern and some dark structural pockets remain visible. These are construction controls, not fresh streamed terrain.

## Rejected and intermediate studies

- `broad`: removes the shoulder clamp and reduces cuts, but does not give enough localized basal structure. Only two views completed before the exploratory capture stalled.
- `nature`: direct union with a dense source-rock depth field produces ragged green edges. Rejected after inspecting the P20 reported center.
- `nature-exact`: exact source-triangle edge events produce comb-like thin triangles at the cap. Rejected. The first process had a corrected GDScript type-inference error; only `exact2.log` is the successful capture.
- `tiered`: native horizontal sections feed the existing closed ledge builder; cleaner result, but remaining narrow paint strips.
- `wide`: minimum tread width increased and tier elevations varied; improves caps, but dense cuts remain.
- `quiet`: compact source profiles and weaker shader relief; improves fine noise only.
- `restrained`: selected sparse geometry plus quieter shader and broader localized shelves. All 17 views inspected.

Earlier normal-map and deeper-cut studies were also rejected: [pass 17](../17-cliff-face-detail/result.md). Failed exploratory captures are not complete evidence sets. The review harness now uses the existing `RenderingServer.force_draw()` capture pattern after settling frames; this is not a general renderer fix.

No fresh world generation, actual player traversal, global streaming, hydraulic, performance or full-suite acceptance is claimed. The original manual issue register and overall cliff art remain open.
