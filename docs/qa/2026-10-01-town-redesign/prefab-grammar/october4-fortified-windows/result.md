# Native fortified-wall windows, October 4

Implementation checkpoint; the full redesign remains open.

## Change

`KitFortifiedFacades` replaces full, unscaled platform wall panels with Pure Village's native stone window module. The replacement keeps the facade's existing outer plane and extends its reveal inward. Its complete native frame must clear neighboring assets, roof skins, floors and public air. Piers, lintels and half-courses cannot squash a window module. Accepted windows are separated by at least one plain bay; an obstructed candidate yields to the next clear bay. This uses the generated town geometry, with no seed-specific production rules. The windows are rectangular native stone openings, not the arched decorative retaining-window asset.

The previous 0.9 m fortification footing intersected the native sill (lowest frame starts at 0.5603 m). The two courses now total 0.5 m and remain made from the existing closed native stone-block asset. This admits ground-storey openings without removing support or leaving floating trim. Platform occurrence and the structural/room layout are unchanged.

## Verification

- Eleven tests / 1,077 assertions pass across fortified facades, retaining recesses and interior citadel gates. An additional spacing/fallback regression passes six assertions (12 tests / 1,083 assertions total across the two runs).
- Finished grand towns 63, 83 and 103: native frames clear all other placed asset bounds; roof/floor contacts and inward public-air clearance pass. Interior-gate tests retain zero floating masses and roof/public-air intrusions, with zero exposed roof ends, gable holes, unsupported roofs and clipped eaves.
- 83/grand admits 23 fortified window panels. Both directions of its actual-character gate traversal pass on the final geometry.
- Matched 83/grand far and close views inspected; native full-height panels fit on both wall levels. Two other towns (63 and 103) were rendered and their overviews and face views inspected. The saved images are native engine renders.

## Limits

This improves selected blank faces; it is not a claim that all facade-depth or building-shape requirements are finished. Some short faces remain blank where roofs, stairs or corner piers prevent a complete opening. The reviewed towns still show oversized roof planes, tall repeated house fronts, and occasional abrupt masonry-family changes. These need further composition work. Windows decorate solid retaining construction; this change does not create new playable rooms behind them. No global performance or full historical-suite claim is made.
