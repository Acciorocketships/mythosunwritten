# Water as a Continuous Substance — round-3 redesign spec

**Date:** 2026-07-10 · **Branch:** feat/water-overhaul · **Pinned review seed:** 2697992464
**Owner directive (verbatim intent):** remove the white moving-water texture and start from scratch — motion must come from waves, not from colouring water white; nothing may be per-cell; the marching-squares method is removed entirely; rivers are continuous smooth streams downhill with no angles; the water should feel like a substance/simulation (the pre-refactor "amorphous blob" quality), matching the Sea of Solitude reference (very clear water). This is the single most important part of the update. Foam policy decided: **zero white anywhere**. Reflections decided: **fresnel + sky + sun only** (no scene mirroring).

## Owner-annotated issues this spec must kill (exact F3 frames)

- **R3-A "edge artifact, obvious with motion"** — flood-plain shore, player (68.3, 4.0, -1172.4), crosshair (68.3, 4.2, -1172.0), cell (3,-49). A wavy angular band tracks the waterline and moves. Diagnosis: the swell-damping seam — surface bobs except where per-vertex baked shore attributes pin it; the moving/pinned boundary is a 3 m-grid polyline. (A second note in this annotation was cut off; owner says ignore it.)
- **R3-B "ghost of the character's hat in the water — wrong side for a reflection"** — player (80.7, 4.0, -1177.7), crosshair (80.3, 4.2, -1177.8), cell (3,-49). Two candidate mechanisms, discriminating experiment below.
- **R3-C "sharp corners from the marching squares" + "sharp edges from the moving water texture"** — falls site, player (34.4, 8.0, -1107.1), crosshair (34.3, 8.2, -1107.4), cell (1,-46). Waterline is a segmented polyline; the white steep wash starts/stops along polygon boundaries (per-vertex baked steep attr).
- **R3-D (quality, not a bug):** the owner LIKED the pre-refactor curved shore film ("amorphous blob… like a simulation") — the new design must provide that quality deliberately.

## What stays (verified in run 2, untouched)

