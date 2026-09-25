# Fresh corner integration and hydraulic ownership — pass 93

Fresh production generation confirms the pass-92 matching-height inner connection and the earlier broad outer turn. It also exposed and repaired a water-query integration error that the saved-world geometry replay could not detect. Unequal-height inner joins remain on their previous construction and remain visually unfinished.

The first fresh run, retained under `fresh-P12`, reports `Owned rock exceeds the prepared water margin` in chunk (-4,-1). Pass 92's connection callback inspected both complete halo wall candidates before owner selection. Some of those distant candidates exceed the caller's 26 m hydraulic query margin. The snapshot still completed, but this run is rejected as an integration acceptance result.

Production now constructs the canonical connected geometry before ordinary per-owner water admission. Each complete owned rock and each core-intersecting grass support still passes the existing authoritative water test. Wet solids withdraw with their visual/collision/support data. Water no longer determines halo connection geometry; this avoids both the escaped query and a query-dependent construction decision. Public/grade pair admission and canonical ownership remain unchanged. This supersedes pass 92's production whole-pair water callback; the optional external rejection callback remains available to detached callers/tests.

A regression fixture observing the actual production compute path records **168,646 escaped samples before the fix and zero afterward**, across four chunk domains. The mixed wet/dry fixture retains some dry rocks, withdraws intersecting complete solids, and produces identical whole-area and separate-chunk rock geometry/owners without duplicates. A fully wet fixture publishes no rock, rock collision or turf support. The observer uses a deterministic rectangular wet field to test admission/coverage, not to validate the hydraulic solver itself.

**24 tests / 194 assertions pass** across hydraulic ownership, inner connections, corner continuity, native attachment and snapshot reconstruction. [Red control](logs/cliff93-water-red.log), [initial green control](logs/cliff93-water-green.log), [full focused run](logs/cliff93-final-tests.log), [production delta](dressing.patch).

## Fresh native verification

The corrected run under `final-P12` generates seed **2697992464**, reaches all nine startup chunks in **422.643 seconds**, and finishes without the water assertion. This is not a controlled performance comparison: independent verification work ran during generation. The existing snapshot-writer diagnostic about an editor-only shader query remains; it is not a geometry failure or a clean-engine-log claim.

The actual newly generated scene contains, within the inspected area:

- Two connected wall formations at the **(-445.5,32,-301.5)** inner junction, with the separate corner withdrawn.
- Four outer corners and two retained shorter inner corners.
- Exact rock and turf reconstruction from every inspected saved recipe and buried floor: zero mismatches.
- All **84,004 distinct inspected triangles** present in the actual generated `CliffRocks` collision shapes, using canonical triangle keys quantized to 1 mm. No substitute test collision is created.
- **1,000 unique foot probes** against native ground after disabling added-rock collision: zero exposed roots and zero missing ground.

[Native audit](fresh-audit.json) · [Generation log](logs/cliff93-final-fresh.log) · [Audit log](logs/cliff93-fresh-audit.log).

## Visual review and limits

Six supplementary close views were captured directly from the freshly generated meshes, without replacing them with replay geometry. The front/elevated matching-height join retains the pass-92 improvement: the existing wall treads continue into the recess without a third competing shelf family. The outer view retains the broader uncompressed bend. The gray faces remain rather broad/plain, some treads remain thin, and the lower unequal-height intersection still has pointed, overlapping shelf ends. These are not accepted as finished cliff art.

[Fresh inner front](final-details/inner_front.png) · [Fresh inner above](final-details/inner_above.png) · [Fresh outer turn](final-details/outer_oblique.png) · [Unfinished stepped inner join](final-details/lower_inner_above.png).

`before-details` contains the same six cameras on the actual pass-88 world. The two remaining inner sites are not equivalent pairs of equal-height end walls: one includes vertically overlapping wall runs and a nonterminal short parent, and the other lacks two eligible parent ends. Their source diagnostic is [recorded here](logs/cliff93-parents.log). No speculative extension through a lower turf crown is promoted in this pass.

The original F3-based P12 captures and pose records are retained under `final-P12`; their obstructed framing does not replace the supplementary corner views for judging these surfaces. No player traversal, general streaming/water acceptance, whole-suite acceptance, or closure of the broader original judging register is claimed.
