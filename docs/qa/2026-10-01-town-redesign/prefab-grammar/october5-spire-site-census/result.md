# Spire supply: finished cap census and lost sites

Previous turn was progress: rejected the ineffective higher-datum candidate with seven-town evidence and restored production. This turn adds `tests/harness/suntail/town_spire_census.gd`, which counts actual cap instances in the combined retained-native + kit-built payload. It records asset IDs, stable owner IDs and transforms. Opaque whole-house prefabs remain separately listed, not silently counted as zero spires. This is a cap census, not a claim about screen visibility or internal geometry of opaque prefabs.

## Current realized parts

| Grand seed | Attached towers | Realized separate caps | Native grammar caps | Opaque whole-house prefabs |
|---|---:|---:|---:|---:|
| 8 | 0 | 1 | 1 | 0 |
| 83 | 0 | 0 | 0 | 0 |
| 13 | 2 | 2 | 0 | 0 |
| 43 | 1 | 1 | 0 | 1 |
| 103 | 1 | 1 | 0 | 2 |

Seed8's real native cap is `pure_village.native.roof_tower_1` belonging to `spatial.fabric.spatial.feature.landmark.00.component.00/native.0107`. Thus its previous attached count0 was not a zero-spire skyline. Seed83 truly emits no standalone cap and has no opaque prefab.

## Why 83 loses its tower-house

The source preference already selects a corner turret. Before carving, 86 possible footprint rectangles include12 that meet the probe's ground-bearing/huddle test; all12 have clear bodies. The carved plan retains12 ground-supported rectangles but0 clear bodies. The complete, untruncated conflict trace groups all12 sites:

- Two western footprint variants conflict with spine, market_square, perimeter and secondary_gate.
- Ten eastern footprint variants conflict with `district_access` and `loop_join`. They are anchors(11,0),(11,1),(12,1),(12,2) unflipped and(11,-1),(12,-1),(12,0),(13,0),(13,1),(14,1) flipped. These are diagnostic coordinates, never production exceptions.

This corrects the preliminary truncated40-contact sample: most sites are not lost to the main spine. `_carve_district_access` connects to the district centre before `_preview_reserved_columns` can protect landmark sites; its route crosses all ten eastern footprints. The native tower-house needs a6x4 footprint and14-band body (taller variant16), plus measured reach and bearing. A full street-fronting realization still has to be proved; the12 empty-field bodies alone are NOT12 guaranteed buildable houses.

Next implementation target: jointly choose the district's legal access/frontage and a preferred native tower-house site before committing the centre-crossing access lane, then protect the accepted complete envelope from loops. Keep actual district connectivity, addressable doors, short-house exclusion, bearing, clear routes and court space. Do not increase selection probability:83 already prefers this family. No production placement rule changed in this turn. All five town builds and both diagnostic runs are terminal; no live handles remain. Full October1 redesign stays active.

Reproduce census: `Godot --headless --path . --log-file /tmp/census.log -s tests/harness/suntail/town_spire_census.gd -- --cities 8:grand,83:grand --output /tmp/census.json`.
