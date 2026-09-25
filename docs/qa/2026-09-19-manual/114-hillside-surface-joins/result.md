# Shared-fill rise diagnosis — longitudinal shaping remains experimental

Production is unchanged. W01, W02's broader hydraulic scope, and all other open original judging issues remain open. The final experiment reduces the largest measured route rise from 0.269745 m to 0.141434 m but does not eliminate it. The explicit actual-mesh downhill gate still exits 1.

## What the diagnosis establishes

Seed 2697992464, source route (-2,-1), exact samples 166–199 from pass 113 were replayed through chunk (-6,-4). We preserved 954 native profile segments and inspected 154 surrounding lattice points. Changing the claimant ranking from absolute bank margin to normalized or centreline distance does not fix the reported points: all three direct profile selections are already non-increasing. The first hypothesis of a simple width-ranking error is not supported here.

The filled field already rises before meshing: four increases, largest 0.269751 m. Its actual mesh has three, largest 0.269745 m. Around the bend, offered river anchors of 25.700 m become final coarse levels down to 3.500 m. The shared connected-surface grade reconciliation lowers the source profile around neighboring lower reaches, without preserving descent along a curved river. Meshing changes small measurements but does not originate the main rise.

The diagnostic's initial missing-key error is fixed by reading anchors from the complete source result, rather than the chunk projection which intentionally omits them. Raw nonfinite diagnostic values are retained in `diagnosis-raw.txt`; JSON represents dry/nonfinite values as null without changing finite measurements. Failed reader attempts are superseded by the final claims run.

## Experiment and rejected regression

`profile_grade.gd` shapes a backwards descent along the actual river course before seeding. Actual rendered-ground clearance constrains lowering; a sill can require a steeper slope. The isolated generated WaterField copy uses grade 0.22; the existing shared-fill limit remains 0.30. This is not a production setting or accepted architecture.

The first version represented the whole route as a dense descent. That accidentally removed ordinary bank collars. Its promising 0.0401 m field / 0.0272 m mesh maximum rise was accompanied by extra neighboring water visible at P10's alternate view. It is rejected, with complete source snapshots and captures in `rejected-bank-loss/`.

A failing regression now pins the lost bank provenance. Each dense edge retains either its original ordinary segment, or the marker for a true descent. The seeder restores original bank widths and terminal-pond handling. Five focused tests / twenty assertions pass, including actual native/candidate seed ceilings and the rule that a bank constraint is not itself a water source. An initial integration fixture incorrectly described a descent and failed equally on original/candidate; the corrected ordinary-bank control is the valid test.

## Final native and physical review

Both fresh native site replays completed, exit 0. Non-water geometry, all instance transforms/buffers and ground collision match pass 113 exactly:

| Site | Geometry records | Collision shapes | Identity |
|---|---:|---:|---|
| P10 | 787 | 38 | Identical |
| P21 | 720 | 36 | Identical |

The sites overlap; counts are not unique world totals. The 441 fixed ground rays per site are unchanged. All 24 positive water-triangle centroid controls across paired scenes hit.

Compared with pass 113, P10 has 99→100 wet survey positions (one dry-to-wet), with retained surface changes −2.738 to +0.153 m. P21 has 203→196 (seven wet-to-dry), with retained changes −3.947 to +0.00549 m. These neighboring coverage changes require further hydraulic judgment; they are not automatically accepted because fewer samples are wet.

All 247 supply-route points within captured terrain still hit water. The other 21 points remain outside snapshot coverage. Two >10 cm buried-water points remain in both versions. Final actual-mesh rises are:

- Sample 177: 0.141434 m, unchanged from pass 113.
- Sample 178: 0.009918 m, down from 0.269745 m.
- Sample 190: 0.027206 m, down from 0.057602 m.

The final field retains two rises, largest 0.269751 m. This differs from the rejected bank-loss candidate and shows why its apparent improvement cannot be reported as the final result.

Inspected reported/overview/90° views retain removal of the high hillside sheet. Restored banks remove the extra P10 background flooding seen in the rejected candidate. Frozen dressing still exposes bare old cliff tiles where water withdrew. Opaque blue is a coverage diagnostic; it is not acceptance of finished optics, animation, swimming, shoreline art or cliff dressing.

- [P10 reported view](after/P10/view_0.png), [overview](after/P10/overview.png), [alternate](after/P10/view_90.png)
- [P21 reported view](after/P21/view_0.png), [overview](after/P21/overview.png), [alternate](after/P21/view_90.png)

## Next correction and limits

Instrument the source pipeline at seed, relaxation, containment and final grade stages around the remaining bend and confluence. Preserve bank constraints while making their interaction with river heads consistent. Do not accept the bank-loss version, flatten the rendered mesh independently, or relax the downhill gate. A pre-shaped source profile alone is insufficient.

Route discovery cost, canonical shared reaches, partial depositional bars, larger confluences, fresh full-game integration and broader original issues remain unresolved. No broad performance comparison or production promotion is claimed. Headless logs retain the existing macOS certificate warning; native snapshot saves retain the known editor-only shader-list warning. Both final native and physical/identity processes exited normally.

## Reproduction

Fixtures are in `tests/fixtures/september19/hillside-surface-joins/`:

- `prepare.py` regenerates the isolated field from current production source with asserted patch locations.
- `test_profile_grade.gd` through GUT: five tests / twenty assertions.
- `native.gd -- --reaches --spots=P10,P21 --opaque-water`: native Metal, explicit log file.
- `geometry_identity.gd`: identical non-water scenes.
- `physical_samples.gd -- --spots=P10,P21 --survey` and `-- --spots=P10 --supply`.
- `native_audit.py`: passes terrain identity, fixed survey/pose and positive controls.
- `supply_audit.py --require-downhill`: expected exit 1; final candidate is not accepted.

All process handles from this pass are terminal. Historical progress notes below are superseded by this result.
