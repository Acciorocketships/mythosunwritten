# More town silhouettes, overhang beams and sheltered canopies

September 26 follow-up, isolated in `codex/town-shapes-wood`.

Lot houses now mix one-, two- and three-storey buildings (18% cottage threshold, 55% medium threshold, remaining tall where the lot allows). Twelve plan families combine with independent width/depth choices: the lot is a maximum reservation, and the planned entrance stays fixed. Rear setbacks, double-ended wings and narrow upper floors add further silhouette differences. Existing long terraces, door access, corner posts and the two wood roof finishes remain.

Every exposed edge of a full-cell upper projection receives the kit’s timber floor beam, including its corner return. Internal module seams receive no trim. This shared assembler change also applies to planner-owned town overhangs without changing their floor ownership.

Freestanding ground-floor faces beneath upper projections have an 85% canopy candidate probability. Whole-canopy footprint clearance then admits only non-overlapping pieces, prioritizing entrance porches. Native review caught perpendicular/adjacent canopy collisions in the first candidate: an independent transformed asset-bounds regression records 63 overlaps without spacing and zero with it. The rejected close-up and corrected `b11_a.png` preserve that comparison.

## Verification

- Original code fails the size/height, overhang beam and sheltered-canopy regressions (`red.log`).
- Final suite: **38 tests / 3,092 assertions pass** (`tests.log`). Includes native roof/balcony collision, connected floors, reserved-lot bounds, doors on all four frontages, multi-cell projections, beam placement, wood finishes and actual canopy bounds.
- The long-balcony/projection prevalence checks now use the multi-storey population because new one-storey cottages cannot have upper projections. This preserves the earlier requirement without forcing every new small house to be tall.
- **18/18 real-player walks pass** across the flat hamlet square and house approaches. The final spacing correction removes only visual canopy instances; canopy assets have no collision.
- Five matched individual gallery pairs plus alternate-side/cottage views inspect silhouettes, corner supports, beams and canopy spacing. The individual camera offsets are fixed; the final 12-house gallery has more background buildings than the earlier 8-house gallery.
- Compact seed 1 and standard seed 2 dense-town reviews check the shared beam assembly. Their planner-authored shapes and existing canopy policy are unchanged. The partly occluded compact street image is not used as primary visual proof.

The final full in-world capture uses seed **2697992464**, player **(235.1,12,449.2)**, the existing `--reported` camera and eight orbit views at 65 m radius / 32 m height. Its baseline is the preceding pass’s final town capture. All nine chunks and nine captures completed with the final spacing code. The reported view and orbit 0/2/4/6 pairs were inspected: cottage/tall-house contrasts and narrower footprints are visible, overhangs retain their corner supports and new edge beams, and the square and approaches remain open. Ten gallery/site pixel comparisons are retained as review aids; live grass and particles prevent a terrain-identity claim.

Reproduce with the commands in `docs/qa/2026-09-26-town-architecture/result.md`; use `--set lots --count 12` for the expanded gallery. No texture rebake is required. The unrelated pre-existing outskirts planner-envelope failure remains documented in the original review.
