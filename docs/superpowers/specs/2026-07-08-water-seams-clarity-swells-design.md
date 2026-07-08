# Water: seams, clarity, swells, and swim-detection — design

**Date:** 2026-07-08 · **Branch:** `feat/water-overhaul` · **Seed:** 2697992464 (pinned)

Round-5 review: five persistent complaints (annotated screenshots dated 7/03–7/05, i.e.
pre-pass-19/20/21; every complaint re-verified at HEAD `f89bf07` before designing — see
Evidence). Sites: V1 `(34.4, 8, -1103.4)` cell (1,-46); V2 `(135, 4, -1159.6)` cell
(6,-48); V3 `(49.3, 7, -1110.6)` cell (2,-46). All on one cascade: falls at
`(48,-1092)` 9→5 and `(48,-1068)` 15→9, level-3 flood plain north-west.

## Evidence at HEAD (before-shots in scratchpad: `before_v1/v2/v3`, `before_v1_nofalls`)

| # | Complaint | At HEAD | Root cause (confirmed) |
|---|---|---|---|
| 1 | "water skirt detached" | pale wedges/lines persist | Contour-cap dive band is painted PALE across its whole width: foam `lap` is keyed on vertical depth (≈0 over the entire diving band, not just at the line) and gate opens at shore 0.45; band reads as a separate hovering shelf. NOT the fall slab (persists with `Waterfalls` hidden). |
| 2 | clear + distortion | milky, zero visible distortion | Refraction offset is constant in screen space (huge world-space smear far away, invisible variation near); offset normal is the swell normal, which is ~flat (λ 110–163 m); binary guard fallback puts a hard boundary at shores ("lensing"). |
| 3 | swells / bumpy dynamic water | glass-flat | All swell wavelengths are 76–163 m — unreadable as waves inside a ~60 m view; they render as a slow tilt. No mid-scale energy. |
| 4 | char floats beside falls | **both directions broken**: teleported char read `in_water=true, wsy=9.55` mid-air, then sank to y=1.7 in the level-5 pool with `in_water=false` | `_river_volumes` boxes span `VOLUME_STRIDE=4` samples straight across cascades: box [4..8] covers y∈[6.5,9] over the level-5 pool with `surface_y=maxf(prof[i],prof[j])=9`. Phantom volume in the air at the crest; no volume hugging the pool (prof-5 lives at samples 5–6, mid-stride). BUOYANCY 17 < g 18 ⇒ inside the phantom box the char sinks at ~1 m/s² = "hovers". |
| 5 | fall visually discontinuous | white opaque curtain vs still teal sheet | `waterfall.gdshader` foam floor 0.42 (+0.55·band +0.35·ends) ⇒ mostly white everywhere incl. crest; crest `ends` whitening draws the hairline; translucent-white side walls read as detached glass wings. |

## Approaches considered

**A. Keep whack-a-mole tuning** (adjust cap slopes, foam widths, alpha). Rejected: 21
passes of history show the three seam systems (sheet caps, fall slabs, foam bands) keep
disagreeing at corners; tuning one re-exposes another.

**B. Merge falls into the sheet mesh** (extrude crest rows down the ogee as welded sheet
geometry, one material). Strongest continuity by construction, but destroys the slab
"volume" look Ryan asked for (front/back/sides), needs new UV plumbing for streak motion,
and reworks `compute_ribbons`/tests wholesale. Too much churn for this round.

**C. Chosen: make every water surface the SAME clear green glass, and make foam a
*thin, attribute-keyed accent*** — then the remaining hairline geometry seams have
nothing to contrast against, plus targeted geometric fixes where the data shows real
holes (swim volumes). Falls keep their slab geometry but render with the sheet's body
(refracted scene through the same tint), foam only as streaks that *develop* down the
fall. This attacks the shared root of #1/#2/#5 (white-vs-green contrast + binary
refraction) instead of each symptom.

## Design

