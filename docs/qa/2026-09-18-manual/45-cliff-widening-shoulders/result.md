# Widening supports and geometry-linked joints

**Experimental; not promoted. Production remains byte-identical to pre-trial pass 34, which is itself not artistically accepted.** The owner rejected the tall tapered rectangles and detached short scratches. This pass fixes a newly reproduced study discontinuity and compares connected geometric joints, but it does not resolve the overall cliff composition.

## Concrete defect found and repaired

The P12 front view's large dark slab was initially suspected to be a side closure. Actual mesh rays instead locate it inside anchor 9: identity orientation, origin (-433.5, 32, -301.5), width 21 m, height 8 m. Its front jumps almost two metres between neighboring 25 cm strips. The shelf's sloping top crosses a hard `height - 0.8` eligibility limit and removes its entire supporting volume at once. This is a pass-44 study bug, not a demonstrated production-pass-34 defect.

`crown-continuity-test.gd` samples the actual photographed mesh at twelve adjacent-strip pairs. It is red on `fan` at **1.877900 m** and green on the direct `joined` repair at **0.111900 m**. Shelf strength now vanishes continuously before the eligibility boundary; its foot consumes the same strength. The final `rooted` study measures **0.076100 m**. The original slab disappears in the matched native P12 front image. The wider fade initially removed too much of the upper ledge, so later studies use a narrower continuous interval.

A separate source-profile regression is red on pass-44 `unified`: its shoulder has a **4.75 m** constant-depth centre. An asymmetric curved profile reduces that plateau to **0.25 m** in the final study. This test checks a specific shape mechanism, not visual quality.

## Shape experiments and judgment

- `fan` introduces asymmetric shelf outlines and short widening feet. Seven tests / thirteen assertions pass, but the crown cutoff defect remains. Rejected.
- `joined` repairs that cutoff. Only the narrow continuity gate was run on this intermediate source. The big slab disappears, but large smooth faces remain. Rejected for art promotion.
- `nature` adds actual prepared Nature-pack front sections before the bearing operation. Seventeen native game views show that the stretched/combined volumes still look too smooth and blanket-like. It is not a tested production candidate.
- `geology` adds an oblique irregular partition shared by broad face relief and narrow joints; shelf elevations are distributed across the available wall height. Eight of nine tests pass; recession reaches 1.006400 m. Tall views become too busy. Rejected.
- `formed` enlarges the shared stone partition and reduces the joint. Eight of nine tests pass; filtered outline correlation is 0.662761 versus the unchanged 0.65 limit. Long upright supports remain visible. Rejected.
- `united` tries the outer maximum of neighboring shelf supports. Seven of nine tests pass: it removes the reported shelf and increases repeated large outlines. The render has conspicuous narrow vertical forms. Rejected.
- `rooted` preserves the shelves but broadens their lower shoulders gradually over their full descent, rather than completing the widening within five metres. Nine tests / seventeen assertions pass. Lower supports merge more, but the close game view still has large plain faces, thin treads and an awkward near-crown transition. **Not promoted despite the green tests.**

The final detail controls use the same `rooted` composition and stone partition with no additional joint, a 2.5 cm joint, or a 10 cm joint before edge/cap/thickness weighting. These are physical recesses in the actual mesh and collision faces. Their boundaries follow the same partition that shapes the broad stone faces; no crack texture or disconnected scratch segments are introduced. Removing the joint retains that broader rock geometry. All three controls pass the same nine tests / seventeen assertions independently (nine distinct tests, 27 executions).

The stronger treatment makes the connected network legible, but introduces small jagged edges in some close views. The subtle treatment is quieter; neither fixes the remaining composition. No option is accepted as the finished cliff. Plant placement is regenerated against each mesh, so plant pixels differ; this is not a foliage-invariant image comparison.

## Verification

The final subtle study retains all 31 closed, nondegenerate photo shells and all 57 reported turf contacts. Photo recession is 0.481800 m, crown excess is zero, and 336.563661 square metres of sampled turf has at least 1.5 m tread depth. Convex-corner recession is 0.264087 m across 188 columns. Mean filtered tall-outline correlation is 0.559873. Individual upper comparisons still reach 0.829339: the aggregate diagnostic is not proof that local columns are gone.

The no-joint control has photo/corner recession 0.456900 / 0.244602 m; the stronger joint has 0.556600 / 0.322337 m. Both retain the same measured broad turf area and crown bound. No test threshold was relaxed.

There are **104 native PNG captures**: four seventeen-view game sets (fan, joined, nature, rooted), six five-view tall sets (geology, formed, united, rooted and the two rooted joint controls), and two three-view P20 joint-control sets. This is an inventory, not 104 independent art acceptances. [Comparison page](comparison.md) selects the useful controls and the reproduced continuity defect.

The game harness replays frozen September-16 world geometry and rebuilds the study's rock/plant formations. It does not regenerate world grass or establish fresh-world streaming, physical player traversal, hydraulic safety, performance, or broad suite acceptance. Grass and broader corner-admission gates were not repeated for these rejected art candidates. All other issues in the original judging register remain open as previously recorded.

## Reproduction

Use `/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story` with a unique `--log-file`.

Tall study: `res://tests/fixtures/september18/cliff-widening-shoulders/rooted-tall.tscn -- --height=64 --output=res://docs/qa/2026-09-18-manual/45-cliff-widening-shoulders/rooted-tall`. Replace `rooted` with `rooted-clean` or `rooted-joints` for the controls.

Game: `res://tests/harness/september16_cliff_transition_context.tscn -- --generator=res://tests/fixtures/september18/cliff-widening-shoulders/rooted.gd --corner-generator=res://tests/fixtures/september18/cliff-widening-shoulders/rooted-corner.gd --corner-study --output=res://docs/qa/2026-09-18-manual/45-cliff-widening-shoulders/rooted-context`. Add `--site=P20` for the three reconstructed photo poses.

Tests select source using `STORY_CHANNEL_GENERATOR`, `STORY_BUTTRESS_GENERATOR`, `STORY_BUTTRESS_CORNER`, and `STORY_COLUMN_GENERATOR`. Run `test_september17_ledge_channels.gd`, `test_september17_cliff_buttress_support.gd`, pass-44 `macro-column-diagnostic.gd`, plus this pass's `outline-test.gd` and `crown-continuity-test.gd`. Logs retain the red and green measurements. `surface-diagnostic.gd` and `cut-diagnostic.gd` record the actual mesh-ray and eligibility diagnosis.
