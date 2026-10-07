# October 6 tree review (seed 2697992464)

Owner report: painted trees neon, two-tone/white leaves, glossy trunks, stump
recoloured, sparse "parkland" placement, no trees on slopes. Owner kept the
denser forest and asked for leaf LODs rather than cutting density.

## Changes
- Leaves: `painted_leaf.gdshader` (radial normals on both faces, crown
  interior/underside shading from bake-written crown bounds, desaturated vendor
  tint, tint noise, translucency). Wood: `roughness_floor` 0.85. Stumps/logs:
  pack colour (`identity` tint).
- Placement (`ambient_tree.tres`): spacing = crown radius, deep_forest fill
  1.15 -> 4.0, scale 1.0-1.3, max_grade 0.8. 3x3 chunks round the photos:
  217 -> 859 trees.
- Leaf LODs: card-thinned 1/2, 1/4, 1/8 index LODs, shader shrink/grow (dolly
  15-300 m: no steps, coverage within ~10%); 48 m tree/bush batches.
- Shadows: baked shadow-only proxy; cards in sun cascades <= 30 m wide, dappled
  crown ellipsoid beyond.

## Frame time (profile_chunk_commit photo poses, ms, machine under other load)
| pose | old density | dense, no LODs* | final |
|---|---|---|---|
| photo 3 (forest) | 27.0 | ~56 | 34.3 |
| photo 1 | 21.1 | ~38 | 29.9 |
| mountain | 18.6 | ~43 | 29.6 |
| photo 2 | 24.9 | ~33 | 31.2 |
| overhead | 28.9 | ~41 | 41.1 |

*all-cascade leaf-card shadows, same load. Stress grove (400 oaks): card
shadows 92 ms, hybrid 33.5, none 14.9; ground brightness hybrid 108 vs cards 107.

Images (git-ignored JPGs beside this file): `leaves_*`, `world_*` (density
before/after), `lod_*` (old density vs final), `shadow_cards_vs_hybrid.jpg`.

## Tests
catalog 24/24, commit queue 7/7, dressing field 6/6, ecology 7/7 (stale LPFV
reference repointed), biomes 7/7, atmosphere director 5/5, collision builder 3/3.
`test_field_streamer` 16/17: the 60 s cold-chunk deadline (baseline failure).
