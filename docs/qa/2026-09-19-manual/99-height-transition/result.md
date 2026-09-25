# Height-transition corner review — pass 99

**The candidate is rejected. All five production/replay files are restored byte-for-byte to their pre-study versions.** The earlier broad outer wrap and matching-height inner ledge remain. The short stepped seam is still open in production.

## What the experiment established

The short turn at (-421.5, 28, -349.5) has two omitted 3 m native panels and adjoining walls of different heights. The candidate admitted connected narrow panels, preserved rock depth below the actual adjoining column's height, and tapered only the exposed upper end. The join selector preferred an already-containing parent over extending a more distant wall. Canonical ownership and complete water/public/grade rejection remained in place.

This supplies the missing rock and removes the independent short corner. However, the adjacent wall generators still produce different depth profiles. Their closing faces become conspicuous where those profiles meet. The short turn gains a pointed face, and the neighboring lower turn gains a large diagonal slab. The latter is a clear regression against the pass-97 control. Passing topology and collision do not justify retaining it.

- [Short corner before](../97-inner-ledge-levels/final-details/short_inner.png) · [Rejected short corner](final-grass-details/short_inner.png)
- [Lower corner before](../97-inner-ledge-levels/final-details/lower_inner_above.png) · [Rejected lower corner](final-grass-details/lower_inner_above.png)
- [Broad inner ledge](final-grass-details/inner_above.png) and [outer wrap](final-grass-details/outer_oblique.png) remain visually coherent in the candidate, but do not outweigh the regression.

The next repair must coordinate the actual adjoining depth profiles and tread boundaries through the height transition. Merely removing end taper, admitting omitted pieces, or adding another independent corner surface exposes the same underlying mismatch.

## Structural and native evidence — rejected candidate only

The pinned reproduction initially fails both tests (1/5 assertions passing). The candidate passes 32 distinct focused tests / 168 assertions across transition admission, complete closed solids, turf membership, inner connections, water ownership, stepped joins, corner continuity, replay, deterministic ordering and whole-versus-partitioned terrain ownership.

The fresh-world audit exposed one replay error: an 8 m wall has one column buried 4.2 m below its datum while the other 108 columns end at -0.2 m. Restoring a single global floor changed the triangle count. Rebuilding with the saved per-column floor profile passes the new regression and the three contract tests (4 tests / 12 assertions, including nine assertions already counted above). Thus the candidate's distinct total is **33 tests / 171 assertions**. This replay fix is archived with the candidate, not retained as a production change in isolation.

The final grass-covered native world has:

- 6 joined walls across 3 inner connections, zero independent inner corner pieces, and 4 retained outer corners in the inspected neighborhood;
- 210,508 distinct inspected triangles, with zero missing from native collision and exact current-recipe reconstruction;
- 2,344 per-column/base foot probes, all buried in actual native ground;
- 4,683 isolated native contact rays across 22 affected walls, zero misses, maximum error 0.00003599 m;
- 1,964 additional wall-root samples, zero exposed roots or missing ground.

These are structural facts about the rejected geometry, not acceptance of its appearance, traversal, water behavior, streaming or performance. Fresh startup with grass is 426.254 seconds and remains expensive.

## Capture scope and exclusions

`study/` uses a truncated native-wall inspection domain that changes a tall parent's extent; it is excluded. `study2/` corrects that domain and `join/` adds the containing-parent connection. Both are frozen art studies, not fresh production.

`fresh-P12/` was generated without `--grass`; its geometry evidence is valid, but `final-details/` is excluded from grass-covered visual acceptance. The corrected final world is `fresh-grass-P12/world.scn`, with 53 grass batches and 14,879 committed instances. Six fixed supplemental views are in `final-grass-details/` and match the pass-97 supplemental poses. Five of those views were inspected directly; the short and lower-above views establish rejection.

The fresh harness's automatically reconstructed P12 cameras enter the character/grass and are not useful art views. Their three captures are excluded. `reported-before/` and `reported-after/` instead retain twelve exact historical camera transforms and FOVs from `2026-09-16-manual/10-rounded-ledges/production-01` across P05/P12/P17/P20. They load the respective complete frozen worlds without rebuilding rock. The character is hidden in both controls. P12 and P20 central views were inspected; no claim is made that all twelve pairs were judged. These supplementary captures do not replace the original camera evidence.

The snapshot writer retains its known editor-only shader-parameter diagnostic. Both fresh processes and the final native detail, audit and contact processes exit successfully. No renderer or startup-performance acceptance is claimed.

## Restoration and reproducibility

`production.patch` and `source-hashes.json` describe the rejected candidate. Its exact source is archived in `tests/fixtures/september19/height-transition/rejected-candidate/`. `restored-source-hashes.json` proves every edited production file matches its before copy. Candidate regression files live outside the ordinary test catalogue under the same fixture directory; their passing logs describe the candidate applied at that time, not restored production.

The unchanged production inner-connection and ledge-level tests pass **8 tests / 83 assertions** after restoration, including 34 shared tread samples with a maximum height difference of 0.00000047683716 m. The original judging register, lower shelf crossings, short inner seam and broader cliff art remain open. No production improvement is claimed for pass 99.
