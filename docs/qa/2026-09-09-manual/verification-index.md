# September 9 manual review — evidence index

Starting source: consolidated main `f3203d96`. The source photographs predate
consolidation. Individual reports distinguish current geometry, frozen source
facts and historical limitations. See [review ledger](review.md) for experiments.

| Issue | Evidence | Status |
| --- | --- | --- |
| 1. Running reaches unloaded terrain | [Streaming](review.md#1-streaming) | Reported route accepted |
| 2. Travel gets slower | [Retention and rendering](review.md#2-performance-degrades-during-travel) | Measured fixes accepted |
| 3. Floating/mounded/creased water | [Water](03-water/result.md) | Photos 5, 7, 8 accepted |
| 4. Missing town grass lip | [Native rim ownership](04-grass-lip/result.md) | Photo 2 accepted |
| 5. Repeated doors | [Connected facade entrance](05-doors/result.md) | Photo 3 accepted |
| 6. Rail misses post | [Native stair attachment](06-stair-rail/result.md) | Photo 6 accepted |
| 7. Hanging offset room | [Timber bay supports](07-offset-room/result.md) | Photo 12 accepted |
| 8. Abrupt road end | [Real road exits](08-path-end/result.md) | Photo 4 accepted |
| 9. Thin exposed turf | [Soil and timber border](09-thin-turf/result.md) | Photo 9 accepted through nearby views |
| 10. Tiny roof inside town | [Public ceiling ownership](10-tiny-roof/result.md) | Photo 14 accepted |
| 11. Open building seams | [Gable](11-seams/roof-result.md), [door return](11-seams/wall-result.md) | Photos 10, 13 accepted |
| 12. Broadleaf fern | [Jade Estuary habitat](12-fern/result.md) | Photo 11 accepted |
| 13. Bigger drifting orbs | [Size, motion and visibility](13-orbs/result.md) | Accepted |
| 14. Remove blur | [Depth of field](14-blur/result.md) | Accepted |
| 15. Biome atmosphere and warm glow | [Seven profiles and native light sources](15-atmosphere/result.md) | Accepted |
| 16. City lanterns | [Door brackets and garden posts](16-city-lanterns/result.md) | Accepted |
| 17. City decorations | [Native seating and storage](17-props/result.md) | Accepted |
| 18. Arches at tunnel entrances | [Supported native tunnel frames](18-arches/result.md) | Accepted |

Camera reconstruction uses rounded player/crosshair coordinates. The original
full-precision camera cannot be recovered; each before/after pair shares its
recorded reconstructed transform. Photo 1 lacks a crosshair hit and uses a
labelled inferred angle. Photo 9's exact view is occluded by merged geometry;
nearby matched views establish its repair. Pixel differences locate changes;
actual visual inspection and physical/field tests determine acceptance.

Known limits: the baseline suite was not globally green. Historical water,
cliff and composition failures are retained explicitly in the relevant reports.
The final water-enabled walking run crosses the reported boundary with zero
frozen time over 822 m, but its 298.923-second startup narrowly meets that
harness's 300-second deadline. This is not universal cold-start acceptance.

## Open the matched images

Each comparison belongs to the issue's completed stage. Later atmosphere and
lighting changes are reviewed separately. Columns in each triptych are before,
after, and amplified absolute pixel difference.

| Photo | Matched visual evidence |
| --- | --- |
| 1 | [Before](01-streaming/walk-before_crossing_inferred.png), [after](01-streaming/walk-buffer-candidate_crossing_inferred.png), [difference](01-streaming/walk-buffer-crossing_inferred-diff-x5.png) — inferred camera; final water-enabled traversal is recorded under issue 3 |
| 2 | [Before / after / difference](04-grass-lip/diff/02_grass_lip_exact_comparison.png) |
| 3 | [Before / after / difference](05-doors/diff/03_doors_exact_comparison.png) |
| 4 | [Before / after / difference](08-path-end/diff/04_path_end_exact_comparison.png) |
| 5 | [Before / after / difference](03-water/diff/05_water_edge_exact_comparison.png) |
| 6 | [Before / after / difference](06-stair-rail/diff/06_stair_rail_exact_comparison.png) |
| 7 | [Before / after / difference](03-water/diff/07_water_mound_exact_comparison.png) |
| 8 | [Before / after / difference](03-water/diff/08_water_crease_exact_comparison.png) |
| 9 | [Before / after / difference](09-thin-turf/diff/09_thin_turf_near_left_comparison.png) — clear nearby angle; exact angle is occluded |
| 10 | [Before / after / difference](11-seams/roof-diff/10_roof_end_exact_comparison.png) |
| 11 | [Before / after / difference](12-fern/diff/11_fern_exact_comparison.png) |
| 12 | [Before / after / difference](07-offset-room/diff/12_offset_room_exact_comparison.png) |
| 13 | [Before / after / difference](11-seams/wall-diff/13_wall_seam_exact_comparison.png) |
| 14 | [Before / after / difference](10-tiny-roof/diff/14_tiny_roof_exact_comparison.png) |

Additional reviews: [orbs](13-orbs/diff/near_orb_00_comparison.png),
[blur removal](14-blur/diff/pinned_00_comparison.png),
[Moonfen mood](15-atmosphere/diff/twilight_marsh_landscape_comparison.png),
[city lanterns](16-city-lanterns/diff/03_doors_exact_comparison.png),
[city furnishings](17-props/result.md),
[tunnel arches](18-arches/game-diff/tunnel_front_comparison.png).

[Final validation](final-validation.md): all 95 selected regression tests pass
with 78,973 assertions; six additional frontage tests pass with 5,266 assertions.
