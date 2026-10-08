# SDD ledger — plan: docs/superpowers/plans/2026-10-07-town-taste-knobs.md
Start HEAD 0aa74796f
Pre-flight: tasks touch distinct files except T2/T3/T4 (SettlementFabricAssembler) and T1/T2 (court plots) — sequential, interfaces: plot['ring'] (T2) read by T3 deco (props avoid walk strips). T7 depends on all. No conflicts found.
Ruling: carry the two stale-comment minors from the dead-code review (NativeTerrainGrade.gd:213, AGENTS.md outskirts paragraph) into Task 7's commit.
Owner change: lamps fixed dark wood (no knob), Task 5 re-baselines.
Task 1: dispatched (BASE d912cd332, opus)
Task 1: fix round 1 dispatched (FIX_BASE aac9b8435) — lobe pull ineffective at default sizes; near-hard enclosure reject; weak tests
Task 1: fix round 1/5 (3 addressed, 0 open; commits aac9b8435..01241af36)
Task 1: minor (deferred): .tres notes say "last attempts accept regardless" but code uses best fallbacks; fallback keep ordering omits enclosure factor; full-strength test checks count only; pulls barely move 53/103 (few alternative sites).
Task 1: complete (commits d912cd332..01241af36, review clean)
Task 2: dispatched (BASE 01241af36, opus)
Ruling: Task 2 ringless courts — same-level street-facing edges also take lawn, walk kept only at street mouths/entrances and drop/lower edges (owner: "some can have no pathway surrounding them at all") — cost if wrong: streets lose a widened edge; ring_chance knob still allows today's ring.
Task 2: fix round 1 dispatched (FIX_BASE eaf9fea21) — street-edge lawn, final-fabric drop assertion, seed fallback, minors
Ruling: Task 2 raised ringless clearings whose bordering houses rise from below keep walk edges (planting decided before room composition) — moving planting after composition is a larger restructuring, deferred; cost if wrong: raised towns show the no-path look mainly on ground greens.
Task 2: fix round 1/5 (5 addressed, 0 open; commits eaf9fea21..c929ec783)
Task 2: minor (deferred): lawn-edge audit treats any mass at outward floor as safe; 53 grand clearings have 0 lawn edge faces (audit vacuous there).
Task 2: complete (commits 01241af36..c929ec783, review clean)
Task 3: dispatched (BASE c929ec783, opus)
Task 3: minor (deferred): paved/market courts read as storage (stall rarely fits); small greens crowded; lantern post colour handled by Task 5.
Task 3: fix round 1 dispatched (FIX_BASE 4e183ee9e) — collision-aware prop clearance vs walk strips; asset demand check
Task 3: fix round 1/5 (2 addressed, 0 open; commits 4e183ee9e..12a45e8b2); ⚠️ asset demand verified by controller grep (TownGroundDressing).
Task 3: complete (commits c929ec783..12a45e8b2, review clean)
Task 4: dispatched (BASE 12a45e8b2, sonnet)
Task 4: note — strict ground rule removes every evidence-town well (all were on raised plazas); follow-up: make ground wells likelier (owner checkpoint).
Ruling: Task 4 'raised green' = floor > bearing+1 band on more than half its columns (sloped cut/fill ground plazas keep wells) — owner rule is 'wells on the ground'; cost if wrong: an occasional well on a slightly raised terrace. Fix round 1 dispatched (FIX_BASE 2abf0ef30).
Task 4: fix round 1/5 (1 addressed, 0 open; commits 2abf0ef30..42ab16ac3)
Task 4: minor (deferred): baseline diff mixes ms timing churn; wells now appear in 0/68 surveyed towns (follow-up: ground wells likelier).
Task 4: complete (commits 12a45e8b2..42ab16ac3, review clean)
Task 5: dispatched (BASE 42ab16ac3, sonnet)
Task 5: minor (deferred): bake tool .uid not committed (uids gitignored in this repo); catalog index ext_resource order; loose brown test.
Task 5: complete (commits 42ab16ac3..157d03129, review clean)
Task 6: dispatched (BASE 157d03129, opus)
Task 5: REOPENED — regression: test_october3_town_discovery fails, asset suntail.prop.lamp_1.dark_wood.finish_walnut missing (TownFramePalette derives finish variants of the new lamp role). Fix dispatched to Task 5 implementer (FIX_BASE 799c599fb).
Task 6: fix round 1 dispatched (FIX_BASE 799c599fb) — suburb clearance ring (refuse cottage, never the town), combined-override test + sweep, optional-bridge roof clash release if local, minors
Ruling: lamp-fix commit 52cac694c swept in Task 6 in-progress files (git add of whole tree); not reverted (non-destructive) — Task 6 implementer told to remove _t6_* throwaways in its commit and note the split. Cost if wrong: mixed history only.
Task 5: regression fix round (52cac694c) reviewed clean; Task 5 complete again.
Task 6: fix round 1/5 (3 addressed, 0 open; commits 799c599fb..3b775ca81, part in 52cac694c)
Ruling: Task 6 cottage placement too far (1.7–3.1r) treated as Important (owner intent is the knob's purpose) — fix round 2: 1-col ring vs built columns only, tangential search, cap 1.6r. Cost if wrong: cottages may crowd the core edge.
Task 6: fix round 2 dispatched (FIX_BASE 3b775ca81)
Task 6: fix round 2/5 (1 addressed, 0 open; commits 3b775ca81..ea4725fb9)
Task 6: minor (deferred): some towns keep only 1-2 of 4 suburb cottages; several cottages saturate at the 1.6r cap; combined audit gable_contacts dropped sharply (layout change, intrusions 0) — check in final review.
Task 6: complete (commits 157d03129..ea4725fb9, review clean)
Task 7: dispatched (BASE ea4725fb9, sonnet)
Task 7: fix round 1 dispatched (FIX_BASE 197c53aa3) — photo-town possible rejection bisect/fix, PublicWalkAudit regression test, result.md accuracy, test pins
Task 7: fix round 1 done (53f444e92) — PublicWalkAudit tests, result.md, test pins. Photo towns build; seed 141 failed before this plan.
Ruling: seed 1/grand returning null under the new defaults (a core wall-room trips the existing setback-roof gate) is recorded as a known limit, not fixed in this plan — no optional taste piece is being rejected; the failure rate is the same 1/64 on both old and new defaults (it moves from seed 141 to seed 1) — cost if wrong: one more seed with no town until the roof-gate follow-up lands.
Task 7: re-review APPROVED (53f444e92). Parked minors: test_old_knob_values_have_no_footways name vs. body (builds shipped table); test_corpus_has_no_pathways_to_nowhere red on 1/grand per ruling, not marked pending.
Task 7: complete
Final review: With fixes — Important: rebake undoes dark lamp; no real old-look pin; pulls may cut built clearings. Fix wave dispatched (base 53f444e92).
Final fix wave (378fb497c, e44ad58a2): re-review APPROVED. Plan complete.
