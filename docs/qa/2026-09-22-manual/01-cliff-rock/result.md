# Cliff rock dressing: banks, towns, terrace edges, ledge steps and corner feet

Owner report (September 22, seed 2697992464, eight F3 photos). Every site was
reproduced in `tests/harness/cliff_site_review.tscn`, which streams the real
world once and then hot-reloads only the rock layer. Its `_kinds`/`_ids`
renders colour each formation by recipe, which separated generator faults from
seams between formations.

## Causes and changes

1. **Bare river walls** (photos 2, 3). Every riverside formation stood on the
   channel bed and was vetoed by `_wet_formation`; the diagnostic at N04 listed
   them all as `wet`, including the inner corner under photo 3's lip at
   (-322.5, 8, 757.5). Water fronting a wall is now the formation's support:
   `CliffRockDressing.waterline` raises the formation to 1 m below the surface
   (`WATERLINE_DEPTH`), keeps no turf below the water, and skips faces with less
   than 3 m above it. `_wet_formation` rejects only rock deeper than that foot.
2. **Bare cliffs beside towns** (photo 1). The veto was the warren's whole-town
   clearance rectangle (79 x 72 m), whose edge lies on the cliff face. That
   rectangle is now a `FeatureGroundShape.envelope`; terrain rock and cliff
   vegetation pass `include_envelopes=false`. Lots, paths and stairs still
   reserve space, and a reservation in front of a wall compresses the rock's
   reach (`_fit_reach`) instead of dropping the 24 m panel.
3. **Bulbs with sheer walls** (photos 4-6). Kind renders show outer corners of
   upper plateaus whose feet extended past a narrow terrace; the floor then
   followed the next level down, extruding a smooth drum. Formations now measure
   their supported depth (`CliffRockCrags.supported_depth`) and scale each
   column's projection beyond the native attachment to fit (smoothed across
   neighbouring columns); floors ignore ground more than 2.5 m below the base.
   A first hard clamp left a flat-fronted block at photo 6 and was replaced.
4. **Sharp steps in ledges** (photos 7, 8). The Amber step lay inside one
   formation. Probing columns found a terrace appearing at strength 1.74 within
   25 cm: the baked Nature-rock sections end in vertical silhouettes. They are
   now slope-limited (`_taper_section`). A second step came from the sequential
   shelf-merge cascade. Merging is now a symmetric pairwise strength transfer
   (only near-equal shelves meet halfway; a clear winner keeps its elevation),
   a smooth fade of a weaker shelf within a hand's width (no stone channel),
   and one tread for exactly coincident shelves. It is order-independent.
5. **Honey-pool outer corners**. Measured feet: the corner arms reached 6-9 m
   around a 3-4 m turn. The whole corner foot now compresses (arms included,
   strongest in the lower half) and thick bodies facet into 2-3 seeded chords.

## Evidence

- `tests/test_september22_cliff_rock.gd`: 8 tests. The ledge-step, merge-order
  and corner-foot tests are red on a reconstructed pre-change copy (step 1.62,
  arms 8.6-10.1 m, order-dependent merge) and green now.
- Full sweep of the 82 cliff/crag/rock/bank/outcrop/ledge/terrace test files,
  compared file-by-file with the reconstructed baseline: all 81 existing files
  have identical pass/fail counts (37 already failed on baseline; historical
  fixtures), plus the 8 new tests. Two old assertions were updated on purpose:
  the pass-120 byte-identical tall-corner pin now asserts corners never widen
  and keep their turf, and the solid-outcrop crown tolerance is 2 mm (the
  order-independent merge moves a near-crest shelf by about 1.1 mm).
- Images (same harness cameras): `river-*`, `town-*`, `bulb-img4/5/6-*`,
  `amber-img7/8-*`, `corner-plan1/2-*` (top-down; before = previous corner
  shaping on the same terrain).

## Limits

The photo-3 camera could not be reproduced exactly; the diagnosis rests on the
now-admitted inner corner. Narrow (< 6 m) wall panels remain bare native tiles.
Waterline banks narrow channels by their projection above the foot; no new
swim traversal was run. Straight-wall feet are unchanged and can still be broad.