- WaterPlan / RiverTrace / PondStamp / carving — unchanged.
- **WaterField in full**: hydrostatic lattice fill (lakes level, water never above source, no holes), continuous monotone terrain-hugging profiles (pure function of (trace, plan) since C1), `steep_spans` from rendered terrain, `level_at`/`wet`/`flow_at`/`grade_at`. All field oracles keep running unchanged.
- Falls remain ordinary steep surface — no fall objects.
- The falsification review protocol (test + visual, prove-the-issue-still-exists, owner's exact frames).

## What is deleted

- WaterMesher's marching-squares extraction, the 3 m contour polylines, multi-pass cell walk, and the **cell-topology-derived look attributes** (the quantized shore/steep bakes, whose per-cell provenance is what produced texture edges along polygon boundaries). The new mesh still carries per-vertex data — but only continuous samples of continuous fields (see Flow frame), which by construction cannot introduce cell edges.
- The white steep wash, streak scroll, plunge whitening, and `water_foam_mask` — **all albedo whitening, everywhere**.
- Swim-volume *math*: `surface_c`/`surface_g` plane metas and plane extrapolation (root of the I4 misclassification and of two documented limitations — plane divergence and dual-level cells). Cell boxes survive only as broad-phase triggers.

## Architecture: field for WHERE, curves for SHAPE, trace for FLOW

Three focused units replace the mesher (WaterSurfaceBuilder stays the thin adapter wiring them):

### 1. WaterContour.gd (new, pure)
`curves(ctx, rect) -> Array[Curve]` — traces the waterline (zero level−ground crossing) and returns smooth curves.
- Presence sampled on a 3 m grid; crossings refined at 1.5 m; segments chained into closed/open polylines.
- Smoothing: two Chaikin passes + resample at ~1.5 m spacing → G1 curves, no corners. Walls need no special casing: the waterline along a wall base is straight and stays straight; wall-corner rounding (≤ ~0.8 m) is acceptable.
- **Chunk seams:** trace in the chunk rect grown by 12 m so smoothing sees identical neighbourhoods from both sides, then clip to the chunk; sampling is world-grid-aligned and the field is deterministic, so neighbouring chunks compute bit-identical border points. Pinned by a border oracle (below).
- Curve points carry: position, tangent, outward normal, local ground slope (wall flag), water level.

### 2. WaterSkin.gd (new; replaces WaterMesher)
`build(water, chunk, region) -> {mesh arrays, triggers}` — the visible surface from curves + field.
- **Interior:** ~3 m lattice riding `level_at` (density required for wave displacement), clipped to the curves; conforming boundary strip stitches lattice to curve (watertight, welded indices, no T-junctions).
- **Meniscus rim (the blob):** a band swept along each curve — from ~0.6 m inside the waterline the surface bulges and curls down ~0.35 m, its outer row diving 0.3 m below ground (sealing; replaces the hem). Rounded rim normals catch fresnel → the soft bright waterline edge of the reference, from geometry not paint. The rim displaces with the body under waves — nothing is pinned.
- **Flow frame:** every river vertex gets CUSTOM0 = (s, d, slope, shore_dist): s = arc length along the nearest trace, d = signed cross-channel distance, slope = continuous profile slope at s, shore_dist = distance to nearest curve. Ponds: slope 0, s unused (isotropic swells). Junction blending: nearest-trace wins with a short 1/d² blend zone (affects wave direction only).
- Invariant preserved: the only free edges are the rim's buried outer row (and true chunk borders).
- **Triggers:** coarse box volumes over wet coverage as today (top level+1.7, bottom gnd_lo−5), but their only meta is a `WaterSampler` handle — a RefCounted wrapping the chunk's frozen field data with `level_at(xz)` (read-only after build; thread-safe by construction). Swell height is NOT in the sampler: the character keeps its own CPU swell mirror as the single source of that truth, exactly as today.

### 3. water_unified.gdshader (rebuilt look, same file)
- **Motion = waves.** Ponds/lakes: the existing approved travelling swell spectrum, unchanged (CPU mirror intact). Rivers: travelling wave trains advected along s — wavelength shortens and amplitude grows continuously with slope (A ≈ base·(1+k_slope·slope)·depth_ramp·shore_fade); steep reaches add a second, slightly crossed faster train (rushing look). At `steep_spans` base lines: expanding geometric rings + churned normals, fading over ~4 m. Fine scale: advected normal ripples in (s, d) coordinates. Shore damping = smoothstep on shore_dist — continuous, no band edge.
- **Zero white:** no foam mask, no steep wash, no plunge whitening. Moving water reads from geometry + specular response only.
- **Clarity (Sea of Solitude):** body_floor ≈ 0.12 (from 0.22), clarity_depth ≈ 12 (from 6.5), shallow tint ≤ 0.10, refraction_strength ≈ 0.11 (after R3-B fix), pastel deep tint kept, fresnel + sky + sun sheen (roughness ≈ 0.12). Exact values are tune-at-battery-frames; the spec pins the direction and rough magnitudes.
- All wave constants live in one gdshaderinc consumed by the shader AND mirrored in character.gd (existing constants-sync discipline).

## The two annotated bugs

- **R3-B ghost hat — discriminating experiment first:** at the exact frame, toggle the character's `cast_shadow` off for one capture. Ghost gone ⇒ it is the sun shadow projected onto the water (matches "wrong side"); fix = disable shadow reception on the water material (`render_mode shadows_disabled`) — the reference look carries no crisp object shadows on water; depth tint keeps the surface grounded. Ghost persists ⇒ it is the screen-space refraction grabbing character pixels; fix = harden the sample guard (reject above-surface samples outright, widen the near-geometry margin, and verify at grazing angles). Either way: verified falsification-first at the exact frame.
- **R3-A shore crease — killed structurally:** no pinned shore band exists (rim rides the swells; damping is continuous in shore_dist). Verified at the exact frame **with a motion check**: two captures ~0.7 s apart, pixel-diffed along the waterline band — the artifact class shows as a coherent moving edge in the diff; absence = pass.

## Swim/wading classification

On trigger overlap, the character samples `WaterSampler.level_at(xz)` + the CPU swell mirror and applies the existing hysteresis (0.8/0.6 swim, 0.05/0.03 wading; wading ⊇ swimming). Plane metas deleted. This closes the two run-2 documented limitations (plane extrapolation near kinks; dual-level cells — the field is single-valued and exact at any xz).

## Verification

- **Field oracles:** unchanged (they never touched the mesh).
- **New oracles (red-first where an artifact class exists to pin):** `test_border_curves_weld` (bit-equality of border curve points across neighbouring chunks, 2 seeds); `test_curve_is_smooth` (max segment turn angle below threshold except at wall-flagged points — this one lands RED against a marching-squares-derived polyline baseline to prove it measures the artifact, then GREEN with curves); `test_no_free_edges_except_buried_rim` (ported invariant); `test_classification_parity` (field depth class == character math at sampled wet/dry/boundary points).
- **Battery grows to 19 frames:** all 16 existing + R3-A/B/C frames above (added to review_vantages.json). Steep/shore frames additionally get the motion-pair diff. Binding rule unchanged: each frame is reviewed to PROVE the annotated issue is still present; only failing to find it counts as fixed.
- **Performance budget:** contour + skin per chunk ≤ 1.5× the old mesher's build time (measured and reported; the fill's ~9 ms budget is untouched).
- **Look acceptance:** the owner judges the substance/clarity feel against the reference at the battery frames — the spec's success criterion for R3-D is his review, not a metric.

## Explicitly out of scope

Scene-mirroring reflections (decided against), gameplay water physics changes (current push/buoyancy untouched), performance work beyond the stated budget, and the deferred run-2 follow-ups (lock-hold comment, water_qa OUT path, dead WaterTile scene) which remain tracked in the ledger.
