# Issue 07 — P07 public platform connection

Accepted for the photographed platform and the measured controls. The platform is retained and can now be entered from the adjacent staircase. Issues 08 onward, including inter-town roads (36), remain separate queue entries.

## Reference and failure

P07 is `Screenshot 2026-09-12 at 12.02.18 PM.png`, seed 2697992464, rounded player (-225.8,14.1,-977.8), rounded crosshair (-226,15.4,-978.1). `ReviewCam.solve_cam` reconstructs the tactical view from these values. The overlay does not contain the complete original camera transform: the reconstructed before/after transforms match each other exactly, but cannot be called the exact historical camera.

Deck.01 retains its sixteen floor cells, world x=-231..-219, z=-979..-967, y=14.08. Its declared neighboring walk cell lies within staircase 07 rather than at a level landing. The coarse floor label concealed the actual tread heights and the intervening railing. All six actual character crossings failed before the change (`walk-current/walking.json`), three lateral positions in both directions.

## Alternatives and implementation

A first source-planning candidate admitted only level-landing frontages. It removed this platform without finding a replacement and changed room allocation. That candidate was rejected and restored; its source, code and checks are retained in `rejected-site/`.

The accepted connection uses one already-owned court cell at the low end of the flight, with another existing court cell supplying its level approach. It reserves a clear passage at the canonical minimum width and headroom and rejects steep grades or a wall in that passage. It consumes no new source plot. The new closed mesh follows the actual stair tread heights on the flight edge and slopes down to the level court on its other edge. Ramp flights use their continuous profile. The same vertices supply rendering and collision. A returning guard protects the raised side, and the flight guard opens only over this physical connection.

The original and current source files are byte-identical (SHA-256 f0316b109901952f963ee75a97b90d96484ece9d5172622cafd835113408c0ef). All photographed floor cells remain. Payload comparison finds one added transition mesh and changes to the adjacent structural skin and flight guard. Retiling changes the local boards, gallery-floor pieces and support pillar batch; wall/roof/decor batches are unchanged. Collision boxes and logical walked cells remain identical. See `payload-comparison.json`.

## Verification and visual judgment

- Six original walking attempts fail; the same six candidate attempts pass. They cross the real finished collision at x=-230.4,-229.5,-228.5 in both directions, without jumping (`live-candidate/walking.json`). The outer approaches produce a small lateral slide beside the existing wall/guard, but complete the crossing.
- The focused original-code tests fail both tests (five assertions). The original live walking failure was recorded before implementation. The additional small geometry invariant was subsequently run against the isolated original code and then against the candidate.
- Fifteen distinct focused/control tests pass 449 assertions across `green.txt` and `controls.txt`, counting shared tests once and retaining the expanded final platform test. Controls cover stairs and ramps in four orientations, outward faces, matching collision triangles, absent approaches, occupied passage air, steep grades and the preceding path/rail repairs.
- The full 48-town corpus constructs 48/48 and retains 11,868 clear centers and 17,038 clear crossings. The fingerprinted corpus gate passes 95 assertions (`corpus.txt`, `corpus-gate.txt`). The same 24 historical off-center pillar contacts remain. No full-suite or general performance acceptance is claimed.

Three reconstructed photo pairs (`current` → `after`) and three close approach pairs (`detail-before` → `detail-after`) were judged individually. They show the retained deck, an open entrance, joined walking surfaces and a connected guard, with no new interior exposure at these views. Native payload comparisons at 90° and 180° clearly expose the new join and closed raised side. Native 0°/270° are hidden by unchanged building surfaces and have zero pixel difference; they are occlusion controls, not evidence of the repair.

Photo region mean absolute RGB difference is 2.16–2.33/255, with 3.67–3.93% of region pixels changing by more than 20. Close approach regions measure 4.08–4.21/255 and 6.34–6.89%. Clear native detail regions measure 8.11–8.58/255. Difference images identify the removed crossing rails, returning guard, new sloped surface and local floor retile. Live-world differences also contain incidental spirit-light positions/illumination; these are not credited as repair evidence. A pixel difference proves change, not correctness; the visual inspection and physical crossing results establish the reported fix.

## Evidence

- [Photo comparison](diff/P07_platform_0_comparison.png)
- [Close approach comparison](detail-diff/P07_entry_0_comparison.png)
- [Native closed-side comparison](native/diff/detail_90_comparison.png)
- [Original walking failures](walk-current/walking.json)
- [Candidate walking results](live-candidate/walking.json)
- [Pixel metrics](diff/metrics.json), [detail metrics](detail-diff/metrics.json)

Production changes: `PublicRealmSurfacePlan.finish_transition_guards` and its court-entry selection; `WarrenTransitionSurfaceBuilder.build_side_entry`. Reproduction uses `september13_platform_qa.tscn`, `september13_platform_current_probe.gd`, `september13_platform_native.gd` and `test_september13_platform_connection.gd`.
