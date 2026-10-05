# Lighting and biome atmosphere — implementation review

Status: implementation and visual acceptance complete. Shared lighting, layered
biome mist, foliage transmission, surface response, atmosphere-aware water and
three quality tiers are implemented. All seven biome appearances have production
evidence. Live woodland, jade orbit, forest-to-meadow travel, destination streaming
and quality costs have been reviewed. Focused native and headless checks pass.

The optional broad audit was bounded after more than four hours; it is **partial,
not green**. See `broad-suite-audit.json` and `broad-suite-partial.log`. Existing
nearby failures were reproduced on the unchanged baseline, but not every broad
failure was individually classified. Two unrelated procedural-water files were
stopped before completion; remaining tail files were not run by that audit.

Forest lighting delivers soft shadowed mist and dappled sunlight. Strong narrow
aerial shafts were not demonstrated at the normal gameplay camera. Metal GPU
timestamps are unavailable; frozen-scene frame measurements do not establish a
full-world frame-rate guarantee. No sky assets were purchased or integrated.

## Current controls and intended biome identities

Select `AtmosphereDirector` in `scenes/world.tscn` and change its exported **Quality**,
or call `set_quality(0|1|2)` at runtime. Standard is the default; this project has
no existing graphics-options menu, so no unrelated menu system was introduced.

| Tier | Effects | Grass |
| --- | --- | --- |
| Economical (0) | Distance haze, selective glow, FXAA; solid canopy shadows | 65% of current LOD population |
| Standard (1) | Local volumetric mist, SSAO, 2x MSAA, forest leaf-gap shadows | Full current LOD population |
| High (2) | Standard plus restrained SSIL bounce and 4x MSAA | Full current LOD population |

SDFGI and resolution scaling were measured as experiments and are not production
defaults. Quality changes preserve worker placement data and existing instance
buffers. `BiomeRegistry.LIGHTING`, `MIST`, and `SURFACE` are the authored controls;
spatial blending uses the existing world biome field.

| Biome | Intended appearance |
| --- | --- |
| Sunwash Meadows | Clear warm daylight, cool fill, restrained glow |
| Lanternwood | Cool forest shade, warm dappled sunlight, layered canopy mist |
| Opal Highlands | Pale cool daylight and distant aerial haze |
| Cherryveil | Rose dusk, cool shadow fill, softly glowing mist and petals |
| Moonfen | Indigo twilight, low water-relative mist, luminous orbs |
| Amber Heath | Golden light, cooler shadow fill, warm distant haze |
| Jade Estuary | Humid teal atmosphere, damp surfaces, shoreline mist |

Water reflections and underwater scattering follow the same lighting mood. The
shared sun direction stays fixed during biome travel. This table describes the
implemented direction; final live woodland acceptance is recorded below. The
bounded broad-suite results and their limits are recorded at the end. Work-log entries are chronological; later decisions
supersede rejected earlier trials.

## Scope and acceptance

- Shared sun, shadow fill, tone mapping, selective bloom and material response.
- Compare baseline, SSIL, SDFGI and combined configurations in the streamed world.
- Distinct atmosphere for all seven biomes: clear meadow, canopy shafts in forest,
  highland distance haze, rose dusk, indigo marsh, amber haze, humid jade shoreline.
- Continuous world-space mist profiles and water-relative layers; no chunk seams.
- Foliage transmission, restrained material wetness and atmosphere-aware water.
- Economical, standard and high rendering tiers; expensive effects remain optional.
- Stable biome travel, camera movement, streaming and underwater transitions.
- Preserve shared ground/grass/moss appearance, coherent shadow direction, neutral
  stone identity, deterministic worker data and main-thread resource creation.

## Review workflow

`tests/harness/atmosphere_review.tscn` accepts `--measure`, `--gi baseline|ssil|sdfgi|combined`,
`--no-fog` and `--no-glow`, alongside the existing position/capture arguments.
It warms up for 120 frames and measures 240 frames after the streamed dressing is ready.
The JSON beside the PNG records uncapped frame-interval median/p95, available
render-thread CPU/GPU counters, resolution, adapter, camera and toggles. Frozen
replay frame intervals include rendering throughput but exclude live generation
and full gameplay simulation. Zero GPU readings are unavailable, not free rendering.

Use the same resolution and camera for comparisons. `--freeze-time` now pins
shader motion; cross-run particle replay and motion sequences still need review.
Timing must be repeated without competing GPU workloads before accepting budgets.

First sites (seed 2697992464): meadow (192,576), forest (-480,384), marsh (-192,-240).
Additional coverage: seven positions and boundary in `biome_review_teleports.json`,
a town alley, a cliff, shoreline, underwater and a streaming traversal.

## Work log

- Inspected actual runtime atmosphere, local fog, foliage, grass and water shaders.
- Extended the production review harness with effect isolation and GPU measurements.
- Fresh worktree lacked ignored assets/addons. Copied local dependencies with APFS
  clones, retaining isolation from the main checkout. First missing-asset render
  was stopped and is invalid evidence.

### First implementation pass

- Profiles now carry lower/upper mist heights, upper-layer weight, emission,
  independent distant haze and sunlight scattering.
- The field packs mist shape alongside extinction; mist anchors to water when
  present. The shader uses one broad world-space noise octave, two height layers
  and restrained tinted scattering. Numeric shape textures skip colour conversion.
- Director quality 0/1/2 selects economical/standard/high. Standard uses local
  volumetrics, SSAO and 2x MSAA; high adds restrained SSIL and 4x MSAA. SDFGI remains
  a harness experiment. Fog range is 256m instead of 512m; requires world review.
- Lanternwood sunlight changed from greenish 0.55 energy to warm 1.05 energy,
  with slightly reduced and less saturated ambient fill. This is a candidate,
  not an accepted final grade.
- Added `lighting_study.tscn`: fixed geometry for quickly inspecting the actual
  director and fog shader, with generic stone/wood/wetness swatches. It does not
  validate the production terrain/vegetation shaders. Supports biome, capture
  and quality arguments. Fog time is pinned to 12 seconds for comparisons.
- Focused GUT run: 26 tests / 1229 assertions passed across atmosphere director,
  atmosphere field, biome registry, chunk FX and September 9 biome mood suites.
- GPU shader study rendered successfully on Apple M1 Pro, Metal Forward+ at
  1280x720. Inspected initial, layered, warm-forest and Moonfen images in
  `/tmp/story-lighting/`. Full-scene appearance and GPU budget remain unverified.
- Original production capture timed out in feature planning after five minutes;
  no valid baseline PNG was produced. Harness timeout extended to 1200s. Current
  candidate capture launched with restored dependencies, log
  `/tmp/story-lighting/lanternwood-candidate.log`; inspect its live tool session
  before starting another render. Do not treat the earlier timeout as evidence
  of a lighting regression.

### Remaining work (full original scope)

1. Complete production captures, obtain a trustworthy original comparison, and
   compare GI modes using representative GPU timings without competing workloads.
2. Tune all seven biome identities in real scenery, including visible forest
   shafts, rose glow, amber haze, highland depth and jade water mist.
3. Implement and review foliage transmission, shared restrained wetness/material
   response and water reflections that follow the atmosphere.
4. Synchronize underwater environment changes with the evolving surface mood.
5. Freeze relevant shader/particle animation for exact comparisons; add motion
   sequences for boundaries, camera turns and streaming.
6. Verify fog/water seams, quality switching, stone identity, grass stability,
   bloom clipping and moving-light trails. Run broader required tests.
7. Finish measured quality budgets and documentation; remove rejected experiments.

This early checklist is historical. The status above and latest review entries
record which items have since been implemented and validated.

### Material and transition pass

- Fixed a reproduced underwater mood bug: the submerged environment previously
  froze ambient colour, energy, bloom, quality and exposure at entry. It now
  mirrors changed surface settings into the same private resource, retains its
  own medium instead of air fog, applies current exposure with depth dimming,
  and restores the exact original environment on exit. Regression failed five
  assertions before the fix and passed afterward.
- Added a fourth canonical 65x65 material lookup (dampness/transmission), updated
  only when the biome map scrolls. All overlap invariants now cover this layer.
  Terrain, sheet, rock contacts and grass share one restrained roughness/specular
  function. Grass transmission fades at roots and with distant geometric detail;
  canopy backlighting uses the same geographic response without colouring bark.
- Water reads the blended sky's linear horizon/zenith colours. Only authored
  scattering, foam and aeration use the scene light gain; screen transmission
  is already lit. Twilight gain is tested below 0.35, daylight at 1.0.
