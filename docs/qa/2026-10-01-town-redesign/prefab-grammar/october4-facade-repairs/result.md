# Download-2: facade and support repairs, October 4

Status: progress, not acceptance of the whole town or prefab grammar.
Both complete native views in this directory were inspected. The review
includes public decks, bridges and guards; isolated building batches had
made walked terrace tops look like hollow houses in the earlier screenshot.

## Retained changes

- Pure Village's unframed gable over stone gets the existing Suntail horizontal
  timber at its base. The beam is seated at the masonry face (0.2 m proud of
  the plaster datum). Timber storeys already have a head beam and do not get
  a duplicate; open branch ends and roofs on another level get no beam.
- Facade fitting checks a projecting bay's whole measured bounds against the
  finished roof/floor triangles. The previous glass-only test missed the hood
  colliding with a cornice. A conflicting bay becomes a complete fitting
  window or plain panel through the existing fitter; clear bays remain.
  This is a conservative bounds admission rule, not a complete roof/bay
  connection grammar or exact triangle-against-triangle intersection test.
- Tunnel crowns retain the same Pure Village masonry as their supporting
  retained walls. They previously changed to plaster, while odd half-storeys
  used vertically compressed framed blue Suntail stone. A real native
  `WallStone_Start_20x15_1` now supplies the half-height retaining course.
  Native source measurements are saved in `native-half-stone-final.log`.
  Existing native corbels and closed decorative windows can now fit tunnel
  supports too, with the same backing, obstacle and public-air checks.
- The grey cubes under upper corners were the **Stone material surface in
  Suntail Crossbar_1**, used as the corner floor beam. The new native variant
  excludes only that surface. All original timber vertices and indices are
  identical. Oak/walnut descriptor variants preserve the host's finish.
  Source Crossbar_1 and its textures remain unchanged.

The first gable beam sat mostly inside the stone relief. That candidate was
rejected visually and the final beam moved forward to the masonry face.
The final view removes the roof-piercing left hood, retains the clear front
bay, makes the cottage's sill visible and removes the grey corner blocks.
The tall support no longer switches between three wall families.

## Validation

- 17 focused tests / 5,778 assertions pass (gable seam, native corner beam,
  native retaining courses, eave fitting, backed windows and corbel relief).
- Facade-contact suite: 14/15 tests, 290/291 assertions. The new hood test
  passes for both kit families and all four orientations. The failing
  `test_reported_upper_street_keeps_high_native_windows_on_its_suntail_house`
  also fails with both this turn's fitter integration and assembler changes
  disabled: 0 qualifying windows on its hard-coded 2/grand house ID.
  Baseline and changed logs are retained; the test was not relaxed.
- Eight-town finished-kit corpus after masonry/relief changes: all build,
  zero floating-mass and roof-public-air violations. Covered quarters remain
  36,18,42,68,14,24,40,92 for 7standard,31large,13large,43grand,58large,
  101large,103grand,211grand. Summary saved. The subsequent corner-beam change
  only removes stone geometry; its timber is identical by vertex/index test.
- Production real-terrain test: 125/125 assertions, 6,708 ms under the unchanged
  8,000 ms budget (machine factor 1.000).
- Native full-context views inspected from both sides. Actual-player traversal of 7/standard skywalk.0 passes in both directions
  (2/2), with the final collision payload; see `player-walk.json`.

## Still open

The shed hood's corner assembly and larger upper overhang still need work.
The stone box beneath the upper public deck now shares its neighbors' masonry,
but its protruding shape is not claimed artistically resolved. Flat support
faces and the overall enclosed-massif composition remain part of the larger
redesign. The full prefab-derived generator is still unfinished.

Canopy source investigation found the relevant rule in Pure Village
`StreetHouse_7`: four `Roof_BottomCurved_OutCorner_5x5_1` pieces at the rectangle
vertices, plus middle runs between them, all at one datum. Their world
transforms are saved in `hood-corner-source.log`. The current `_emit_pent_eaves`
ends every face independently with left/right caps and never uses those
corner modules. Implement a connected-run rule, using source corner geometry
and whole-assembly clearance; do not just overlap two capped strips. Straight
and curved corner families both exist. Their pivots and vertical extents are
not interchangeable. This investigation is not a completed canopy fix.
