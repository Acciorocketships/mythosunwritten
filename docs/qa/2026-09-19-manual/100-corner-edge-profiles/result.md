# Cliff end-cap repair and corner-profile study — pass 100

The production change repairs invalid closing triangles after rock shaping and ledge warping. It does **not** resolve the remaining short inner seam or lower shelf crossing. The experimental shared-depth transition stays outside production.

## Retained production repair

An actual physics ray through the diagonal slab in the rejected pass-99 image hits the end cap of the wall at `(-445.5, 32, -289.5)`, not an added face bump. Some existing closing diagonals cross the deformed polygon's outline. Independently checking the previous production geometry also finds **eight escaping triangles on three walls**, so this is not merely a defect introduced by the rejected experiment.

`CliffRockEndCaps.gd` triangulates the final end outlines after shaping and ledge warps. It retains every boundary sample, including collinear samples, so adjacent triangles still share complete physical edges. Sorted boundary traversal makes the result deterministic and idempotent. The front, back, top, bottom, turf, vertex set and rooted outline remain unchanged. No height-transition admission or profile compression from pass 99 is retained.

The pinned regression fails with eight escaping triangles before the change and passes afterward. The final focused run passes **22 tests / 133 assertions**, covering cap containment, closed edges, preserved surfaces and roots, idempotence, inner connections, ledge heights, corner continuity and snapshot replay. The 34 existing shared tread samples retain their sub-micrometre agreement.

## Fresh native verification

A fresh grass-covered P12 world completes in **429.485 seconds**. This is an observation, not a controlled performance comparison. Its inspected neighborhood contains 31 straight walls, four outer corners and one remaining independent short inner corner; four walls retain two connected inner joins.

- All inspected rock and turf reconstruct exactly from current recipes.
- All **320,237 distinct inspected triangles** exist in actual production collision.
- All **3,917 foot probes** remain buried in actual native ground.
- An independent check of **4,387 end-cap triangles on 31 walls** finds zero escaping or degenerate triangles.
- **6,533 isolated native collision rays** hit their corresponding visible wall, with maximum position error 0.00006104 m. A further 3,470 wall-root probes find no exposed roots or missing ground.

The `changed_walls` field in `physics.json` is an inherited diagnostic label: its value 31 means all sampled walls, not 31 demonstrably changed wall shapes. This check measures contact agreement, not player traversal. The snapshot writer retains its known editor-only shader-parameter diagnostic; fresh generation and all native audits/captures exit successfully.

## Visual judgment

All six fixed supplemental final views were inspected. The main inner ledge and outer wrap retain their previous silhouettes. The cap repair introduces no visible new slab in those views, but the pre-existing lower crossing and short seam remain conspicuous. No overall cliff-art acceptance is claimed.

- [Main inner ledge](final-details/inner_above.png)
- [Outer wrap](final-details/outer_oblique.png)
- [Lower crossing, still open](final-details/lower_inner_above.png)
- [Short inner seam, still open](final-details/short_inner.png)

The controls use the same six poses in `../97-inner-ledge-levels/final-details/`. Twelve additional captures in `reported-after/` retain the original P05/P12/P17/P20 camera transforms and FOVs. Their controls are `../99-height-transition/reported-before/`; both hide the character and load complete frozen worlds without rebuilding the rock. The P12 central pair was inspected directly; no claim is made that all twelve pairs were judged. Fresh P12 also uses the historical camera-pose root, rather than the invalid automatically reconstructed actor-intersecting poses from pass 99.

## Experimental profile blending — not retained

The height-aware pass-99 walls can be contracted toward the actual adjoining collinear wall's depth profile. A pointwise clamp collapses triangles; proportional depth compression preserves the sections but still exposes invalid old cap triangulation. Rebuilding those caps changes the study from **150 escaping / seven degenerate cap triangles to zero / zero**, and removes the largest spike. The final study also has zero nonmanifold edges, lost turf triangles or vertices outside the prior bounds.

Those structural successes do not make the short corner acceptable. The `section-caps-short/` views retain a mismatched shelf and pointed upper contact. The diagnostic in `short-ledge-levels.json` explains why ordinary ledge-height matching cannot resolve it: one narrow parent has two turf groups, while the other has none. Simply increasing the allowed height warp would not supply the missing tread. The next investigation must follow the real adjoining wall runs through that narrow transition and coordinate their supported surfaces.

The initial `shared-edges/` replay omitted corner root metadata, so its absent-corner collateral is excluded. Later `shared-short/`, `section/`, `section-caps/` and `section-caps-short/` studies restore exact corner geometry and metadata. The structural bounds diagnostic was corrected after cap reordering: comparing vertices by triangle index falsely reported outward movement; comparison against the original actual bounds reports zero expansion. None of these study variants replaces fresh production evidence.

`production.patch`, `source-hashes.json`, archived logs and `manifest.json` preserve this pass. Fixture-only experiments are under `tests/fixtures/september19/corner-edge-profiles/`. Short-corner continuity, lower shelf crossings, broader cliff appearance and the original water/town/streaming/biome judging register remain open. No full-suite, global performance, water or streaming acceptance is claimed.