- Production ground, cliff, canopy, Meadow rock, grass and water shaders compiled
  and rendered in the fixed-geometry material study on Metal. Inspected
  `/tmp/story-lighting/materials-jade.png` and `materials-water-moonfen.png`.
  These prove shader operation, not final landscape art direction.
- Added `--sweep` to the production harness: standard/economical/high, isolated
  SSIL and SDFGI, combined GI, no fog and no glow, after one terrain load.
  Reports include actual GI toggles and MSAA. Readiness now includes grass work
  and commits. `--freeze-time` pins shader wind/waves/mist and orb motion, seeks
  seeded particles, and holds existing water simulation buffers for within-run
  comparisons. Cross-run particle determinism and motion reviews remain unverified.
- Focused suites: 28 tests / 1307 assertions passed before adding the explicit
  water-surface mist assertion; its final rerun is recorded separately below.
- Four broader suites initially reported 7 failing tests, all showing invalid UID
  warnings in imported assets. The worktree generated new ignored script IDs.
  Restored 1874 `.uid` files from the original checkout and cleared the documented
  filesystem cache; re-import is running. Must rerun the broader suites afterward.

### Live work and isolation

The earlier candidate process was stopped when the new material schema made its
already-loaded project globals obsolete. It produced no valid image or timing.
A managed baseline checkout now exists at
`/Users/ryko/.codex/worktrees/lighting-baseline/story`, pinned to
`f4d9b972ce996dc7bca37d20fa2868f0add559d2`. Only its review harness changed
(measurements and a 3600-second timeout); its production sources remain original.
Dependencies and ignored remaps are isolated copies. Its first run failed because
tracked PNGs lacked ignored import remaps; those were restored before relaunch.
Current baseline run: tool session 76508, log
`/tmp/story-lighting/lanternwood-original.log`, output `lanternwood-original.png`.
It is still doing feature planning; do not restart on an observation timeout.
Current main-worktree UID re-import: tool session 96094, log
`/tmp/story-lighting/uid-import.log`. The baseline is in use; retain its worktree.

Next: finish baseline, rerun related tests after UID repair, then capture the current
production sweep with frozen sources. All seven real biome views, motion/seam checks,
GI selection, GPU budgets, broader suite comparison and final art acceptance remain
open. The material implementation is now present but still needs world-level tuning.

Latest verification: field + water regression rerun passed 10 tests / 1364
assertions, including all 169 mist samples anchored at the mock water surface.
Latest material study (`materials-meadow.png`) compiled the shared visual clock,
water reflection changes and grass support-normal response without shader errors.
The bright meadow study looks quite pale/lime; check highlight compression and
ambient/key balance in the actual landscape before accepting that endpoint.
The baseline has advanced to its second feature job (first feature ready), so
its long initial planning phase was slow work rather than a dead process.

### Asset repair verification and sky shortlist

The UID re-import finished. The four related suites now pass all 20 tests / 389
assertions (`/tmp/story-lighting/related-repaired.log`), including water shader,
grass streaming, neutral ambient light and ground seams. The prior seven failures
were resolved by restoring the ignored resource identities. Import logged errors
for unused Quaternius sources and sandboxed editor settings; those are separate
from these now-passing runtime regressions.

The original landscape capture has reached 4/9 built chunks and 16 feature-ready
chunks after roughly 15 minutes. Candidate timeout now matches the baseline's
3600 seconds, because a 1200-second timeout leaves little margin for the remaining
terrain, dressing and grass generation. The expensive phase predates this change.

Sky research is secondary to shader validation. No assets purchased or installed.
Candidate fit below is an art-direction judgement from public listings/previews,
not evidence of integration or measured performance.

