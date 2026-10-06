# October 3 acceptance audit — incomplete

The completed isolated October suite tests the current integrated changes. It is
not the full repository suite and cannot certify visual quality or performance.
`state.json` and individual logs record its progress; `source-manifest.json`
identifies the dirty source under test.

| Requirement | Available evidence | Remaining acceptance |
|---|---|---|
| Roof/walk clearance, complete roof ends | Finished-triangle roof-air suite; contact/dormer/eave tests; recent native junction views | Final full-repository regression comparison and fresh production-player/streamed checks after latest changes |
| Deep facades and native mixed building grammar | Source prefab/module studies, actual recessed/high window panels, bays, native trim, cross-gables and turrets | Broad player-height holdout review; high-window and dressing improvements do not establish all facades match the reference |
| Clearings, massifs, useful direct routes | Central-ground source domain; 60 source cases, 104 cottages; 17/large approach length reduction and 10 player routes | Wider integrated route/terrain checks with current instance placement |
| Skywalks/underpasses | Supported bridge reservations and actual-player routes; bridge and tunnel suites | Refresh distribution and production route evidence after current layout/geometry changes |
| Optional inhabited fortified tiers | Seeded absent/one/multiple tiers, wall-room/tunnel/gate suites; prior native and player reviews | Confirm current broad corpus retains crossings and connected populated rings; inspect remaining broad masonry faces |
| Ground/trees/activity groups | Native urban and wooded reviews; current complete-payload dressing tests; 44 trees retained in wooded example | Latest changes need production grass/terrain/streaming observation; flat preview ground cannot prove this |
| Mixed-kit alignment | Both native kits, measured roof junctions and complete assemblies, current native-roof regression | Independent holdouts, build-order determinism and full suite comparison |
| Performance and streaming | Prior quiet 6.735 s solve against8 s gate; prior9-chunk render and eviction/reentry | All predate recent changes. Fresh quiet solve; representative render/memory measurements; actual eviction/reentry |
| Procedural generation | Seeded streams and geometry-dependent rules; inspected code has no reported world/city seed special case | Search is limited evidence; inspect changed production code together with deterministic rebuild results |

The terminal-contact coverage gap is now repaired with the exact native recipe
poses from the original defect, exercising both failure without the proved
relationship and successful atomic admission with it. The current generated
9/grand remains separately covered as a whole town. No production tolerance was
changed to make the test pass.

The47 October files pass after three documented test-expectation repairs.
A fresh quiet production solve passes149 assertions in6.219 s (8 s ceiling);
the two build-order tests also pass. Original failing logs and repaired reruns
are retained. The streamed-player/reentry harness completed successfully:9/9 walks,
confirmed eviction, replacement and reentry,712.261 s. Evidence:
`../october3-world-walk/walk.json`. This precedes the subsequent attic-window
change, covered separately by native closure/public-air checks.

Next sequence: finish refreshed streamed
visual/traversal/reentry evidence; finish baseline regression and representative
art/performance acceptance. The goal remains active.
