# Suntail building kit: implementation plan

Spec: `docs/superpowers/specs/2026-09-24-suntail-building-kit-design.md`.
Worktree `/Users/ryko/story-suntail`, branch `suntail-towns`.

## Phase A: kit foundation (done)

1. Bake the Suntail pack into the catalog: `tools/environment_bake/manifests/suntail_village_kit.json`
   (136 assets, `building_trimesh` collision on structure, a manifest
   `material_palette` restoring vendor tints and `material_roughness` removing
   converter mirror finishes).
2. `BuildingKit` (roles + native metric) and `SuntailBuildingKit`.
3. `BuildingMass` IR and `BuildingKitAssembler`: walls on cell-edge slots,
   half-module jetty insets with brackets and floor beams, plinths, soffits,
   gable stacks, eave/slope/top roof rows, dormers, barge boards, ridges,
   pent eaves, decks with rails, posts, dressing.
4. Gallery harness `tests/harness/suntail/building_gallery.gd`; the House_1
   replica matches the prefab (pinned by `tests/test_building_kit.gd`).

## Phase B: village integration (done, iterating)

1. `KitVillageBuildings`: houses from planner lineages (`...partNN` merged) and
   prefab-landmark reservations; balconies, overhang supports, skywalks,
   retained-terrace skin as kit masses; legacy units, fabric families and
   terrace families withdrawn.
2. `BuildingDesigner`: materials, jetties, bays, finishes, pent eaves, roofs
   with clearance fallback to terraces, dormers, dressing.
3. Kit-derived anisotropic world frame (`VillageWorldScale`), vertical call
   sites, inverse-transpose normals, rigid compensation.
4. `KitSubstitution`: remaining legacy public pieces redrawn by measured
   bounds; props (stalls, lamps, crates...) swapped to Suntail props.
5. Hamlet lots: `KitStandaloneHouse`.
6. Program vocabulary includes the kit assets.

## Phase C: falsification review (ongoing)

Loops:
- Flat-ground town battery: `tests/harness/suntail/kit_town_review.gd --cities
  seed:profile,...` (seconds per town; orbit, top, street views).
- Live streamed world: `tests/harness/village_site_capture.tscn -- --seed S
  --at x,y,z --orbit R,H --ground-ring R` (several minutes per site).

Backlog (each item: reproduce in a view, fix, re-render the same view):
- Stacked-house blocks in large towns read as one slab (pent eaves and finish
  tints added; still check).
- Roof wings of neighbouring houses interpenetrate; cornices poke into taller
  neighbours.
- Door dressing: wall lanterns, entry steps where the door is above ground.
- Chimneys composed from stone courses.
- Street dressing with Suntail props (barrels, crates, carts, lamps, fences).
- Legacy stairs/plank shaders coloured to Suntail timber.
- Update tests that pin legacy building art; update AGENTS.md.