- [Anthony Wille: Stylized Skies](https://www.artstation.com/marketplace/p/6gzAj/stylized-skies-collection-of-handdrawn-skies-and-clouds):
  inspected preview; painterly, crisp-edged cloud masses with soft internal shading.
  Fifteen images include backgrounds, cubemaps and individual alpha cloud PNGs.
  My first choice for a hybrid procedural gradient + painted cloud layer, allowing
  daylight, rose and indigo biome tinting. Listing explicitly says its cubemaps are
  not HDRIs. Commercial option listed at $12 on October 4, 2026.
- [Leeyo Atelier: Skies 2 — Stylized, textures](https://leeyoatelier.gumroad.com/l/skies2-stylized-textures):
  inspected preview; attractive blue daylight, rose sunset and moonlit variants.
  Five 8192x4096, 16-bit sRGB PNG panoramas; direct texture edition avoids reliance
  on the Unreal-only package listed on Fab. Large baked celestial discs constrain
  light alignment and crossfades. Prefer the daylight/rose/moonlit options over the
  more saturated neon or murky brown looks for this game's current materials.
  Store header shows $6+ but indexed purchase minimum differs; confirm final price
  at selection time rather than promising a fixed price.
- [BD Studios: Free Stylized Hand-Painted Skybox](https://marketplace.unity.com/packages/2d/textures-materials/sky/free-stylized-hand-painted-skybox-265475):
  free comparison candidate, supplied as a Unity package. Raw texture contents
  and Godot import have not been verified; lower priority than the texture packs.

The [EmaceArt procedural sky](https://store.godotengine.org/asset/emace-art/stylized-procedural-sky/)
was considered but is not a drop-in choice: its listing requires Godot 4.7 and marks
the release unstable; this project runs 4.5.1.

Proposed integration after lighting acceptance: retain one shared sun direction;
blend the sky gradient with existing biome mood weights; add at most two cloud
texture layers, with slow coherent drift and biome tint; keep sun/moon separate
where possible. Start at 2K/4K and measure texture memory, sky update cost, horizon
seams and crossfade ghosting. Water's current gradient reflection approximation
would need to sample the same sky function to reflect the painted clouds.

### First landscape evidence and motion review support

Previous goal turn classification: progress (sky shortlist recorded and related
shader regressions verified passing). This turn re-polled live baseline session
76508, then observed successful completion rather than restarting it.

- Baseline finished nine chunks in 1050.97 seconds, captured 141 dressing batches /
  2518 instances / 218 collision shapes. Image and JSON are preserved in `captures/`.
  It is visibly a reed-covered lowland with flat cool illumination and little
  surface separation. The current biome survey confirms this is **100% deep_forest**:
  the geographic label is correct, but the local land cover is wetland, so this
  view cannot establish canopy shaft quality. A dry wooded view is still needed.
- Baseline render-thread CPU median 0.361ms, p95 0.520ms. GPU timestamps are zero
  and unavailable on this Metal run. These CPU timings do not establish frame rate.
  Original/candidate animation and the baseline's immersion state at its relocated
  camera are not fully matched, so this is provisional visual evidence.
- Candidate measurements now disable VSync and the engine FPS cap, and record
  median/p95 wall-clock frame intervals separately from GPU/render CPU time.
  Report includes biome weights and actual VSync mode. These are throughput
  measurements, not a replacement claim of GPU timing.
- Added `--orbit`: 180 sequential rendered camera steps across 90 degrees, saving
  13 frames and camera transforms. Runs for standard/high in a sweep. Frozen-time
  mode isolates temporal artifacts caused by camera movement. Actual sequence
  inspection remains pending. The relocated review camera refreshes immersion
  before stopping the director, and at each orbit step.
- Harness parse validation passed before the frame timing addition; candidate
  startup subsequently loaded the full script without parse errors.
- Current production candidate is live: session **55298**, log
  `/tmp/story-lighting/lanternwood-candidate.log`, `--measure --sweep --orbit
  --freeze-time 12`. Keep sources stable until its captures finish.
- Identical-material seven-biome study is running sequentially in session **25959**;
  output `/tmp/story-lighting/palette-<biome>.png`. It is supplementary material
  evidence and does not replace each biome's actual landscape acceptance.

Both seven-biome study runs have now completed (25959 and contrast trial 51053),
with no logged shader/script errors. All fourteen images were inspected and copied
to `captures/`. `lighting_study --grade contrast` is a review-only alternative:
ambient energy multiplied by 0.7 with a 0.24 floor, shadow opacity 0.82, general
bloom 0.012. It has not changed the production grade.

Visual findings: stronger shadows improve form separation in meadow, highland,
amber and jade while leaving the sunlit surfaces similar. Meadow still looks too
pale/lime and highland is very pale overall. Moonfen is already near the lower
readability limit, so a blanket ambient reduction is not an accepted solution.
Cherryveil keeps a distinct rose mood but needs real vegetation to judge whether
its pink is excessive. Forest has a warmer readable key, but neither synthetic
study establishes convincing canopy shafts. Next grade trial should target bright
biomes individually and preserve twilight shadow readability; compare in actual
landscapes before promoting any constants.

The production sweep is still live in session 55298, doing its first expensive
feature-path planning phase. No final candidate image or accepted budget yet.

### Orb compatibility and repeatable scenery

- Reproduced four orb-test failures: orb-only payloads have no `mist_shape`.
  The adapter now checks density before creating fog textures, avoiding all three
  images/textures for clear chunks. An older test and replay also implicitly set
  fog alpha to one via `PackedColorArray.resize`; their orb-only fields now
  explicitly use zero density. Headless rerun: 10 passing / 1 graphical-only
  pending, 798 assertions. Native Metal rerun: all 5 orb tests / 2584 assertions
  passed, including the renderer-only motion/light-attachment check.
- Added optional `atmosphere_review --snapshot <path.scn>` using the existing
  render-fixture saver. It now retains the fourth material map, lighting globals,
  mood/seed/position, and an optional pinned visual clock. Captured water materials
  replace viewport textures with images without changing the original material.
  Replay files omit runtime scripts so they cannot start terrain workers.
- Snapshot round-trip test passes eight assertions: numeric texture pixels,
  twilight water gain, clock, review position and script-free restoration.
  Live water-buffer round-trip still needs native verification on a fresh export.
- Added `lighting_replay.tscn --replay <path>`, with quality/GI/effect options,
  `--grade contrast`, and `--sun-yaw`. Legacy camera-less captures accept recorded
  `--player x,y,z --crosshair x,y,z` through `ReviewCam.solve_cam`.
  Validated on the September 12 town fixture at player (956.3,16,-2065.3),
  crosshair (956.1,17.2,-2064.9), with fog disabled. This is old geometry and
  supplementary lighting evidence only. Initial attempt had no camera and exited
  with an engine shutdown crash; supplying its recorded pose rendered successfully.
- Inspected three town images (saved in `captures/`): current grade, contrast grade,
  and contrast with sun yaw -110. Ambient reduction alone changes little in this
  front-lit view; side lighting substantially improves roof, timber and masonry
  depth. It remains a trial, not a production sun-direction change.
- Full isolated suite is live in session **94766**, summary
  `/tmp/story-lighting/full-suite-summary.log`. Serial process group **68026** was
  temporarily suspended with SIGSTOP before candidate frame timings; **resume with
  SIGCONT after session 55298 finishes**. Other user's test processes are untouched.
  At suspension, 20 files had reported with no failures. The newly added snapshot
  test is separately verified, as the full runner enumerated files before it existed.

Candidate production code loaded before the orb allocation fix; its fog-bearing
chunks use the same shader/data. Do not claim its clear-chunk allocation timings
cover the later optimization. Its harness also predates the snapshot option, so
the currently running capture will not export a scene; subsequent sites should.

### Candidate capture, stalled window, offscreen recovery

- Session 55298 finished terrain in 1027.5s and produced the standard view, now
  preserved in `captures/lanternwood-candidate-standard.*`. Compared with the
  provisional original, key light is warmer and the character is easier to read;
  the wet lowland still looks quite flat. Standard 1280x720, 2x MSAA: frame median
  27.889ms / p95 31.283ms; render CPU median 0.351ms / p95 0.440ms. GPU timing is
  unavailable. This is one configuration, not a completed comparative budget.
- The native window stopped producing draw events before its first orbit frame.
  Repeated session polls confirmed it alive; a one-second `sample` of PID 66808
  showed an idle/delayed main loop, not active terrain work or a CPU deadlock.
  The same orbit code completed all 13 frames in the fast study both with and
  without uncapped measurement. The precise window-level cause is unproven.
- Preserved the available evidence and explicitly terminated only PID 66808;
  session 55298 is now terminal (143). It must not be polled or described as live.
  Test process group 68026 was **resumed with SIGCONT**, and remains running.
- Production review now uses an always-updating offscreen SubViewport. A two-second
  no-draw watchdog forces a frame and records recovery; measurements spanning a
  recovery are flagged invalid. Capture/report uses the camera's actual viewport.
  New live session **50365**, log `/tmp/story-lighting/offscreen-candidate.log`,
  requests the full sweep and `/tmp/story-lighting/lanternwood-current.scn` before
  variants. No orbit in this generation run; replay can perform camera experiments.
  Headless parse check passed. Do not claim offscreen recovery proven until it runs.
- Full suite has its first reported failure in `test_feature_program.gd`; focused
  reproduction log `/tmp/story-lighting/feature-failure.log` is pending inspection.
  No baseline comparison has established whether that failure is pre-existing.

Offscreen replay subsequently completed its screenshot, all 13 orbit images and
measurement on the town fixture (session 53291, exit 0), with zero watchdog draws
during measurement. Inspected start/mid/end views; architectural shadows track the
camera changes without obvious displaced trails in these samples. This does not
cover volumetric trails because fog was deliberately disabled on the legacy fixture.
Artifacts are in `captures/town-offscreen*`. The 640x360 timings are exploratory
with other generation/test work active, not a production performance budget.

The exact feature-program mismatch (195.5 versus expected 159.5) also occurs on
unchanged baseline f4d9b972 (`/tmp/story-lighting/feature-baseline.log`). Baseline's
old UID cache contributes additional warnings/failures, so compare this specific
assertion rather than aggregate counts. It is not a lighting regression.

Current live work: full suite **94766** (resumed; group 68026 is not suspended),
offscreen production capture **50365**. The previous 55298 render is terminated;
all quick study/replay/native-orb jobs are complete. Snapshot test: 1/1, 8 assertions.
Source changes during the new production build are harness-only refactoring of
the already-loaded viewport setup plus replay support; its render configuration
and shaders remain unchanged.

### Side-lighting comparison and broader regression triage

- Inspected `captures/side-meadow.png`, `side-deep_forest.png` and
  `side-twilight_marsh.png`. These use yaw -110 and shadow opacity 0.82 while
  preserving the production ambient fill and bloom. Cast shadows describe form
  more clearly; Moonfen remains readable without the rejected blanket fill cut.
  Meadow is still pale and the wet highlight can clip. These are material studies,
  not landscape acceptance; production sun constants remain unchanged.
- Replay now supports the same `--grade side` isolation so the pending current
  landscape snapshot can be compared without changing two lighting variables at
  once. The older town-side capture also reduced ambient fill and therefore is
  not equivalent to this new isolated side grade.
- The dressing-field failure `nature wave asset is active: lpfv.big_rock.01`
  occurs at line 72 in both current and unchanged baseline runs
  (`/tmp/story-lighting/dressing-current.log`, `dressing-baseline.log`). The
  baseline cache additionally produces UID warnings, so aggregate counts are
  not comparable. Both focused jobs were still finishing other tests when this
  was recorded (sessions 50594 and 84270).
- Full suite also reports one field-streamer failure; its assertion has not yet
  been isolated. Do not classify it as pre-existing without reproduction.
- Current offscreen capture session 50365 remains in terrain feature planning
  at about 460 seconds, with no screenshot/snapshot yet. Preserve this build.
  The full-suite runner 94766 is running, not suspended. Side studies 2053 ended
  successfully. No final performance or seven-biome acceptance claim is made.

### Native water snapshot verification

- Extended `test_lighting_snapshot.gd` with a graphical readback test: two water
  meshes share a live material backed by a rendered SubViewport; capture copies
  both ripple and packet images, preserves sharing, leaves the original material
  intact, and survives binary scene save/reload after the original viewport is
  freed. Native Metal run passed 2/2 tests, 19 assertions, session 7397 exit 0
  (`/tmp/story-lighting/water-snapshot.log`). This verifies the capture mechanism;
  the pending real-world snapshot still needs visual comparison.
- Current dressing test 50594 is terminal (exit 1); the known asset-active
  assertion is the current failure. Baseline 84270 reached its summary with five
  failures including cache-related errors and the same asset assertion.
- Started a focused field-streamer reproduction, session 4034, log
  `/tmp/story-lighting/field-focused.log`. At last inspection it was in its
  background-build test with no failure yet. Do not infer the suite's failing
  assertion from its test name or elapsed time.
- Offscreen capture 50365 verified live at 625 seconds, now building neighbouring
  feature blocks (one feature block ready, progress 0.59). Full suite 94766 also
  verified live. No restart or production shader edits during this build.

### Completed current-world quality sweep

Session 50365 completed successfully (exit 0). Terrain loaded in 1060.055s;
snapshot `/tmp/story-lighting/lanternwood-current.scn` was saved before variants.
All eight captures/reports are preserved as `captures/offscreen-candidate-*`.
Actual scene: 141 dressing batches, 2518 instances, 218 collision shapes; forest
weights 1.0 at (-480,384), a wet lowland rather than a dense canopy site.

1280x720, Apple M1 Pro / Metal Forward+, fixed shader time 12, uncapped:

| Variant | Median frame ms | p95 ms |
|---|---:|---:|
| Standard | 21.701 | 25.374 |
| Economical | 16.947 | 21.180 |
| High | 24.691 | 28.690 |
| SSIL at standard MSAA | 22.525 | 26.237 |
| SDFGI | 25.552 | 30.198 |
| Combined GI | 26.616 | 30.951 |
| No fog | 21.365 | 24.886 |
| No glow | 21.876 | 25.767 |

GPU timestamps remain unavailable. All measurement intervals had zero forced
draws; the watchdog recovered five idle gaps outside those intervals. These are
single-run wall-clock comparisons, not universal GPU budgets. Our test groups
68026 and 73214 were suspended for the sweep and **both resumed with SIGCONT**
after it completed. Other running work was not manipulated.

Inspected standard, economical, SSIL, SDFGI, no-fog and no-glow images. SSIL/SDFGI
bring little improvement to this open scene. Fog softens distant trees but still
flattens the foreground; removing it saves only ~0.34ms in this sample. Glow cost
is within noise here. The economical gain likely includes AO and MSAA; isolate
those before attributing it. No production quality change accepted from one site.

Current-world side-light replay with fog and a 13-frame orbit is now running,
session 23525 (`/tmp/story-lighting/current-side.log`). It uses `--grade side`,
preserving ambient fill. The full suite 94766 and focused streaming test 4034
are resumed. The latter reproduces a 60-second worker-payload timeout and then
ring/release assertions while cold planning is still active; baseline comparison
is still needed before declaring that failure pre-existing.

Side replay 23525 completed (exit 0) and saved all 13 orbit samples. Its start
image has noticeably pale/blue reeds compared with the live standard image;
do not accept the sun-angle change until replay fidelity is established. Loading
the PackedScene at replay line 21 reports three absolute get_node paths outside
the active tree, suggesting retained viewport references despite captured water
overrides. There are also shutdown resource-leak diagnostics. Control replay
with unchanged lighting is running as session 91715, log
`/tmp/story-lighting/current-control.log`, output `current-control.png`. Compare
it with `offscreen-candidate-standard.png` before attributing pale reeds to light.
Side captures are preserved in `captures/current-side*`; motion review remains
pending that fidelity check. Both test groups are resumed, not suspended.

### Replay palette repair and next biome

The unchanged control replay also rendered pale reeds. Root cause verified in
`CameraVisibilityBubble._adapt`: native material parameters are written directly
to RenderingServer, bypassing ShaderMaterial's serializable parameter storage.
Snapshot/replay now reconstruct those parameters from the original native surface;
texture RIDs are converted back to source Texture2D resources. The original live
adapter is untouched. `control-fixed2.png` restores green/brown reeds and visually
matches the live standard capture. An initial detector checked an include's
uniform rather than its include path; that missed the adapters and was corrected.

Native snapshot suite now covers traversal, texture serialization, sharing and
live buffer readback: 3/3 tests, 26 assertions, clean exit 0 in session 47109
(`/tmp/story-lighting/snapshot-adapter3.log`). The preceding run passed assertions
but crashed on shutdown; waiting for two render frames after retiring the temporary
adapter resolved the next run. Do not describe the crashed run as passing.

Repaired side-light replay 79952 completed, including all 13 orbit images. Inspected
start/mid/end: warmer shafts in the distant trees and stronger reed/character
shadows improve depth. No obvious large fog trails in these samples; this is not
a complete temporal-artifact audit. Files `captures/current-side-fixed*` supersede
the pale-reed side captures. Production sun is still unchanged pending adoption.

Water snapshot capture now inspects viewport uniforms on any geometry shader
override, including camera-wrapped water and depth adapters, rather than requiring
the original water shader path. The next current-world snapshot must verify that
this also removes the absolute-path load diagnostics.

Twilight-marsh production capture **21712** is live, position (-192,-240), log
`/tmp/story-lighting/moonfen-current.log`, snapshot/output `moonfen-current.scn/png`.
It started with unchanged production shaders/director and does not measure frame
timings while test jobs run. The current forest snapshot remains reusable at
`/tmp/story-lighting/lanternwood-current.scn` (105 MB). Full suite 94766 and focused
test 4034 are resumed; no jobs are intentionally suspended.

### Adopted sun direction and isolated AA/AO costs

Production sun now uses yaw -110 degrees and shadow opacity 0.82, retaining
elevation -32, biome ambient fill, exposure and bloom. Evidence: three biome
material studies, the architecture study and the corrected current-world forest
side comparison/orbit. This strengthens form without the rejected blanket ambient
reduction. It remains subject to seven-biome review. Focused director/world-lighting
tests passed 6/6, 29 assertions (`/tmp/story-lighting/grade-tests.log`, exit 0).
The already-running Moonfen build loaded the earlier sun constants; review it
through replay with the new grade before claiming production-angle acceptance.

Matched frozen-world ablation at 1280x720 (same old sun for all three):

| Replay variant | Median frame ms | p95 ms |
|---|---:|---:|
| Standard 2x MSAA + AO | 16.659 | 19.030 |
| No AO, 2x MSAA | 15.957 | 18.050 |
| AO, no MSAA | 13.961 | 14.682 |

All intervals have valid wall-clock timing, zero forced draws; GPU timestamps
unavailable. Replay omits live simulation, so its baseline is not comparable to
the live sweep's 21.701ms as an optimization claim. Thin reeds visibly degrade
without MSAA; retain 2x for standard. AO costs about 0.7ms here, MSAA about 2.7ms.
Artifacts: `captures/ablation-*`. Temporary pauses of our groups 68026/75662 were
both resumed after session 78477 exited 0. No job is intentionally suspended.

Snapshot regression after generic viewport handling initially failed because a
numeric uniform was cast to Texture2D. Fixed by inspecting its Variant type first
and explicitly typing the readback Image. A native run now passes 3/3, 26 asserts,
exit 0 (`/tmp/story-lighting/snapshot-verified.log`, session 65297). Intermittent
shutdown crashes in earlier adapter tests were not a clean pass; the test now
releases temporary shaders before awaiting renderer retirement.

Current live work: Moonfen build 21712 (about 365s, cold plan complete, feature
paths active); full suite 94766; FXAA side-light replay/orbit 86514 (log
`/tmp/story-lighting/fxaa-side.log`, output `fxaa-side.png`). Focused streaming
test 4034 finished exit 1, one test with three timeout-related assertions; baseline
classification remains open. FXAA is a review-only flag, not yet a production tier.

FXAA replay/orbit 86514 subsequently completed. Inspected initial and midpoint
images: fewer harsh aliasing edges than no-AA, but distant reeds are softer and
thicker than 2x MSAA. Adopted FXAA for economical quality only; standard/high
explicitly clear screen-space AA when switching back to MSAA. Preserved in
`captures/fxaa-side*`. Its frame-time cost still needs measurement; the no-MSAA
ablation is not an FXAA timing. Native snapshot regression 65297 passed all 3
tests / 26 assertions and exited cleanly. Both background jobs remain resumed.

### Forest mist height tuning

Added review-only lower-height / upper-weight scales to the frozen-scene replay.
Compared the corrected current forest with both scales at 0.5, retaining sunlight,
density at the ground, distant haze and scattering settings. `captures/forest-layered.png`
shows clearer near reeds/shadows and retains distant tree separation; the previous
upper layer washed a larger part of the view. Adopted for forest: lower scale
height 9 -> 4.5m, upper contribution 0.24 -> 0.12 (upper height remains 30m).
Other biome mist profiles are unchanged. Dense-canopy shafts still need a dry
forest site; this wetland view does not prove that requirement.

Replay 88328 completed exit 0. Moonfen capture 21712 remains live at about 600s,
still in its first feature-path build; do not restart it based on the long phase.
It loaded the earlier sun/forest constants, so subsequent replay is required for
current-source comparisons. Full suite 94766 remains active, no jobs suspended.

### Quality transitions and dry forest viewpoint

Extended the quality-switch regression to put the camera in a real SubViewport:
high 4x MSAA -> economical FXAA/no MSAA -> standard 2x MSAA/no FXAA. This verifies
that returning to standard clears the economical blur pass. Headless director
tests passed 5/5, 31 assertions (`/tmp/story-lighting/quality-switch.log`). The
preceding forest-profile field/registry run passed 14/14, 1411 assertions.

Located actual tree placements in the saved forest using native MultiMesh readback
(headless returned zero transforms and was discarded). Dry trees sit near
(-660,16,539). Capture `forest-canopy-pose.png` confirms dry sloping lawn and large
canopy shadows; a foreground trunk obstructs much of that view. Replay camera
relocation now samples mood at the requested position instead of retaining the
original snapshot mood. A more sun-facing orbit is running as session 72866,
log `/tmp/story-lighting/forest-canopy-orbit.log`, output `forest-canopy-orbit.png`.
This uses the current sun and half-height/half-upper-weight mist on the older
snapshot, equivalent to the adopted forest mist change.

Moonfen 21712 verified live at ~920 seconds, five feature blocks ready; full suite
94766 also remains running. No intentionally suspended jobs. The earlier
`forest-canopy.png` used incorrectly formatted camera flags and is not a new
viewpoint; only `forest-canopy-pose.png` used the verified coordinates.

### Twilight landscape reviewed

Moonfen capture 21712 completed successfully: nine chunks in 1009.781s, 144
dressing batches / 2517 instances / 130 collision shapes, 5609 visible grass
instances. Saved `/tmp/story-lighting/moonfen-current.scn` (75 MB) and
`captures/moonfen-current.png`. Snapshot duplication and replay still report
three absolute-path lookup diagnostics; generic viewport capture did not eliminate
all retained references. The rendered water/reed appearance is usable, but do
not claim the diagnostic issue resolved.

The indigo air/water and warm floating lights establish twilight; near character
and shoreline were close to the readability limit. Increased only Moonfen's
ambient energy 0.28 -> 0.30 and moonlight 0.18 -> 0.28, preserving hues and glow.
Current-grade replay 52126 completed with all 13 orbit frames. Inspected start,
midpoint and end: shoreline/rock forms separate better while retaining darkness;
no obvious large glow trails in those samples. Artifacts `captures/moonfen-readable*`.
Focused director/water/registry tests passed 13/13, 104 assertions; twilight's
water gain remains below 0.35. Live water motion and underwater transitions are
not proved by frozen-time orbit images.

Dry-forest orbit 72866 completed. Shadows are legible, but this small wooded rise
does not show strong shafts; stored grass coverage also belongs to the original
player location, so it is a lighting probe, not a complete relocated gameplay view.
Checking a forest alternative retaining upper weight 0.24 while keeping lower
height 4.5m: session 12477, log
`/tmp/story-lighting/forest-canopy-haze.log`, image `forest-canopy-haze.png`.

Blossom production capture **55730** is running at (672,96), log
`/tmp/story-lighting/blossom-current.log`, outputs `blossom-current.scn/png`.
It started with the current sun, forest mist and Moonfen lighting constants.
Full suite 94766 remains running. No intentionally suspended jobs.

Forest alternative 12477 completed. Retaining upper weight 0.24 gives better
distant tree separation and sun scattering than 0.12 while the 4.5m lower layer
still clears the foreground relative to the original 9m. Adopted 4.5m / 30m /
0.24 as the forest shape; `captures/forest-canopy-haze.png` records it. This
supersedes the earlier half-upper-weight choice. Blossom's live build loaded
the preceding 0.12 forest upper weight; its own blossom profile is unchanged.

### Underwater scattering follows biome illumination

Added an immersion sequence to the fixed material study: the camera descends
from y=1.2 to 0.3 through a pool at y=0.8, then returns, saving nine frames. This
uses the production water shader and UnderwaterView with a controlled sampler;
it is not proof of natural-world underwater coverage. Its geographic tint query
is still at the study origin while lighting is forced to the selected biome.

The first twilight sequence exposed a real lighting mismatch: the unlit underwater
overlay retained daylight-bright turquoise scattering despite the dark environment.
Director now sends the same light gain used by the surface water to UnderwaterView;
the medium tint is scaled in linear colour space before upload. Air exposure and
extinction are unchanged. Inspected frames above, entering, submerged and exited:
the repaired underwater view stays darker and the above-water view is restored.
Before/after artifacts: `captures/immersion-moonfen-*` and
`captures/immersion-moonfen-dim-*`. Native sessions 42392 and 68534 exited 0.

Regression checks compare bright/dark medium scattering and verify the director
actually supplies twilight gain to the immersion effect. Initial focused run
passed 7/7, 45 assertions; final wiring run is session 57768, log
`/tmp/story-lighting/underwater-wiring.log`. Blossom 55730 and full suite 94766
remain live; no intentionally suspended jobs. Blossom loaded the previous
UnderwaterView, but its above-water capture does not exercise this change.

### Blossom review and custom-grass snapshot fidelity

Blossom 55730 completed (exit 0): nine chunks in 799.065s, 185 batches / 1493
instances / 216 collision shapes, 4604 visible grass instances. Snapshot
`/tmp/story-lighting/blossom-current.scn` and `captures/blossom-current.png`.
The original rose fill flattened grass/ground/water separation. Adopted cooler
ambient colour `94aac7`, energy 0.42 (was `c7b2d2`, 0.52); sun, sky and glow
remain unchanged. Corrected result: `captures/blossom-repaired.png`.

The first cool-fill replay exposed a capture regression: native-material repair
also copied native parameters onto custom grass overrides whose underlying mesh
had a StandardMaterial. That cleared the shared ground palette and produced a
false pink island. Restrict native repair to the actual native adapter signature.
Earlier saved snapshots with cleared grass bindings are repaired from the exact
GrassStreamer sources: source albedo, palette/UV, mesh base/height. Intact custom
overrides remain untouched. `blossom-cool-fill*` and `blossom-cool-fixed.png` are
invalid grass-colour evidence; the repaired single view supersedes them. Earlier
forest/twilight replays also used that overbroad repair and should be rechecked
where grass appearance matters. Their live captures remain valid.

Snapshot tests now explicitly preserve a custom grass override. Native assertions
passed but shutdown intermittently crashed; waiting within a test retained its
locals, so it did not reliably retire resources. An after_all render wait now runs
after local references are released. Session 13295 exited cleanly: 3/3, 28 asserts.
Combined native snapshot/director/underwater run 25412 also exited 0; see
`/tmp/story-lighting/blossom-validation.log`. Underwater wiring run 57768 separately
passed 7/7, 46 assertions.

Meadow production capture **91083** is live at (0,0), log
`/tmp/story-lighting/meadow-current.log`, outputs `meadow-current.scn/png`.
At last inspection ~555s, first feature block active. It started before the cooler
blossom fill but includes the underwater light fix. Full suite 94766 is still
running; no intentionally suspended jobs. A corrected blossom orbit is being
captured separately in `/tmp/story-lighting/blossom-final-orbit.log`.

### Corrected orbit checks and remaining landscape captures

Blossom final orbit 55903 exited 0. Inspected middle/end views after the grass
repair: canopy remains pink, shaded grass keeps the cool neutral substrate, and
water/shore silhouettes stay distinct. Saved `captures/blossom-final-orbit*`.
Moonfen final orbit 88470 also exited 0; inspected start/middle/end with corrected
grass bindings. Its actual mix is 95.98% twilight marsh, 2.98% amber, 0.71% blossom,
0.33% meadow. Indigo water, subdued reed colour and warm motes remain consistent
through the turn. Saved `captures/moonfen-final*`. These are frozen-world camera
checks, not acceptance of live water animation or streamed travel.

Meadow-at-origin 91083 exited 0 with 123 batches / 2714 instances / 75 collision
shapes and zero visible grass. The image shows a broad reed-covered water surface;
it is **not dry-meadow acceptance**. Use the existing Sunwash review position
(192,576) for that remaining check instead of relying on the spawn label.

Production highland capture **61617** at (384,672) and amber capture **66478** at
(-480,-384) are now running, both with fixed visual time 12 and `.scn` snapshots.
Logs `/tmp/story-lighting/highland-current.log` and `amber-current.log`. Full suite
**94766** remains active and memory-gated; no intentionally suspended jobs. Avoid
launching more terrain builds while these two occupy memory.

The review harness now writes a separate `-scene.json` for both live captures and
frozen replays, recording biome weights, actual camera transform/FOV, resolution,
quality, visual time and source. This does not overwrite optional timing JSON.
Headless replay script parse check exited 0 and native Moonfen exercised the new
report successfully. Existing highland/amber processes loaded the previous harness
before this addition, so obtain their weights from snapshot metadata afterward.

### Spatial mood and material-map flight

Added replay `--travel-end x,z`: move the camera through frozen production geometry
at a simulated 10m/s, update the real biome weights/director and canonical material
map at 60 steps/s, then hold nine seconds at the endpoint. It records screenshots
every three simulated seconds plus weights, sun/ambient energy and map centre.
This isolates spatial lighting continuity; it deliberately does not claim to move
the player, regenerate the grass ring, simulate water or stream new terrain.

Native session **43679** exited 0 for forest (-480,384) to boundary (-240,672).
Inspected frames 720, 900, 1080, 1440, 2160 and 2790. The lookup centre changes
from (-768,768) to (0,768) between samples 900/1080 without an obvious colour seam.
The later biome transition raises sun energy continuously from 1.05 to 1.3901;
settled weights are 98.2% meadow, 1.3% forest and 0.5% twilight. The shaded forest
and pale meadow remain geographically distinct while the shared sky/water lighting
eases. No abrupt exposure jump is visible in the sampled sequence. Grass is absent
at the destination because this is a frozen capture of the original player's ring;
that view must not be used to approve live meadow grass.

Artifacts: `captures/forest-travel-travel-*` and its JSON. Headless script parse
check exited 0; `git diff --check` clean. Highland **61617**, amber **66478** and
isolated suite **94766** were re-polled and remain live. Last terrain heartbeats
were approximately 505s and 435s, both advancing feature planning. No build was
restarted and no additional heavy capture was launched.

### Live traversal harness prepared

Added `atmosphere_review --live-travel-end x,z` for the outstanding live check.
It scripts observer XZ at 10m/s while leaving gravity, water, the director, grass
queues and terrain streaming active. Screenshots/weights/grass counters are saved
along the route; the destination waits for its actual 3x3 chunk keys and empty
grass/dressing queues, then holds nine seconds before the settled capture. This
is a rendering/streaming test, not a proof of walkability. Frozen-time arguments
are rejected for this mode. A timeout propagates a nonzero exit.

Two parse checks exited 0 and diff whitespace checks pass. **Native traversal has
not run yet**. Suggested remaining run: start (-320,576), finish (-180,672), which
crosses the forest/meadow neighbourhood and the x=-192 chunk boundary. Inspect
the actual weights and settled ground before accepting it as meadow evidence.
Use Jade (-1632,480) with unfrozen `--orbit` for the other outstanding live biome.

The prior goal turn made progress (camera-flight implementation and inspected
spatial evidence). Current highland **61617**, amber **66478** and test suite
**94766** have all been confirmed live by their session handles. Amber has five
chunks built; highland has begun committing chunks. Memory was 36% free at the
last check, so do not start the next heavy capture until one exits. Project native
viewport is 1920x1080; final performance checks should include that resolution,
not rely only on the earlier 1280x720 timings.

### Highland and amber production review

Highland **61617** and amber **66478** both exited 0. Highland is a pure highland
sample at (384,672): 132 dressing batches / 835 instances / 159 colliders and
7710 visible grass instances. Amber: 112 batches / 1465 instances / 77 colliders,
5651 visible grass instances. Saved originals in `captures/*-current.png`.

Highland's original ambient 0.70 / sun 1.45 washed out its pale foreground.
Lower fill alone was subtle; adopted ambient **0.48** and sun **1.15**, keeping
the sky and light colours. Amber ambient changed from `cab6a1` / 0.55 to
**`94a5bd` / 0.42**, retaining warm sun and golden sky. These are restrained
adjustments, not a new palette. Water's lighting gain follows the production
profile changes automatically.

Sequential native replays **80369** exited 0 for both refined profiles. Inspected
matched start views and 45/90-degree orbit views: highland retains its pale blue
grass with readable slope/shadow variation; amber keeps its golden grass and
orange trees with more subdued shaded regions. Saved `captures/highland-refined*`
and `captures/amber-refined*`, including scene metadata. Frozen replay continues
to emit the known absolute-node-path and shutdown resource diagnostics; these are
not represented as fixed or as production-runtime errors.

Focused post-adjustment run **77106** exited 0: atmosphere director, biome registry
and lighting water, **13/13 tests, 106 assertions**. Log:
`/tmp/story-lighting/refined-profiles-tests.log`.

Live boundary run **4987** now starts at (-320,576) and ends at (-180,672), with
unfrozen shaders/water and the new destination readiness check. Log/output prefix
`/tmp/story-lighting/boundary-live`. Jade run **54753** at (-1632,480) uses unfrozen
`--orbit` and saves a production snapshot; prefix `/tmp/story-lighting/jade-current`.
Both remain live in terrain planning. Full isolated suite **94766** remains live,
through September 27 files at last inspection. Do not benchmark concurrently with
these terrain jobs. The two new runs started before/during the highland/amber
profile edit, so use recorded weights to determine whether a final replay is needed.

### Native-resolution performance and rejected scaling experiment

Measured current corrected forest and refined highland snapshots at 1920x1080,
Apple M1 Pro / Metal Forward+, with this task's two live render jobs and isolated
test process group suspended only for the measurements. Cleanup traps resumed all
three; `ps` verified running/sleeping (not stopped) states afterward. Benchmark
**94129** exited 0. These are frozen nine-chunk render-throughput measurements,
not full simulation/streaming FPS or a 49-chunk gameplay budget.

| Scene | Tier | Median frame ms | p95 ms |
| --- | --- | ---: | ---: |
| Forest | Economical | 17.607 | 18.464 |
| Forest | Standard | 22.106 | 23.997 |
| Forest | High | 25.772 | 27.055 |
| Highland | Economical | 28.800 | 30.162 |
| Highland | Standard | 36.452 | 38.526 |
| Highland | High | 43.419 | 51.621 |

All six intervals had zero forced draws and valid frame timing. GPU timestamps
were unavailable. Source JSON/images: `captures/*1080-q[012].*`. Forest q0/q1
images inspected: economical retains palette and readability but loses local mist
and has coarser foliage edges. Dense highland grass is materially more expensive
than the original wet forest view; do not generalize the latter's timings.

Added replay-only `--render-scale` using Godot's documented
[FSR 1 viewport scaling](https://docs.godotengine.org/en/4.5/classes/class_viewport.html#enum-viewport-scaling3dmode).
Benchmark **72673** exited 0: highland Economical at 75% scale = 24.340/26.419ms
median/p95; 85% = 26.513/29.191ms. Both timing intervals valid. The 75% image loses
fine grass/roof detail for a limited gain; **neither scale is adopted in production**.
Artifacts `captures/highland-fsr-*`.

Replay-only `--grass-fraction 0.65` is now measuring the same highland view at
native resolution, using the existing stable multimesh prefix, to test whether
reducing grass draw count is a better economical-tier option. No production grass
density has changed. The command again resumes task-owned groups automatically;
inspect the live benchmark session before further measurements or claiming a win.

Grass-prefix experiment **12572** exited 0: native 1080p / Economical with 65%
of existing visible grass instances measured **24.759ms median / 26.010ms p95**,
zero forced draws, valid timing. The inspected image retains sharper terrain,
character and roof detail than 75% FSR, at similar throughput, while the grass
carpet is visibly less dense. This is a possible **Economical-only** tradeoff;
production still draws full density on every tier. Before adopting it, route the
scale through GrassStreamer (including newly committed tiles and restoration on
quality changes), test stable buffers/count restoration, and inspect motion.
Artifacts `captures/highland-grass65.*`. All three task-owned process groups were
confirmed resumed after both experiments. Live jobs remain boundary **4987**,
jade **54753**, full suite **94766**; no intentional suspensions remain.

### Live jade/boundary acceptance and economical grass integration

Jade **54753** and boundary **4987** both exited 0. Jade is pure jade_wetlands:
212 dressing batches / 1855 instances / 242 colliders, 8315 visible grass instances.
Inspected live initial/45/90-degree views with unfrozen shader time: teal haze,
canopy shadows, grassy slopes and distant water remain readable. Saved
`captures/jade-current*`. This run includes real water/grass animation, unlike the
earlier frozen snapshot orbits.

Boundary travel ran from (-320,576), 100% forest, through a 64% forest / 36% meadow
sample at (-270.54,609.92), to (-180,672), about 94% meadow / 6% twilight before
settling. Inspected intermediate frames 360/720/960 and the settled image. Meadow
grass is present on the dry banks, the sky/water grade changes gradually, and the
grass queue grows from 1916 to 6894 visible instances as the observer travels.
Crossing x=-192 temporarily leaves six committed chunks; the harness waits for
the actual destination's full nine before the settled image. No obvious colour
seam or abrupt lighting switch is visible in the sampled frames. Saved
`captures/boundary-live-live*`. This is scripted observer travel with live gravity,
water and streaming, not a walkability test.

Adopted **65% grass draw density only for Economical**. GrassStreamer updates the
stable multimesh prefix in place; newly committed tiles inherit the setting and
switching back restores the current full-density LOD. The grass vertex shader
uses the same density multiplier, retaining smooth distance fading instead of
letting CPU removal outrun shader fade. Worker payloads, buffers, placement and
Standard/High density stay unchanged. Director handles grass created after its
initial grade. Snapshots record the scale and replays account for the saved scale.

Red-first test **31813** failed on the missing reversible density control. Green
headless **89144**: 13/13 tests, 88 assertions. Native **40343**: grass streamer,
director and snapshot suites, **16/16 tests, 116 assertions, exit 0**. These verify
new commits, moving LOD, quality restoration, stable GPU resource identity and
unchanged deterministic payloads. The first attempted filtered red command selected
a script name incorrectly and ran no tests; it is not counted as evidence.

Final native 1080p Economical highland **32888** exited 0, **24.585ms median /
26.345ms p95**, valid timing and zero forced draws during measurement. Inspected
45/90-degree views: thinner grass is the intended low-tier tradeoff, with coherent
ground colour/fade and no obvious new ring. Saved `captures/highland-economical-final*`.
The isolated test group was automatically resumed and verified non-stopped. It is
the only remaining intentional long job (**94766**, process group **68026**).


### Final regression audit and forest scattering experiments

Current/baseline four-file comparison (sessions 4614 / 22455) both exited 1 with
17 tests, 11 passing, 6 failing, 103/115 assertions. Extracted failure and script-error
diagnostics matched exactly: September 16 immersion lacks the historical P10
`samplers.bin` fixture (its actual UnderwaterView test passes); September 10 grass
sampling reads the retired terrain-grades array; September 11 camera roles has
headless mouse/hat failures; loading-screen progress differs from its old oracle.
Logs: `/tmp/story-lighting/audit-current.log`, `audit-baseline.log`.

Baseline field-streamer comparison 24997 also failed the cold worker-payload wait.
It additionally failed the background ring timeout and reported stale resource
UIDs, so its 12/17 result is not an exact suite parity comparison with current
16/17. It does establish that the worker timeout predates these shader changes.
No terrain assertions were relaxed.

Forest upper-layer weight x3 (sessions 56302 / 40355) added general haze without
convincing stronger beams; rejected. Current production mist remains 4.5 m lower,
30 m upper, weight 0.24. A low sun-facing diagnostic with simple canopy gaps
(session 10856, `shafts-study.png`) and scattering-only x3.64 (44267) shows subtle
volumetric shadowing. Production replay 99236 (scattering 8) reveals broad lit
pockets under the trees but washes distant slopes. This remains an experiment,
not an adopted profile. Relocated snapshot views lack the original grass ring;
they diagnose lighting only. Canopy-gap harness flag `--shafts` and replay/study
`--sun-scattering` allow this comparison without changing production settings.

Scattering 4.4 in the original grass-covered forest view (11354, exit 0) was
inspected at start/45/90 degrees against the accepted Standard view. It brightens
the upper mist but does not deliver a decisive beam improvement. **Rejected both
4.4 and 8; keep 2.2.** The current style supplies soft, view-dependent scattering;
strong cinematic canopy beams are not yet an accepted result. Saved diagnostic
images under `captures/shafts-*`, `forest-scatter*`, `forest-low-shafts-*`.

Reviewed the production diff for underwater environment ownership, linear colour
handling, density restoration, numeric map channels and worker/main-thread
separation; no additional defect identified. `git diff --check` passes.
Full isolated run remains live in process group 68026; other Godot jobs visible
on the machine belong to other work and were not touched.


### Thin-mist renderer cutoff: root cause and native regression

The sun-aligned wisp prototype (40177 / 29869, both exit 0) did not improve beam
readability enough to justify its additional noise evaluation. Removed it from
the runtime shader; retained `rejected-sun-wisps.gdshader.txt` as experiment evidence.

A low-density/high-scattering test exposed the actual engine limit: at 2% local
density, changing volumetric sunlight from 250 to 10000 still produced no visible
mist. Godot 4.5.1's [local-fog integration source](https://raw.githubusercontent.com/godotengine/godot/4.5.1-stable/servers/rendering/renderer_rd/shaders/environment/volumetric_fog.glsl)
discards density <= .001 and packs surviving density at 1/1024 precision. It also
multiplies shader EMISSION by density. Much of our upper layer was discarded,
and our prior emission expression multiplied density twice.

Candidate correction stochastically rounds density onto 2/1024 increments using
fine world-space noise, preserving the intended mean thin-medium density. Engine
froxel jitter/filtering/reprojection integrate the samples. Emission now supplies
radiance without an extra density factor. The candidate defaults on but still has
`review_precision` / `review_density` comparison controls pending acceptance.

Native regression `test_biome_mist_precision.gd` renders the actual shader in an
isolated Forward+ viewport with no other visible content. Red 71493: measured
brightness exactly 0, failed 1/1. Green 54373: 1/1 passed, exit 0. This is rendered
pixel evidence, not a source-text assertion. An additional no-external-light
emission assertion has been added and still needs its native run.

Production forest comparison 38935 and thin-medium comparison 37002 exited 0;
inspected 45/90-degree views, no obvious grain in the sampled images. This is not
yet a full motion/performance acceptance. Seven-biome corrected-shader sweep is
running as 82970; broad isolated tests remain 94766. Current profile constants
remain unchanged; high scattering values were only harness overrides.


### Accepted precision correction and measured cost

Seven-biome sweep 82970 exited 0. Inspected all seven corrected captures; no
palette regression or visible grain in these samples. Meadow's old origin replay
is still a flooded view, not a new dry-meadow acceptance. Prior live dry-bank
coverage remains the grass evidence. Isotropic scattering trial 83335 supplied
no clear improvement; retained anisotropy 0.45 and all existing profile constants.

Native 39469 passed the scattering + emission checks (1 test / 2 assertions).
Native 92789 added camera travel and passed all 3 assertions: thin medium remains
visible, broad brightness variation stays under 0.03 during travel, and emitted
fog remains visible with external fog lighting disabled. Both exited 0.

Matched native 1080p forest / Standard benchmark 56998 exited 0:
- Previous density/emission integration: 22.034ms median / 23.700ms p95.
- Corrected integration: 22.142ms median / 24.015ms p95.
Both have zero forced draws and valid frame timing; GPU timestamps unavailable.
The 0.108ms median difference is small enough to retain the correctness fix.
Inspected the corrected 45-degree orbit for visible grain/trails; none obvious in
the sampled frame. This does not replace a complete video or gameplay benchmark.
Task-owned test group 68026 automatically resumed and was verified running.

**Adopted the precision and emission correction.** The legacy path now requires
explicit `--mist-density 1 --legacy-mist` in the replay harness. Normal scenes use
the correction by default. Final native test after this comparison-flag cleanup
is running; no profile tuning or extra sun-aligned noise octave was adopted.
Sun-facing production-canopy probe 57470 exited 0 and shows soft lit mist around
the tree; it does not establish strong narrow cinematic beams. That visual item
and the broad isolated test audit remain open.

Final native 72490 exited 0: 1/1 test, 3/3 assertions after comparison-switch cleanup. `git diff --check` passes. Broad suite 94766 was polled and remains live, through traversal-envelope tests. This goal turn made progress by fixing and graphically verifying the renderer cutoff/emission defect.


### Canopy light gaps: production integration under review

Previous goal turn made progress: precision-aware mist and emission correction
passed its final native render test. This turn checked fog resolution (128 grid,
96 m range; 3802) and ambient fog fill (zero ambient / scattering 4.4; 68746).
Both exited 0 but neither produced enough improvement to adopt their settings.

Solid low-poly tree crowns produce broad occlusion. A shadow-only porous-leaf
prototype (26700, 43 batches, exit 0) visibly breaks those slabs into dappled light
without perforating the visible mesh. Reviewed initial/45/90-degree views.

Integrated `CanopyShadows` into EnvironmentCommitQueue: the shadow child shares
its parent's existing MultiMesh, has an identity transform and dies/hides with
its parent. The original casts no second shadow. Only canonical canopy materials
qualify; atlas bark remains opaque. The shadow-only child is excluded from camera
visibility adaptation because it cannot obstruct the image. Forest weight from
the canonical 48 m biome field moves the hole threshold continuously; Standard /
High enable the pattern, Economical retains solid shadows. A shared sun-direction
global aligns the pattern, and snapshots preserve both direction and quality.

Red 37041: 1/2 tests passed, missing proxy failed as expected. First red 44902 ran
no tests because the new class was not imported; fixed via explicit preload and
do not count that attempt. Green headless 66433: 12/12, 69 assertions. Native
24351: 16/16, 105 assertions, exit 0 across proxy, actual commit queue, director,
snapshot and fog suites. Native 97789: 3/3, 16 assertions including rendered-pixel
verification that forest gaps admit more sunlight, intermediate weights do not
darken it, and Economical restores the original solid-crown shadow.

Production-helper forest orbit 97715 exited 0 and matches the successful
prototype. It improves dappled illumination; narrower aerial shafts still need
their final visual decision. Matched 1080p original-camera cost comparison is
running as 76978 (solid vs porous), with task-owned suite group 68026 temporarily
suspended and an automatic resume trap. Do not mark performance accepted until
that session exits and its JSON/image evidence is inspected.


Canopy benchmark 76978 exited 0, both intervals valid with zero forced draws:
solid = **22.716 / 24.074ms**, porous = **23.179 / 24.631ms** median/p95 at 1080p.
Inspected the normal-camera 45-degree view; the ground/grass/water remain coherent.
Task-owned isolated suite was verified resumed. Adopted the canopy detail at this
roughly 0.46ms measured median cost. A subsequent shader shortcut skips atlas/noise
work entirely on Economical and outside forest; the active forest pattern is
unchanged. Do not interpret the earlier pair as a separate measurement of that
shortcut. Native final 49926 exited 0: 16/16 tests, 106 assertions including the
quality/biome pixel test, production commit and snapshot checks. Diff check clean.

A fresh live nine-chunk dry-forest capture at (-660,539) is now starting, using
current production queue/shaders/grass and a frozen orbit. It is the remaining
landscape acceptance for the new shadow representation, beyond the relocated
snapshot studies. Broad suite 94766 remains live, past village-reported-ground.


Live dry-forest session is **90508**; its current heartbeat confirms active cold
feature-path planning at (-660,539), seed 2697992464, 0/9 ready. Do not restart it
because the planning phase is slow. Broad isolated session **94766** was polled
and remains live, through warren-maze-carver. Current worktree passes diff check.
This turn made progress: integrated biome/quality-gated canopy light gaps,
verified actual queue ownership and rendered gating, and measured their cost.
Remaining acceptance is the fresh live woodland capture, the broad-suite final
classification, and the final scope audit. No scene/code edits have been made
since the live capture was launched; it includes the optimized shadow shader.


### Completion audit (updated after live woodland acceptance)

Both worktrees still have HEAD `f4d9b972ce996dc7bca37d20fa2868f0add559d2`.
Remaining grass-lip comparison: current 76337 and baseline 69739 both exited 1,
0/2 passing, 7/1016 assertions. All 2018 emitted failure-diagnostic lines matched
exactly (GUT repeats diagnostics in its summary). These are retired native-lip
geometry assertions, not grass shading regressions. Logs: `grass-lip-current.log`
and `grass-lip-baseline.log` under `/tmp/story-lighting/`.

| Requirement | Authoritative evidence / current finding |
| --- | --- |
| Better shared lighting, form and material response | Director, shared surface include, native material studies and seven production captures; implemented and visually reviewed. |
| Distinct seven-biome lighting/fog/glow | Registry profiles, spatial fields, seven-biome corrected-shader sweep 82970; reviewed; latest forest canopy addition accepted in live session 90508. |
| Forest rays and canopy illumination | Real shadowed scattering, precision regression 72490, porous crown integration and native pixel tests 97789/49926; dappled light verified in fresh woodland session 90508; strong narrow aerial shafts are not claimed. |
| Fog continuity and water-relative placement | Field/shared-edge tests, scrolling-map tests, 169 water-datum checks, live boundary capture 4987; new density encoding uses world coordinates, not chunk coordinates. |
| Water/underwater follow biome mood | Lighting-water/native immersion checks and Moonfen before/after captures; no daylight-bright water retained in twilight. |
| Performance and scalable quality | Native 1080p tier comparisons; Economical reversible grass prefix; fixed-point correction ~0.11ms, canopy detail ~0.46ms measured median deltas. GPU timestamps unavailable; frozen throughput is not live-game FPS. |
| Streaming and camera behavior | Live jade/boundary accepted; current queue/proxy ownership and quality tests pass; new dry woodland session 90508 accepted. |
| Sky-background research | Three-store shortlist and hybrid painted-cloud recommendation above; no purchase or integration was requested. |
| Regression checks | Relevant headless/native suites pass. Nearby broad-suite failures reproduced on baseline; full isolated session 94766 still running, so no whole-suite pass claim. |

Visual acceptance is complete. The broad isolated suite remains running.
No terrain geometry or unrelated failing assertions were changed to obtain these
results. The compact controls/biome guide at the top now distinguishes current
settings from the historical experiment log.


### Final live woodland acceptance

Session 90508 exited 0. The fresh production nine-chunk capture at (-660,539),
seed 2697992464, is 100% Lanternwood, Standard quality, 1280×720. It contains
152 dressing batches / 2012 instances / 276 collision shapes and 10434 committed
grass instances (9411 visible). Inspected the initial image and orbit frames
090 and 180: grass follows the terrain, dappled illumination is visible, and
shadows remain aligned as the camera turns. The new shadow proxy does not
introduce visible duplicate geometry or camera obstruction. PNG/JSON evidence
is saved under `captures/forest-dry-live*`.

The snapshot serializer emits three known out-of-tree absolute get_node errors;
these precede the successful snapshot save and do not indicate shader compilation
failure. The idle-draw watchdog fired four times, so this capture is visual
evidence only, not performance evidence. No new shader error appeared.

Accepted forest appearance is soft shadowed mist and dappled canopy light. Strong,
narrow aerial shafts were not demonstrated at the normal gameplay camera and
are not claimed as a delivered visual result. More scattering was rejected
because it washed out the scene. The broad isolated suite is the only remaining
verification job.


### Broad-suite time bound

`test_water_plan.gd` remained CPU-bound for more than 15 minutes after the prior
343 files completed. Stopped only its verified task-owned PID 531 (PGID 68026)
with SIGTERM so the remaining isolated files could run. This file is **incomplete**,
not passing: the wrapper writes `tests=? pass=? fail=0 script_errors=0` when a
process stops before GUT's summary. Do not interpret that zero failure field as
a pass. No assertions or terrain code were changed. The separate focused water
lighting and native rendering checks have already passed.


### Final disposition

The shader implementation and its required focused/visual acceptance are complete.
The optional wider audit was bounded rather than extending this lighting task
into procedural-water maintenance. Session 94766 exited 143 after the verified
task-owned group was stopped. `test_water_plan.gd` and the active
`test_water_production_seams.gd` are incomplete. Subsequent tail files were not
reached by this run; water-shader and world-lighting checks had separately passed
the earlier focused suite. The newly added fog/canopy/snapshot tests also passed
separate native runs and were not in the broad runner's original file glob.

Broad audit: 343 files with GUT summaries; 1832 reported tests, 1686 reported passes, 118 reported failures, 24 script-error lines. 71 files report failures or script errors. Missing pass fields/headless pending cases prevent interpreting the residual as a precise skipped-test count. These are partial totals, not a complete-suite success claim.

The nearby failures investigated against the identical baseline are documented
above. Other terrain/town failures were not exhaustively classified. No terrain
geometry or unrelated assertions were changed. All task-owned review/test jobs
are now stopped or exited; no commit or PR was created. Final diff check passes.

Delivered visual direction: shared filmic lighting and softened shadows; seven
blended biome grades; layered water-relative mist; forest dapple; restrained glow;
foliage transmission and damp surface response; coordinated water/underwater
lighting; three quality tiers. Sky-store research remains a recommendation, with
painted cloud layers over the procedural biome gradient the preferred next step.
