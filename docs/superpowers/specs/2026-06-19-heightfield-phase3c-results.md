# Heightfield Terrain — Phase 3c Results & Remaining Cutover Work

Status of the live cutover (`use_heightfield`, default **off**) after Phase 3c Tasks 1–3 + visual validation.

## What works (validated)

- **Structural placement from the plan, wired into the live loop** behind `use_heightfield`. Tasks 1–3 implemented + spec/quality reviewed; full suite **212/212 with the flag off** (shipping path unchanged).
- **Deterministic + idempotent**: `place_region` places each cell once; eviction now *removes* distant tiles (no double-placement on return). The start-tile/origin overlap is gone (start tile skipped when the flag is on). Determinism/no-churn is proven by the unit/integration tests (the plan is a pure function of position; tiles are never retiled).
- **Visual acceptance (screenshots):** with the flag on and the player parked in a feature-rich region, the plan renders a coherent **terraced/layered landscape** — multiple 0.5m terrace tiers and 4m cliff steps, **grid-aligned with no vertical gaps**, walls facing the drops correctly (asset-grounded facing from Phase 3b), and **decorations (trees) still spawn** via the queue. Tuning `HeightfieldPlan` amplitude/max_storeys changes the height range as expected; the clamp turns steep height into staircases (by design — sheer tall mountains need a steeper source field, a tuning knob).
- Harness: `tests/harness/heightfield_shot.{gd,tscn}` renders and saves a screenshot for inspection.

## Remaining work for a full production cutover (follow-ups)

These were surfaced during Phase 3c integration/visual analysis. None affect the flag-off shipping path.

1. **Water/banks do not yet appear with the flag on.** `drive_heightfield_structure` registers plan tiles but does not run the rule pipeline, so `WaterRule` never fires on them. Options: run `WaterRule` (or a water check) on placed ground tiles, or have the plan place water/bank tiles directly from `Helper.is_water`. (Design choice — worth a brief decision.)
2. **Emergent ground-lateral expansion still runs alongside the plan.** `_is_structural_socket` deliberately leaves ground cardinal laterals live, so the base plane can both be placed by the plan *and* grow emergently — redundant and a mild double-placement risk at the place-region edge. Decide: suppress ground laterals when the flag is on (plan is the sole base source, world extends via the moving place region) — likely the right call.
3. **Performance / batching.** The per-cell reference `surface_height`/`storey_at`/`level_at` build large windows; `place_region` at radius 6–8 every frame is slow (first-frame hitch of seconds). For playable live use, batch the storey/level fields once per chunk instead of per cell. (Flagged since Phases 1–2 as deferred.)
4. **Place-radius vs RENDER_RANGE/REVEAL_MARGIN reconciliation** and a **burst-harness churn run** (`burst_harness` with the flag on) to record structural churn = 0 quantitatively.

- **Water on elevated terrain is deferred.** WaterRule now restores water/banks on flat (storey-0) heightfield ground tiles. Where the (independent) water field overlaps high terrain, the heightfield currently places land (cliff/level), not water — matching "water in low areas" rather than the old generator's water-takes-precedence. Full water-vs-height integration (force water cells low + bank drops, without breaking the 0/0.5/4 gap invariant) is a follow-up.

## Recommendation

The structural redesign is proven end-to-end behind the flag. The remaining items are a focused follow-up phase (call it 3d): water integration + ground-lateral reconciliation + batching, then flip `use_heightfield` on by default and re-run the churn harness + screenshots as the final acceptance.
