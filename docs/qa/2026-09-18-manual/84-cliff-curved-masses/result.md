# Cliff shape studies and P02 buried timber — pass 84

No cliff candidate from this pass is selected. Production `CliffRockCrags.gd` remains the pass-82 version, including its physical Nature-derived bumps and bounded added-depth transitions. The owner's request for stronger, more interesting rock forms is still open.

## Rejected cliff studies

All studies change actual mesh geometry, with the existing material. The P20 oblique images rebuild rock and plant visuals on the pass-83 fresh-world snapshot; they do not rerun candidate terrain, grass or collision. The tall views use the native 32 m studio wall. These are art rejection studies, not gameplay acceptance.

| Candidate | Result |
| --- | --- |
| `candidate` | Bending whole formations produces little improvement; broad panels still dominate the game and tall views. |
| `union` | Replacing accumulated ledge support with a soft union removes useful ledge area. Ordinary area retains 82.29%, tall only 50.75%. Two of three tests pass, 5/6 assertions; reject. |
| `projected` | A continuous descent projection retains 86.27% ordinary and 87.93% tall ledge area and passes six tests / 12 assertions, but several visible ledges become hairlines. Reject on the native views. |
| `clasts` | Denser, stronger sampled Nature bumps produce pinched small forms in the game view. Reject. |
| `stones` | Clipped convex stone fronts remain too soft in the game view. Reject. |
| `seated` | The convex fronts with a shorter ledge blend remain soft and uneven; the tall wall looks wrinkled. Reject both inspected views. |
| `shoulders` | More frequent, broader rooted shoulders add depth but retain broad smooth panels and an uneven tall-wall silhouette. Reject both inspected views. |

The tests reported for `union` and `projected` are candidate-only checks. No geometry acceptance is claimed for the later art-only studies. An initial test command without an explicit log path crashed in Godot's RotatedFileLogger and is not counted as evidence.

## Selected P02 repair

The original T05 stray-board report includes horizontal timber protruding from the base of retaining stone. The town seed is 2697992464; player position is (-1050.8, 9, 1055.9), crosshair (-1048.7, 9, 1060.8). The pass-83 frozen CPU source retains the actual current town construction.

`maze_ground_skin_transaction` already removes buried lower faces of ground-level turf. Its loop inspected only the cells holding the *top* turf cap. On a taller retaining column, the cap is at y=1 while the buried lower cell is y=0, so the ordinary soffit renderer still emitted a timber floor under the stone. The normal rule now examines retained column cells. Elevated lower faces remain eligible for their required soffits.

The red regression reproduces both photographed instances (`maze-soffit/10/0/-4/5`, `maze-soffit/11/0/-4/5`) in the exposed faces, final treatments and native payload: 8 of 12 assertions fail. After the repair, 26 tests / 932 assertions pass, including both open elevated garden underside controls and the complete production-surfaces test file.

A fresh compilation from the frozen CPU source removes 30 ground-level soffits in this town (343 → 313 native instances). No remaining instance changes, no new instances, and public surface payloads, explicit collision boxes and walked cells are identical. Collision belonging to the removed native soffit instances is removed with them; no unchanged-collision claim is made for those instances.

Four before/after native pairs were rendered and inspected: the reported pose reconstructed with ReviewCam.solve_cam, and front, overhead and side diagnostics. They show the bottom boards removed while the stone, turf and furnishings stay in place. This isolated native fixture does not include the surrounding terrain or path paint, and is not a fresh full-world traversal. Two pre-existing material UID warnings fall back to valid text resource paths during the native run.

The vertical timber joint remains open. A separate study substitutes native stone in 12 pure masonry joints, but exposes bright white native end surfaces and is rejected. No change to vertical joints is selected.

T05 is therefore only partially repaired. T04's raised path block, T06's surrounding path paint, other town issues, the full cliff art request, and the broader water/streaming/biome register remain open.

[Reported native before](town-soffits/native/before-reported.png) · [Reported native after](town-soffits/native/after-reported.png) · [Payload difference](town-soffits/difference.json) · [Production change](production.patch)