### 1. Swim volumes split at falls (`WaterSurfaceBuilder._river_volumes`)
Walk samples accumulating a run while `prof[start] - prof[j] ≤ 1.0` and run length <
`VOLUME_STRIDE`; emit one box per run: x-span = run's samples (ends clamped to the
crest/last sample, +1 m pad only at run-interior joints), y-span = `[min bed − 1,
run prof + 1.6]` (swell headroom so a bobbing char stays inside), `surface_y` = run prof.
Boxes never span a drop; the plunge pool gets its own hugging box. `_update_in_water`
unchanged (overlaps at joints now agree within 1 m).
**Test:** on the pinned seed river, build volumes and assert (a) the phantom point
`(49.3, 7.0, -1110.6)` is inside no box, (b) `(49.3, 4.6, -1110.6)` is inside a box with
`surface_y ≈ 5`, (c) for every box, `surface_y` minus min ground along its own samples ≤
RIBBON_DEPTH_OFFSET + slack, and box top ≥ surface.

### 2. One visual language: fall = sheet (`waterfall.gdshader`)
Body = refracted screen sample (offset scrolls downward with the fall + noise wobble,
same rejection guard as the sheet, graded not binary) tinted toward the sheet's
`color_deep` (~35 %). Foam = falling streak bands gated by `smoothstep(0.06, 0.55, UV.y)`
— crest starts as clean green glass flush with the upper pool, white develops on the way
down; plunge keeps strong white + existing alpha dissolve (0.88→1.06). Crest `ends`
whitening deleted. Side walls + lip cap marked via `UV2.x=1`: alpha × 0.45 and foam × 0.5
there, so the wings stop reading as bright shards. Roughness 0.5 stays.

### 3. Sheet clarity + true distortion (`water_unified.gdshader`)
- Refraction offset scaled by inverse view depth (`/ max(1, -VERTEX.z·0.08)`): strong
  wobble up close, subtle far — no giant smears, visible distortion.
- Offset normal gains an *animated* term: slow-scrolling noise (refraction only, not
  lighting) so the see-through picture visibly swims like the reference.
- Fallback is graded: `suv = mix(SCREEN_UV, suv, smoothstep(0, 0.25, depth_at_suv))` —
  kills the hard "lens edge" boundary at shores (V2 artifact).
- Foam gate tightened to `smoothstep(0.8, 1.0, shore)`: lap line hugs the waterline
  (±25 cm); the cap dive band and crest cells (shore 0.7) stop washing white — fixes the
  "detached pale skirt" reading. `foam_width` stays for the depth pinch.
- Glare: `roughness 0.07 → 0.14`, `SPECULAR 0.5..0.85 → 0.45..0.7` (the white blob in
  S3/V3 is the sun on a near-mirror surface).
- Clarity: `clarity_depth 6.5 → 8`, deep mix cap 0.92 → 0.88. `body_floor 0.22` stays.

### 4. Swells with real energy (`water_common.gdshaderinc` + `character.gd`)
Spectrum rebuild, all terms TRAVELLING sines (pass-21 rule: nothing rides slow noise):
two long (λ~150/163 m — large rise/fall), three mid (λ~38/27/19 m, distinct headings,
1.2–2.2 m/s — the visible bumps), and *deterministic envelopes* on the two big mid waves
(`0.75 + 0.45·sin(k_e·p − w_e·t)`, λ~90 m) for randomness that stays exactly
CPU-mirrorable. Sum normalized ≈ ±1, `wave_height 1.15 → 0.9`. `character.gd
_swell_offset` mirrors the full new sum (incl. envelopes — they're sines, not noise).
Shore fade (0.45→0.9 kill) and crest damping unchanged — waterlines stay pinned.

### 5. Deferred until seen at the after-vantages
"No skirt" residuals (0.5–2.5 m dry drops get neither rim nor curtain) and the
upper/lower-pool brightness difference: re-shoot V1/V3 after 1–4 land; add geometry only
if an artifact remains (candidate: dry-drop curtains at >1.2 m, or corner bury already
covers it).

## Error handling / invariants
- All shader edits keep `depth_draw_always`, `cull_disabled`, ALPHA-write (screen
  texture requires the transparent pass).
- Volume boxes stay coarse Area3Ds (swim tolerance): never used for rendering.
- Existing invariant suites (`test_water_float_invariants`, `test_water_surface_builder`,
  `test_water_plan`) must stay green; new volume test file added.
- Character mirror constants documented as "keep in sync" pairs in both files.

## Verification
GUT: water suites + `shader_compile_check`. In-game (pinned seed): re-shoot V1/V2/V3 at
Ryan's derived orbit-cam poses (cam = aim-point − 8 m horiz + 5 m up), plus a swell
motion pair (two shots 3 s apart) and a char-in-pool float check at V3. Iterate on
visuals until the annotated artifacts are gone; refresh `review_teleports.json`.
