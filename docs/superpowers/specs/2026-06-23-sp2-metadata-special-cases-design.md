# SP-2: Metadata-ize the live special-cases

**Date:** 2026-06-23
**Status:** Design — part 2 of the terrain simplification (SP-1 dead code → **SP-2 metadata** → SP-3 decompose/simplify).

## Goal

The generic engine — primarily `TerrainGenerator.gd` — must stop naming specific
tags (`"level"`, `"cliff"`, `"ground"`, `"ground-plain"`, `"hill"`) or hardcoding
socket-name lists (`["front","back","left","right","topcenter"]`, `"bottom"`,
`begins_with("top")`). Each policy moves to **metadata authored on `TerrainModule`**;
core code reads the metadata. **Behavior is preserved exactly** (guarded by the
characterization net + full suite).

User guidance honored: no thin wrappers; data-driven rules with no per-tag
branches in core; rewrite for readability.

## Metadata model (new fields on `TerrainModule`, all defaulted)

Set **post-construction** by the builders (not via the positional constructor —
that would force churn across ~30 call sites and read worse). Defaults reproduce
today's behavior, so most factories need no change; only differing modules set a
field.

| Field | Type | Default | Replaces | Set on |
|---|---|---|---|---|
| `is_base_plane` | bool | false | `tags.has("ground")` in `can_place`/`add_piece`/`_drive_heightfield_structure` | ground-plain, water, bank |
| `requires_surface_support` | bool | false | orphan-sweep `tags.has("hill") or displaceable` (the `hill` disjunct) | hills |
| `structural_socket_names` | Array[String] | `[]` | `_is_structural_socket` tag+socket-list | ground-plain, levels, cliff edges, cliff interiors → `["front","back","left","right","topcenter"]` |
| `density_profile` | String | `"macro"` | `_route_fill_prob` family branches | ground-plain → `"gentle"`; levels → `"level"`; rest default `"macro"` |
| `grows_in_cliff_core` | bool | false | `not tags.has("cliff")` in `_route_fill_prob` cliff-core foliage exemption | cliff edges + interiors |
| `vertical_stack_family` | String | `""` | `tags.has("level")` pair in `can_place` level-below-level filter | levels → `"level"` |
| `attachment_socket` | String | `"bottom"` | `"bottom"` literals in adjacency/placement defaults | (default suffices for all) |
| `socket_role` | Dictionary[String,String] | `{}` | `begins_with("top")` elevation inference | surface sockets → `"surface"` (emitted centrally by `surface_spawn_sockets`) |

**Why these carriers:** `structural_socket_names` is a per-module *list* because
the predicate is literally set-membership; `socket_role` is a per-socket dict
because a module has both `"surface"` tops and lateral sides; everything else is
whole-tile policy → per-module scalar.

## Rewrite map (current → metadata)

- **`_is_structural_socket`** → `return socket_name in piece.def.structural_socket_names`.
  (Water/bank keep default `[]` — they carry `"ground"` but not `"ground-plain"`,
  so they are non-structural today; default reproduces this exactly.)
- **`_route_fill_prob`** → keep the foliage `if _socket_can_spawn_point(...)` branch
  and `_in_cliff_core` checks UNCHANGED; replace only the two tag discriminators:
  the cliff-core foliage exemption `not tags.has("cliff")` → `not piece.def.grows_in_cliff_core`;
  the family dispatch → `match piece.def.density_profile { "level": …_level_scaled_fill; "gentle": …_gentle_scaled_fill+core-eager-seed; _: …_macro_scaled_fill }`.
  **Branch ORDER (foliage-first) must be preserved** — level tops are point-spawnable and take the foliage branch before the level branch today.
