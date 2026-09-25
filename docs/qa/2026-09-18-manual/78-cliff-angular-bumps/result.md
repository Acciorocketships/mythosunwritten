# Source-shaped bumps and carved-body studies — pass 78

Production geometry remains exactly pass 77. The new studies are not promoted: native game and tall-wall views still expose the rejected broad smooth faces, repeated upright forms, or loss of useful ledges. The authoritative addition is a regression test that catches major ledge-area loss missed by the previous geometry checks. C01–C04 and the full original issue register remain open.

## Experiments

All studies change real mesh coordinates, with no texture or shader change. The saved P20 oblique game camera, seed 2697992464 and fixed 32 m tall study provide direct comparison with pass 77.

1. `candidate.gd` samples the unfiltered Nature rock bodies for the local physical bumps, increases depth from 0.35–0.75 m to 0.55–1.05 m, and shortens the union blend. The red photo regression first fails on baseline with zero changed vertices. Candidate has 733 outward-moving exterior vertices across 79 columns and retains all original turf points and the crown. Six tests / 18 assertions pass. The native result still reads as shallow marks on broad smooth supports. Rejected.
2. `integrated.gd` introduces larger rock profiles before tread construction is finalized, so the ledges and supporting mass can change together. Actual foot sampling includes that added depth. It gives fuller lower formations but exceeds the upper projection envelope by 0.110635 m (limit 0.08 m). Eight of nine tests pass, 19/20 assertions. Rejected.
3. `bearing.gd` uses one filtering pass for the new profiles, smaller depths and a slower crown-to-base growth curve. The envelope excess drops to 0.058752 m and all nine tests / 20 assertions pass. Both native images still retain tall smooth supports and creased-looking detail. Rejected visually.
4. `carved.gd` replaces the additive body/support calculation with a single varying rock body and finite cuts above the ledges. It bypasses the old final projection/addition stack for this experiment. Native images have more distinct stone forms and wider tall ledges, but also dark undercuts and abrupt sampling features. Seven of nine tests pass: maximum recession is 0.5115 m and only 48/57 reported tread probes are covered by turf. Rejected.
5. `supported-carved.gd` limits downward recession to 0.16 m per metre of height. Maximum recession drops to 0.032 m; turf coverage improves to 51/57. Eight of nine tests pass. It remains a rejected intermediate study.
6. `open-carved.gd` removes downward recession. All nine existing focused tests / 20 assertions now pass, including 57/57 tread samples, 31 closed/nondegenerate photo shells and 440 preserved tread-grade samples. However, native views lose much of the useful ledge area and regain straight supporting columns. Rejected despite green tests.

## New area regression

`tests/test_september18_cliff_ledge_area.gd` measures the actual turf-triangle area of 48 m wide controls at heights 8 and 32 m. At least 75% of the preceding production area must survive a face-detail change; this is a conservative regression bound, not an art-quality score or a complete measure of ledge distribution.

| Height | Pass 77 area | Open-carved area | Retained |
|---|---:|---:|---:|
| 8 m | 69.1376 m² | 39.9820 m² | 57.83% |
| 32 m | 48.9225 m² | 16.6252 m² | 33.98% |

Both new tests reproduce red on open-carved (2/4 assertions) and pass on unchanged production (two tests / four assertions). `ledge-area.json` also records the earlier variants. Merely preserving some pointed caps and passing one reported ledge is insufficient to protect the wider cliff composition.

## Views and scope

Inspected native pairs: `world/` and `tall/`; `integrated-world/` and `integrated-tall/`; `bearing-world/` and `bearing-tall/`; `carved-world/` and `carved-tall/`; `open-carved-world/` and `open-carved-tall/`. The supported intermediate has a recorded game capture but is not claimed as a separately judged acceptance view. All native render processes terminated successfully.

The game harness replays frozen terrain, lighting and grass, replacing rock visuals and their plants. It does not validate fresh placement, collision, water exclusions or actual traversal. The focused tests check geometry; no new native physics, worker integration, global suite or performance acceptance is claimed. Production is byte-identical to `before.gd` and recorded in `source-hashes.json`.

## What the evidence changes

Increasing the physical profile depth alone leaves the inherited support composition in place. Moving shapes earlier affects real lower volume but still inherits those supports. Carving the body exposes a second constraint: above-ledge clearance must coexist with broad ledge area. Enforcing clearance by propagating each upper maximum downward destroys too much of that area and creates the same columns again. Further construction work must solve finite ledge clearance and their supporting volume together; the monotone-column correction is explicitly rejected.
