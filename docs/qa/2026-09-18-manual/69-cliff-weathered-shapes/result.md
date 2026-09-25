# Physical rock formations merged into the cliff

The owner clarified that the next change must add actual bumps, outcrops and irregular formations, rather than repeated texturing. Production now samples existing baked Nature rock shapes into local physical formations. Their placement, widths, heights, tilt, lean and reach vary deterministically. Lower shoulders widen the root, while a continuous union merges overlapping formations into the existing closed cliff mesh. The collision and planting pipeline consumes those actual triangles. No material, normal-map or color-texture change is part of this iteration.

The new formations share the existing broad lower rocks through a maximum, so overlapping lower systems do not double their reach. New projection is constrained by the actual wider foot and gradual crown-to-base envelope. The upper attachment remains intact. Ledge fronts and backs receive the same continuous displacement; closed shells and native footing remain required.

## Rejected work and remaining visual limits

The initial surface-relief experiments were the wrong emphasis. Strong noise looked like wrinkling; broad cell relief looked like creases; a material experiment produced incorrect purple coloring. These remain isolated study fixtures. A separate embedded-mesh experiment looked like small rocks pasted onto the face, and was rejected. None of those surface or material experiments is used in production.

The first merged-formation candidate passed its focused checks but failed the wider upper-silhouette guard: 0.132488 m excess against the 0.08 m bound. Its original tests, fresh snapshot and captures remain under `production-tests.log` and `fresh-P12/` as superseded evidence. The final version constrains extra projection by the same lower bearing envelope. `final-P12/` is a separate fresh generation of this correction.

Native final views show broader, uneven lower shoulders and locally different rock silhouettes. They still show overly smooth upper faces and upright support organization, particularly on the 64 m study. Some turf boundaries remain thin/angular. This is a retained physical-geometry step, not full cliff-art acceptance or a claim that the gold-standard reference has been reached. No original water, town, streaming or biome issue is closed.

## Regression evidence

The new mesh regression fails on the no-crags baseline: zero moved vertices, zero affected columns and zero added depth. The final production mesh moves 5,332 of 38,717 sampled lower vertices by more than 0.25 m across 118 columns, while 28,426 samples remain within 0.02 m of the baseline. Maximum added depth is 2.401400 m. The upper quarter remains unchanged in this control. This checks actual vertex positions, so a shader-only edit cannot satisfy it.

The final combined run passes 30 tests / 95 assertions. The upper-silhouette survey reports zero excess over 304,264 samples; 32,333 photo-lip samples have zero breaches. All 57 ledge-cap probes retain turf and 31 sampled shells remain closed. The actual grass worker retains 345 supported patches with zero escaped or buried roots; corner geometry, orientation, public/wet admission and chunk ownership checks pass. Native physical results follow below. Frozen art captures deliberately do not claim regenerated grass or collision. Seventeen final frozen views and one final 64 m oblique study are retained; P12 side, P17 front, P20 oblique and tall oblique were directly inspected, including the pass-66 P17 comparison. P20 retains a broad plain face: this evidence specifically prevents claiming that the owner’s smooth-wall complaint is fully resolved. Compare the same cameras in pass 66's `world/` and `tall/` directories. Production provenance is in `source-hashes.json` and `production.patch`.

## Fresh native world and collision

The final fresh P12 world completes in 480.953 s and commits 53 grass tiles / 14,883 instances (11,686 visible). This timing is not a controlled performance comparison. Three fixed-camera captures and the snapshot are retained in `final-P12/`; the main view was inspected. The original fixed actor pose is inside the changed rock, so it is not used as a valid supported player stance. Separate traversal cameras and physical checks establish support. The known editor-only shader-global query warning occurs during snapshot saving; the process exits zero.

All twelve actual-character walks, both directions on six ledges, pass with zero underside contacts. A native ground probe discovers 126 formations, 26 near the site, and checks 370 foot points with zero exposed or missing bearings. These run against the final fresh snapshot rather than the earlier frozen art fixture. `walks/walks.json` and `root-probes.json` preserve their measurements.

All final launched test, capture and physical-check processes have exited. The original judging register and full cliff-art acceptance remain open. This pass makes no full-suite, hydraulic, streaming or startup-performance claim.
