# Mythos loading screen

`mythos_loading_screen.tscn` is the project's startup scene. It requests
`scenes/world.tscn` through Godot's threaded resource loader, polls progress
without blocking the main loop, then installs the loaded world behind a
high-layer overlay. The overlay remains until `FieldTerrainStreamer` reports
that every terrain chunk beneath the player's startup footprint is integrated.
At the origin corner that support set is exactly `(-1,-1)`, `(-1,0)`, `(0,-1)`,
and `(0,0)`.

The bottom hairline is `MythosTaperedProgressBar`, not a timer. Three percent is
Godot's threaded scene-resource load. The remaining range combines measured
worker milestones for PathContext/features, heightfield, meshing, water, and
dressing across the four startup support jobs and their required feature halo,
then the actual main-thread integration fraction. The streamer prioritizes that
support work ahead of its normal outward radius. The bar's small `preview` cycle
exists only in the screenshot harness and is disabled in production.

The original atlas is paired with `mythos_mythic_atlas_background_cloudless.png`,
a genuinely cloud-free parchment plate with the foreground illustration removed.
The earlier plate retained stationary corner clouds and must not be used behind
the moving layer. Dedicated transparent textures under `layers/` contain the
cities, clouds, and celestial chart:

- four cloud banks drift independently using translation only (never rotation);
- the left and right settlements move on separate slow parallax paths;
- the stationary river is the original atlas painting; a second sample of those
  exact pixels scrolls downstream along a hand-fitted centreline for most of a
  cycle, cross-fading only at wrap, and is clipped to the river's local width;
- only `layers/chart.png` rotates, carrying its constellations with it;
- the parchment plate, title, and separate progress Control never rotate.

The ShaderMaterial parameters on the scene are the art-direction controls. The
cloud/city parallax, localized river flow, and chart rotation are deliberately
readable over the multi-chunk startup wait.

To preview and validate the GPU motion without entering the game, run:

```sh
godot --path /Users/ryko/story res://tests/harness/loading_screen_preview.tscn
```

The harness compares two rendered frames and writes the later one to
`user://mythos_loading_screen_preview.png`.

The real-world startup handoff (including monotonic measured progress during
worker planning and automatic dismissal without player input) is covered by:

```sh
godot --headless --path /Users/ryko/story \
  res://tests/harness/loading_world_startup.tscn
```
