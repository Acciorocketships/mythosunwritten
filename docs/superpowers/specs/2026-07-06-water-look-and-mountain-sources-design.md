# Water Look & Mountain Sources — Design

Date: 2026-07-06
Owner request (verbatim intent):
1. Water animation looks like it is running in **fast forward** — restore normal
   ripple speed. The earlier "make rivers faster" request was about the *moving
   river water*, not the global animation rate.
2. Rivers should be **faster and rougher** via real **choppy waves** (geometry,
   not just a foam texture), while the water itself stays **clear**.
3. Make the water **look nicer and clearer**, matching the supplied reference
   image (bright clean teal, glassy reflections, visible-but-tinted background).
4. **Rivers start on mountains/hills** — source pools at the top; rivers may
   still cross flat ground on the way down.
5. Work happens in a separate worktree.

## Root cause of the fast-forward look

Commit `a27bd4d` implemented "faster water" as `flow_speed 3 → 6` in
`terrain/water/water_unified.gdshader`. That uniform scrolls the detail-noise
texture that *is* the visible ripple pattern on all flowing water, so doubling
it doubled the apparent playback rate of the ripples — a video-speedup effect,
not a faster-river effect. Still-water swell (`wave_speed`) never changed.

## Approaches considered

- **A. Just revert `flow_speed` to 3.** Fixes the regression, delivers nothing
  on "faster, rougher rivers".
- **B. Revert the base rate; make speed a *local* property (scale scroll by
  steepness); sell speed with advected geometric chop + flow-stretched detail;
  add screen-texture refraction for clarity.** Moderate shader work, no mesh or
  builder changes (flow + steepness already ride CUSTOM0). **Chosen.**
- **C. Full Gerstner wave stack + planar reflections.** Real waves and real
  building reflections like the reference, but planar reflection needs an extra
  render pass and Gerstner horizontal displacement fights the shore-dip
  waterline trick (edges must stay buried in the banks). Overkill for the
  stylized target.

## Design

### 1. Animation speed (fix + faster rivers done right)

- `flow_speed` default back to **3.0** — the pre-regression baseline for calm
  reaches.
- Effective scroll velocity becomes `flow_speed * (1.0 + rapids_boost *
  steep_v)` (`rapids_boost` ≈ 1.5): gentle reaches read exactly as before;
  steep reaches genuinely race. Speed is now *where the river is steep*
  instead of a global playback knob.
- The dual-phase dithered scroll mechanism stays as-is (it exists to hide
  phase-reset pulses).

### 2. Choppy waves (geometry, clear water)

In `vertex()`, on top of the existing still-water swell:

- A **chop term**: two short-wavelength directional wave trains travelling
  along the per-vertex flow direction at the effective scroll speed, crest-
  sharpened (`1 - |sin|`-style, not smooth sine), broken up by the noise
  texture so crests never read as bars.
- Amplitude = `chop_height * fs * (0.4 + 0.6 * steep_v)` — proportional to
  flow strength `fs`, boosted on rapids. Because the builder already fades
  flow to zero at channel edges/rims, chop dies out exactly at the shoreline,
  so the shore-dip waterline (edges buried in the banks) is untouched.
- The vertex normal is finite-differenced from the *combined* height function
  (swell + chop) so the chop is lit as real geometry.
- Rivers currently *suppress* swell (`amp *= 1 - 0.7*fs`); that stays — chop
  replaces swell in rivers rather than stacking on it.

In `fragment()`: detail noise for flowing water samples in a flow-aligned
basis, stretched along-flow and compressed across-flow as `fs` rises —
ripples elongate into streaks, the classic fast-water read. Foam logic keeps
the existing noise-gated rapids streaks (`steep_v`-driven); no flat foam adds.

### 3. Clear, nicer water (reference look)

The current body is milky: flat `ALPHA` 0.82–0.96 over a pale sage blend.
Replace opacity-as-color with **screen-texture refraction**:

- `hint_screen_texture` sample offset by the surface normal (view-oriented),
  offset magnitude fading in over the first metre of depth (shores don't
  smear), with a depth re-check at the offset UV falling back to the straight
  sample when the offset lands on geometry in front of the water.
- Body color = refracted scene tinted by a depth ramp (Beer-Lambert-style
  exponential toward `color_deep`): shallow water is visibly *through* to the
  bottom, deep water saturates to a rich teal. Palette shifts from pastel sage
  to the reference's cleaner teal-green (tuned live against screenshots).
- **Fresnel** blends toward the reflective deep color at glancing angles;
  `ROUGHNESS` drops to ~0.03 (crisp sun glints + sky reflection), `SPECULAR`
  up. Building-mirror reflections from the reference are explicitly out of
  scope (planar reflections need a second render pass).
- `ALPHA = 1.0` (written, keeping the material in the transparent pass —
  required for the screen texture); clarity now comes from refraction, not
  alpha blending. Foam stays opaque. `depth_draw_always` and the depth-buffer
  waterline mechanism are unchanged.

### 4. Mountain-top sources

`WaterPlan.has_source`/`source_pos` today: jittered candidate in the
super-cell must sit on `smooth01 ≥ 0.55` ground **with local slope** —
headwaters on hillsides. Change to **summit-seeking**:

- **Gradient-ascend** the jittered candidate on the smooth field
  (`ASCEND_STEP = 12`, max `ASCEND_MAX_STEPS = 40` ⇒ ≤ 480 m travel),
  stopping when `|grad| < ASCEND_FLAT_EPS` (converged on a local peak).
- A cell fires only when the ascent **converges**, the peak keeps
  `smooth01 ≥ SOURCE_MIN01`, sits outside the spawn ring, and passes a
  **prominence gate**: mean `|grad|` over 8 ring samples (radius 48 m) around
  the peak ≥ threshold — real hills/mountains qualify, flat plateaus don't
  (replaces `SOURCE_MIN_SLOPE`, which is *anti*-summit: gradient is zero at
  the top).
- Source pool (`SOURCE_POOL_R`) sits at the ascended peak — a spring pond at
  the summit; the existing `_pond_level` min-over-footprint clamp nestles it
  into the summit rather than floating it.
- **Anti-churn**: ascent is a pure function of (seed, cell); the ascended
  position is instance-cached like traces. `REACH` grows by the max ascent
  distance (480 m) so bounded-window guarantees hold (`REACH_SUPERS` 4 → 5).
- Density: retune `SOURCE_MIN01`/`SOURCE_PROB` so seed 991177 keeps a similar
  source count to today (ascent makes the height gate easier, prominence gate
  removes plateau sources).

### Tests

- `test_water_plan.gd`: replace the hillside test with peak invariants
  (near-zero gradient at every source, prominence ≥ threshold, height floor);
  determinism/purity tests stay and must keep passing; density guard
  (≥ 1 source in the 13×13 window) stays.
- Shader changes are visual: verified by compile-clean project run + in-game
  screenshots against the reference (river reach, rapids, lake, shoreline),
  plus the existing water surface-builder tests proving no regression in the
  mesh/flow data the shader consumes.

### Out of scope

- Planar/SSR building reflections; ripple-sim changes (`WaterRippleSim`
  cadence/strength untouched — it predates the regression); river network
  topology beyond source placement; underwater rendering changes.
