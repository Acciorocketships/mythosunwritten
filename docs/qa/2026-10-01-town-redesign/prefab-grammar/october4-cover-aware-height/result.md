# Cover-aware height experiments, October 4

**Rejected. Production height behavior restored.** Neither late crown removal nor an early height cap has demonstrated an acceptable solution to the tall flat fronts. The architectural task remains open.

## Experiments

The late kit-stage trim preserved door rooms, balconies, adjacent construction and public air. It could not shorten the target 63/grand stacks: house.010 carries balcony/door obligations, and house.015 meets protected neighboring construction/public air. Its implementation and refusal records are archived here; it is not active code.

The next early cap retained the original optional roll as a maximum, bounded it by the underlying massif, and reserved a complete room above adjacent passage headroom. Required streets and carried rooms retained their existing authority. Seven candidate/gate tests passed (1,007 assertions), and all four finished towns had zero floating-mass and roof/public-air violations. Nonetheless 31/large lost its four quarter-cell ceilings two bands above a path. Structural validity was insufficient.

A second trial reserved two complete rooms above the passage. That restored the two-band ceilings, but still lost six four-band quarter-cell ceilings in 31/large and four in 7/standard. In seed 7 the aggregate count stayed 36: new coverage elsewhere hid the loss at `(0, 0, -3)`. Seed 53's original coverage was restored. Seed 63 still lost only distant ceilings, but a favorable target-town result does not excuse the other losses. This second trial did not receive the first candidate's unit-test acceptance; both were rejected by finished geometry.

The inspected native 63 overview showed shorter stacks, but still tall fronts. It is archived as a rejected experiment, not an accepted art result. Changing a parcel budget alters subsequent room composition; simply reserving one or two potential rooms is not equivalent to preserving the actual covered passage.

## Retained diagnostic

`tests/harness/suntail/compare_inhabited_cover.gd` compares two enclosure-probe JSON snapshots at the same town, walk and quarter-cell. It detects removed or raised ceilings, including missing towns/walks. New cover elsewhere cannot compensate. `--max-band` explicitly selects the ceiling-distance limit (default 4); malformed input fails separately. This is a review check, not a new runtime generation rule.

The comparator's three tests / 11 assertions pass. Running it on the second trial returns failure and identifies all ten lost quarter-cell ceilings within four bands. Exact records are in `rejected-comparison.json`. Candidate source and test files are preserved as `.txt`, outside production/test discovery.

## Next structural work

Preserve actual occupied room/door/balcony relationships when altering silhouettes, and make a roofable wing or setback within that structure. Do not repeat a broad optional-height cap with another arbitrary room reserve. The previous approved interior gates, native fortification openings and public masonry changes remain intact.

Restoration verification: all four rebuilt towns exactly match every baseline walk/quarter ceiling-distance record. The comparator passes with `--max-band 100` (all recorded ceilings), and each town has zero floating-mass and roof/public-air violations. See `restored-four.json` and `restored-comparison.json`.
