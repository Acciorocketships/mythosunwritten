# GrassField implementation note

**Date:** 2026-07-22
**Branch:** `codex/grass-field`
**Spec:** `docs/superpowers/specs/2026-07-17-grass-field-design.md`

## Landed design

- Audited every file and meaningful embedded variant in the new source folder: eight Maya source/
  clump variants, all eight Collection patches, the scatter component meshes, its unique tuft and
  complete 7,000-placement patch, plus the complete Japanese Maple. The first pass selected Maya
  clump 2. After reviewing the complete lineup, Collection 5 was selected for its fuller, more
  stylized curved-blade silhouette. The scatter source remains a 1,176,000-triangle field of
  duplicated white-material tufts, and the Japanese Maple is a 39,920-triangle tree rather than
  ground cover. Source-specific screenshot harness sheets keep the complete comparison legible.
- Extended `stylized_grass.json` and the normal environment bake with indexed-component ribbon
  simplification. Collection 5 contains 311 disconnected blades, each a regular 20-vertex /
  18-triangle strip. The bake retains root, bend, and tip rows, preserving every blade and its
  authored normals while reducing the patch from 5,598 to 1,244 triangles (77.8%). It moves each
  complete blade 25% radially from the patch centre, then merges, centres, and grounds one
  self-contained collision-free catalogue mesh. UV2 carries each translated ribbon root XZ; the
  311 ribbons resolve to 200 stable root groups, so trampling is local
  to a blade/branch group instead of moving the entire patch. Runtime never touches `assets/Grass/**`.
- Consolidated the runtime to one variant list and one batch per non-empty tile. Random yaw, scale,
  tint, and the 311-blade patch provide variation without multiple warmed assets or a second buffer
  upload. The final seed-v3 17×17 jittered lattice is intentionally much coarser than the former
  tuft grid: Collection 5 bakes to about 3.11 m wide / 1.18 m tall, and its 1.41 m spacing still
  overlaps by more than 2×. This is 289 primary candidates instead of 400 (27.8% fewer), while
  saturated beds remain closed.
- The pure `GrassField` still projects slow biome/canopy/tint fields from a canonical world-aligned
  3 m lattice. Its final 0.20–0.42 carpet curve saturates open marsh and stronger habitat while
  eliminating the long low-occupancy tail that exposed repeated tufts; exact-zero shared clearings
  remain preserved. The field evaluates
  paths, water, grade, and terrain height at each exact jittered anchor. It reuses
  `FieldTerrainStreamer`'s one worker and canonical field/path caches; grass never gates terrain.
- Hill placement now uses the sampled terrain normal as each patch's local up. A separate hashed
  lattice is admitted only by `1 / normal.y - 1`, restoring density in proportion to real hill
  surface area without reshuffling or overfilling flat ground. The former cliff-only taper is now
  one edge rule: ecological grass-bed margins and exposed upper cliff lips uniformly shrink
  patches toward 55% over the final 3 m. Edge tiles alone visit extra deterministic layers admitted
  by `(1 + slope_area_extra) / edge_scale²` at moderate scales, capped at four total layers. The
  cached cliff mask is symmetric for one-sided surface-normal sampling, but its placement response
  is deliberately asymmetric: lower ground keeps the ordinary carpet right into the opaque wall,
  while upper-lip candidates taper and survive only when their final footprint remains on the
  walkable surface. This removes the cliff-wide clearance band without restoring the dark
  slope/cliff knot or permitting overhangs. Exact shared
  occupancy remains authoritative; its 3 m projection only prevents unnecessary supplemental
  work in fully covered interiors.
- Path qualification now tests the selected, randomly scaled Collection 5 footprint at its centre
  and eight perimeter points. The prior reservation-only centre test allowed the patch's broad
  outer blades to cross the rendered corridor even when its anchor was technically outside it.