- **`can_place`** → `(A)` `if new_piece.def.is_base_plane: return true`; `(B)` blocker filter `not p.def.is_base_plane and …`; `(C)` level-below-level filter → `new.def.vertical_stack_family == parent.def.vertical_stack_family and != ""`, inner `p.def.vertical_stack_family == new.def.vertical_stack_family` (keep the `< new_y - 0.1` y-comparison identical).
- **`add_piece`** player-reject + replace-overlap filters, **`_drive_heightfield_structure`** rule-run gate → `is_base_plane` in place of `tags.has("ground")`.
- **`_purge_orphaned_stacks`** sweep → `if not (swept.def.requires_surface_support or swept.def.displaceable): continue`.
- **`get_adjacent_from_size`** → point case key via `Helper.get_attachment_socket_name(orig_piece_socket.socket_name)` (geometry, no literal); ground-special adjacency → `is_base_plane` reads + `orig_piece.def.socket_role.get(name,"") == "surface"` in place of `begins_with("top")`.
- **`surface_spawn_sockets`** (TerrainSpawnConfig) gains a returned `socket_role` sub-dict marking every `top*` socket `"surface"`, so the surface-socket set tracks the foliage-socket set automatically (DRY, one edit).

## Decisions

- **Density curves: keep the variety, dispatch on `density_profile` (behavior-identical).**
  The three curves (`_gentle_/_level_/_macro_scaled_fill`) are distinct tuned
  ecological roles; unifying them is a visible world-shape change with no
  characterization coverage of curve magnitudes. Not unified in SP-2. The math
  helpers stay (they hold tuned constants, not content names — not thin wrappers).
- **Constructor unchanged**; fields set post-construction by name in the builders.
- **`Helper.get_attachment_socket_name` directional mapping and `HeightfieldFacing.OFFSET_TO_SOCKET` stay** — pure geometry, content-neutral.

## Out of scope (kept or deferred)

- **WaterRule** tag triggers `"ground"`/`"water"` — it is a content rule; naming
  its own domain is appropriate. Keep. Its `CARDINAL_SOCKETS`/`DIAGONAL_SOCKETS`
  are geometric socket vocabulary (not tile policy) — flag only; optional SP-3
  consolidation.
- **`HeightfieldInstantiator._lookup_tag` (`"ground"→"ground-plain"`)** — a
  content-layer alias, not core engine; defer to SP-3 with the heightfield/WFC
  content cleanup.

## Incremental tasks (each guarded by the characterization net + full suite)

- **T1 — structural-socket metadata** (low risk): add `structural_socket_names`,
  set on ground/level/cliff, rewrite `_is_structural_socket`.
- **T2 — base-plane + surface-support flags** (low-med): add `is_base_plane`
  (ground/water/bank) + `requires_surface_support` (hills); rewrite `can_place`
  (A)(B), `add_piece`, `_drive_heightfield_structure`, `_purge_orphaned_stacks`.
- **T2b — vertical_stack_family** (low-med): add field on levels; rewrite the
  `can_place` level-below-level filter (subtle — keep the y-comparison exact).
- **T3 — density profile + cliff-core flag** (HIGH risk, silent drift): first add
  a **pinning test** capturing pre-refactor `_route_fill_prob` outputs for a
  ground-topcenter, a level-lateral, and a cliff-lateral at representative
  positions; then add `density_profile`/`grows_in_cliff_core`, rewrite
  `_route_fill_prob` preserving branch order; the pinning test + char Test 4 must
  stay green.
- **T4 — surface-socket role + attachment** (low): extend `surface_spawn_sockets`
  to emit `socket_role`, add `socket_role`/`attachment_socket` fields, rewrite
  `get_adjacent_from_size`'s elevation inference + point-key.

Order: T1 → T2 → T2b → T3 → T4 (least-coupled to most-coupled).

## Risks

- **T3** silent world-shape drift → mitigated by the pinning test + preserved
  branch order.
- **base-plane vs structural confusion**: `is_base_plane` covers ground+water+bank;
  `structural_socket_names` is set on ground-plain only (NOT water/bank). Audit
  both sets explicitly.
- **hill topcenter point-spawnability**: confirm `HILL_*_STACK_SIZE_WEIGHTS`
  behavior is unchanged by the rewrite (the `_socket_can_spawn_point` gate is
  untouched, so it is — but verify the assigned `density_profile` for hills never
  matters because their topcenter is point-spawnable).

## Verification

After each task: `test_terrain_decoration_characterization` + the named guard
suites + (at task end) full GUT suite with scenes restored (baseline 193/193),
then re-delete scenes to preserve the user's working state. No runtime behavior
change anywhere.
