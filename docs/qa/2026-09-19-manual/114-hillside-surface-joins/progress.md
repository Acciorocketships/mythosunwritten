> This pass is complete as an experiment; every process is terminal. See [result.md](result.md) for final values and rejection limits. Production is unchanged.

# Hillside surface diagnosis and longitudinal descent experiment

Production is unchanged. W01 and the complete original judging register remain open.

The previous turn answered a status question only (no implementation progress). This turn resumed the actual failed diagnostic process, fixed its reporting error and completed the source/field/mesh diagnosis.

## Completed diagnosis

- Original process 45385 reached `c.fill.rivers` missing-key error. Interrupted only after observing that actual error; it exited 130.
- Corrected process 65229 completed exit 0: 34 exact route samples, 154 surrounding lattice points, 954 frozen profile segments.
- Source anchors are read from `_source_fill`, not the chunk projection (which does not retain the river array).
- The raw JSON writer emitted nonfinite dry values. `diagnosis-raw.txt` retains those bytes. `diagnosis.json` represents these explicitly as null; no finite number changed. Two failed readers are superseded by the final clean `claims.gd` run. The probe now normalizes nonfinite JSON tokens on writing.
- `claims.gd` compares absolute bank margin, normalized channel distance and centreline distance. All three select non-rising profile heights across the 34 route samples. The initial ownership-metric suspicion is not supported here.
- The field itself has four local rises, maximum 0.269751 m, before triangulation. The saved actual water mesh has three, maximum 0.269745 m. Meshing changes the smaller values but does not originate the main defect.
- Around the bend, native river anchors at 25.700 m become final coarse levels as low as 3.500 m. The later connected-surface grade reconciliation lowers those values around surrounding lower reaches. A monotone input route does not ensure a monotone resulting 2D fill.

## Isolated experiment in flight

`profile_grade.gd` shapes the descent longitudinally before offering seeds. A backwards distance envelope uses the actual river course and rendered-ground clearance; required physical sills may retain steeper slopes. A generated copy of WaterField calls this helper; production has no reference to it. Current experiment grade is 0.22 versus the existing shared-fill grade limit of 0.30.

Three helper tests / twelve assertions pass: bend arc distance, actual sill clearance with downhill order, unchanged gentle rivers and lakes, immutable inputs. This is only local mathematics, not native acceptance. The existing pass-113 actual-mesh downhill gate is the red target.

Current candidate probe session 82168: building one source solve at chunk (-6,-4), seed 2697992464, with original geological carving and the pass-112 long reach adapter. Await its actual result before native captures or promotion. No source solve is restarted on elapsed-time observations.

## Candidate field result

Session 82168 completed exit 0. Longitudinal shaping reduces four field rises in the inspected interval to one, from 0.269751 m maximum to 0.040105 m. Ground is unchanged. The residual starts at route sample 190, at the confluence into a flat 1.7 m receiving reach. A 6 m interpolation cell mixes its low receiving anchors with a higher tributary corner; changing margin to normalized distance does not change that corner ownership. The candidate remains unselected.

Native two-site replay started as session 78887 (Metal), using the original saved terrain and current generated water. Candidate helper tests pass 3 / 12; native/physical acceptance still pending.

## Native rejection and repair

The first native candidate completed both sites and exact non-water geometry identities matched. The actual 247 in-scene route probes remained wet, but one rise of 0.027206 m remained. Alternate P10 views exposed additional neighboring water. This candidate is rejected and all its captures/results/source snapshots are in `rejected-bank-loss/`.

Cause: representing the entire route as one dense descent silently changed ordinary river sections from their native bank collars to the descent seeder's zero-bank rule. A new provenance regression fails on that candidate. The helper now retains a source segment per ordinary dense edge and a distinct marker for actual descents; the generated seeder restores each original bank width and terminal-pond rule.

Five tests / twenty assertions pass, including actual original/candidate seeded bank ceilings and the bank-not-source condition. The first integration fixture unintentionally described a descent rather than an ordinary bank and failed on both implementations; its corrected long flat reach is the valid control. Native replay session 60298 is rebuilding both sites with restored banks. No production change or issue closure.