- `GrassStreamer` keeps the 60 m full-density / 84 m fade / 108 m eviction ring, normalized
  whole-patch dropout ranks, one-buffer atomic tile commits, and conservative deformation bounds.
  Population LOD remains player-anchored. Wind detail now fades by camera distance from 32–48 m,
  stopping screen-distant blades even when an orbit camera is offset from the player. The same
  broad low-pass moves the 82%-up-biased near normal to the terrain sheet's upward normal; retaining
  angled card normals after their shape became unreadable produced a false dark ring at the grass
  population boundary.
- Global ground colour now has one explicit runtime owner:
  `terrain/materials/ground_palette.tres`. The terrain sheet, lips, skirts, cliff dressing, and
  dense-grass shader all bind that resource's one texture object; grass also uses the exact
  lip-top UV rather than a CPU-copied colour from a related asset. Changing the palette texture
  therefore updates all of them together.
- `BiomeRegistry.ground_tint_at` is the matching pure colour-field owner. It combines the existing
  biome multiplier with continuous ±4% value patches at 108 m and ±2.5% warm/cool patches at
  156 m. Terrain, cliff dressing, and grass all call it, allowing subtle intra-biome variation
  without seams or independent grass noise.
- Meadow's ground multiplier changed from `(1.12, 1.06, 0.78)` to `(0.72, 0.66, 1.0)`. The
  shared atlas swatch is already saturated green; removing the above-one boost and restoring some
  blue makes both exposed ground and grass materially darker and less neon without dimming already-dark
  forest/marsh biomes or changing global lighting.
- Collection 5 has no albedo texture; its
  source light/dark structure comes from the bent blade normals. Nearby grass retains 18% of those
  directions under an 82% up-normal bias, then fades to the terrain normal with camera distance;
  the material uses full roughness with zero specular.
  Back-facing ribbon fragments flip into the same lighting hemisphere, removing the dark stipple
  caused by cull-disabled cards. The contact row now returns exactly to the terrain colour, eases
  gradually to a 0.84 shaded body, then reaches a 1.04 tip. A subtle cool-to-warm
  height tint and root-group-stable 0.97–1.03 variation likewise start above that contact row and
  keep blades readable on the brightest meadow ground without a dark bed/terrain seam. Camera
  detail fades both variation and height contrast back to the exact terrain value, so the
  added structure does not restore far-field grain or leave a false dark ring where the finite
  grass population gives way to bare terrain. The former instance-brightness setting is
  removed; local variation is either shared with the ground field or shader-owned above the
  ground-matched contact.
- `TrampleField` still supplies a world-anchored 64 m, 0.25 m/texel visual trail window with
  coalesced uploads. The actor radius is now 1.1 m, moving strength never falls below 0.72, shader
  bend/drop are 1.25/0.95 height ratios, and recovery is 10 s. This makes an actual run leave an
  immediately legible flattened wake across the broad Collection 5 patches. Inspection of the user's four decoded glitch
  frames exposed a real snapshot mismatch: a scroll published its new origin before the shifted
  image reached the GPU, so old pixels moved in world space for a frame. The last-uploaded texture
  and origin now switch atomically. The retired `ambient_grass` dressing set is not restored. Grass
  remains visual-only with no collision, navigation, persistence, or gameplay identity.
- Wind now occupies the requested midpoint between the original aggressive pass and the nearly
  static gentle review: idle bend is 0.055, gust bend 0.27, gust travel 4.2 m/s, and gust scale
  110 m. Idle harmonics are 1.05/1.70 rad/s with 22% secondary amplitude, while a 0.38–0.88 gust
  response keeps the fronts broad rather than abrupt.
- A grass-free control capture showed the remaining distant "grass shadow" on the bare terrain:
  it was the low golden-hour sun's full-opacity cliff shadow, not grass or its LOD. Global sun
  key energy is now 1.1 and shadow opacity is 0.40, retaining character/object grounding while
  preventing long terrain shadows from dividing open meadows into a dark band and a blown-out
  background.

## Performance gate

Measured in the rendered `grass_streaming_qa.tscn` harness on an Apple M1 Pro (10-core CPU,
16-core GPU, 16 GB), seed `2697992464`, player position `(48, 30, -1500)`:

| Metric | Result |
|---|---:|
| Desired grass tiles | 52 |
| Resident batches | 52 |
| Committed / submitted instances | 13,421 / 10,716 |
| Raw MultiMesh buffers | 1,073,680 bytes (1.02 MiB) |
| Grass worker time | 31.016 ms/tile average, 50.671 ms maximum |
| Grass commit time | 0.174 ms maximum |
| Grass LOD update | 0.015 ms maximum |
| Settled process time, grass on | 43.600 ms average, 45.884 ms maximum |
| Settled process time, grass off | 17.363 ms average, 18.998 ms maximum |
| Grass process delta | 26.237 ms average |
| Total scene draw calls, grass on/off | 174 / 149 |
| Total scene primitives, grass on/off | 7,569,634 / 420,494 |

The 0.5 ms individual commit gate passes. Relative to the preceding 20×20 / 8%-spread Collection 5
pass, the final field cuts resident instances and buffer memory by 28.4%, worker average by 22.9%,
and submitted scene primitives by 22.9%. The broad-patch representation remains about 95% below
the former Maya tuft pass in instance count. Collection 5's 1,244-triangle patch still submits more
geometry per instance. The current settled process measurement is 43.6 ms on the named machine;
the project has no explicit target frame budget, so this is recorded rather than presented as a
30 or 60 FPS qualification.

The final visual pass shows closed saturated beds, terrain-matched colour with retained relative
blade shading, exact ecological/path clearings, no obvious tile patches, and no lighting LOD band.
Two settled frames 30 frames apart measured only 0.00832/255 mean maximum-channel change in the
distant `y=260..379` band; 0.00434% of those pixels changed by more than eight levels. The distant
carpet is therefore effectively static while readable near/mid-field wind remains. After the
17×17 reduction, the standalone deterministic field profile measured 36.242 ms for 288 accepted
flat-ground interior patches (down from 39.259 ms / 398 in the preceding pass). Fully covered
interiors retain the primary/slope layer count, empty path contexts short-circuit footprint probes,
and cliff classification is cached by terrain cell. The real streamed average above includes full
shared terrain/water/path qualification.

## Texture-download finding

The separately downloaded `Grass Textures.zip` contains two 2048×2048 RGBA diffuse PNGs. They are
UV atlases made of disconnected blade islands, not coherent cutout cards and not geometry. They
can texture only the missing model whose UVs match those islands; they cannot recreate the grass
shown on the download-page preview by themselves. The download page exposes Japanese Maple model
files beside the grass-texture ZIP, so the listing appears mislabeled or incomplete. The practical
resolution is to request the missing grass GLB/OBJ/FBX from the seller or marketplace support.

## Reproduction

```sh
godot -d --headless --path /Users/ryko/story \
  -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json

godot --path /Users/ryko/story res://tests/harness/grass_streaming_qa.tscn \
  -- --capture /tmp/mythos-grass.png

godot --path /Users/ryko/story res://tests/harness/grass_streaming_qa.tscn \
  -- --capture /tmp/mythos-grass-clip-site.png --clip-site --quick

godot --headless --path /Users/ryko/story \
  -s res://tests/harness/profile_grass_field.gd
```

## Verification

- Grass/streamer/trample focus after the final fringe, mesh-spread, and cliff-boundary pass:
  31/31 tests passed, 389 assertions, clean process exit.
- The preceding whole-feature GUT pass: 451/452 tests passed with 60,176 assertions. The remaining test,
  `test_joined_rivers_touch_higher_priority_water`, is the repository's pre-existing zero-assert
  risky test. GUT reported exit code 0 after 856.876 seconds; Godot then hit the known
  `recursive_mutex lock failed` teardown crash after printing the complete summary.
- The final Collection 5 environment manifest completed successfully; the rebake pruned the
  superseded Maya grass descriptor, mesh, material, texture, and visual from the runtime catalogue.
