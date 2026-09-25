# Partial black-screen investigation

The photographed game rectangle (x12,y149,width3432,height1931) is 64.288% near
black. Its strongest straight discontinuities align at x896/1024/1792/3072 and
y512/640/1024, all multiples of 128 pixels. This is consistent with a tiled
rendering failure, but does not isolate a particular renderer subsystem.

The first stress harness needed an explicit Image type on its duplicated probe;
that parse-error launch produced no evidence. The corrected 1920x1080 snapshot
run completes 540 sampled frames / three orbits with no partial or whole-black
samples. The grass-bearing 3432x1930 snapshot completes 1,080 sampled frames /
six orbits with none. A small diagnostic text overlay is rendered in the target,
as in the owner's screenshot. The snapshot contains 32 lights and 493 geometry
instances. The first two runs use the issue-1 comparison adapter, whose inherited
broad phase now includes low ground. Subsequent runs use the complete archived
pre-review adapter with only class registration/include paths changed, avoiding
that inherited difference.

A live high-resolution run is now testing dynamic field/grass/lighting ownership,
rapid orbits, slight player-position jitter and alternating camera distances.
No production fix or acceptance is recorded. The upstream cluster issue is a
candidate cause only; disabling local lights/effects remains a diagnostic control.

The live run also remains clean through its first 540 frames. Per-frame image
readback forces GPU synchronization and may hide a rendering race; the next
pass leaves fourteen rendered frames between readbacks. This changes only the
diagnostic sampling schedule. No speculative renderer/configuration fix has
been made. The current editor is no longer running, so its exact build could
not be recovered from a live process; the runner is Godot 4.5.1 Metal Forward+.

Native-window Metal and Vulkan each complete 1,800 stress ticks (120 sparse
readbacks) without partial corruption. Four corresponding image pairs have mean
RGB differences of 0.00355–0.00496/255 and only 0.00471–0.00583% of pixels changing
over 20 levels. The pairs were visually inspected. This establishes close
renderer agreement for these frames, not a repair or an engine-driver cause.

Sparse offscreen and some native runs produce wholly black readbacks, including
the diagnostic text. Keep these separate from the owner's partial corruption.
Ordinary redraw attempts also stalled while the native window was occluded;
one-second process sampling found the main loop sleeping rather than blocked in
a rendering resource call. Keeping the verification window above other windows
allowed ordinary redraws. A nine-chunk live pass with nine actual FogVolumes
completes 1,800 ticks, 120 sparse samples, with 16 wholly black readbacks and no
partial sample. Frozen snapshots previously omitted FogVolumes; the snapshot
helper now includes them, and the new mist-bearing snapshots are separate files.

The full gameplay radius changes the diagnostic population materially: 49 fog
volumes, 170 lights and 2,584 geometry instances, versus 9/32/493 in the focused
live pass. It catches a transient black foreground garden at tick 1,920, affecting
6.414% of the coarse sampled image while text and adjacent buildings remain
visible. The unchanged-camera hold clears it before any lighting/effect toggle.
Consequently none of the later fog/glow/SSAO/light/bubble controls establishes
causality. This is a real partial black render, but its mesh-shaped footprint is
not yet the owner's extensive tiled pattern. Do not call issue 4 fixed.

An every-frame GPU diagnostic now reads the HDR scene before tonemapping without
modifying it. It transfers a small classification/preview buffer asynchronously,
with the actual render camera transform. Native calibration against white,
half-black, then white surfaces returns exactly 0/4,608/0 black samples out of
9,216, with zero invalid samples. This reduces the chance of missing transient
failures between synchronous screenshots. HDR previews have a diagnostic tone
curve and are not substitutes for the final game-image colour comparisons.

The first full-snapshot GPU route completes 3,601 consecutive rendered-frame
results. Frame 481 has 9,210 black samples out of 9,216, no nonfinite samples,
and six surviving bright samples. Its asynchronous HDR preview and actual
camera transform are preserved in `gpu-original`. All other frames are clean.
This is a stronger timing diagnostic than the sparse final-image samples; it
still does not isolate the cause or reproduce the owner's particular tile mask.
The initial progress update overlooked that early anomaly; the completion audit
and subsequent update correct it explicitly.

Apple Metal API plus shader validation was attempted. Shader instrumentation
spent over four minutes compiling the engine's sky pipeline before reaching the
test. A process sample located that compiler wait, and only the owned process
was terminated. The API-only validation then completes 1,440 stress ticks with
no validation error or partial black sample. It does not exonerate GPU shader
access: the shader-validation attempt never reached the replay.

The accepted issue-1 adapter, retaining the original small bubble, completes
the identical 3,600-tick route with 3,601 consecutive HDR classifications. Its
maximum is one black sample, zero nonfinite samples, and no anomalous frame.
Every callback also verifies the GPU's summed 9,216-sample completion count.
This supports material reuse as a candidate repair, but a single intermittent
baseline failure is insufficient to isolate it. A 7,200-tick archived-adapter
repeat is testing that explanation before acceptance. No additional production
change is made for issue 4 at this point.

The archived repeat finishes with 7,201 consecutive HDR results. It does not
repeat the near-black frame, but records six nonfinite patches: frames
5,357–5,360 (12/11/8/5 samples), 6,108 (411), and 6,110 (207). The original
classifier includes alpha, so these results alone do not establish invalid
visible RGB. The updated probe records RGB nonfinites separately. Magenta in
the saved previews is the diagnostic invalid-value marker, not game colour.

The expanded native calibration passes white/half-black/white and 66 rendered
results across all 60 alternating states, using actual render-camera positions
to check asynchronous frame attribution. The first current-adapter launch
stopped in the harness because assigning an untyped Array to its typed preview
list failed; it produced no replay evidence. Changing that assignment to the
typed list's `assign` method allows the replacement run to proceed.

The corrected current-production run completes 7,201 consecutive results,
without black or nonfinite anomalies. Seven HDR preview pairs share exactly
equal recorded camera transforms; all were inspected in `gpu-pairs.png`.
Frame 481's preview difference is 26.419/255 mean RGB. The six other comparisons
exclude magenta invalid-value markers from finite-colour arithmetic. Changes
inside the larger current bubble are expected. These are 128-by-72 HDR previews,
not replacement full-resolution photo comparisons or proof of causality.

Starting the archived route at tick 5,280 changes its rendering history. Its
961 results include 442 anomalous classifications from local frame 519 onward,
but all those previews alternate between two byte-identical images while camera
transforms change. Final viewport readbacks, including UI, are wholly black.
Reject this run as stale/invalid capture evidence: a successful compute counter
does not by itself prove that its input scene texture is current. A QA-only
small HDR frame marker now supplies a second independent frame identity check.

The source adapter also discards before the original shader's implicit texture
derivatives and `fwidth` calls. Nonuniform discard can make subsequent derivatives
undefined ([GLSL 4.60 specification](https://registry.khronos.org/OpenGL/specs/gl/GLSLangSpec.4.60.pdf)). `LateCutout.gd` is an isolated
diagnostic candidate that samples the source first, preserves the original
position/normal used for coverage, and handles source exits before discarding.
It is not a production change or an accepted black-screen repair.

The late-discard candidate's 961-frame short run has no black or nonfinite
classifications. Five full-resolution pairs share exact cameras at ticks
5,400/5,580/5,760/5,940/6,120. Visual inspection finds preserved native surfaces
and coverage. Mean differences are 0.182–0.472/255; 0.0071–0.0257% of pixels
change over 20 levels (the QA marker corner excluded). Different fog/animation
histories remain, so these differences do not isolate derivative behaviour.
`late-pairs.png/json` retain the comparison. No failing current-adapter frame
was reproduced, so this candidate has not earned production acceptance.

The first marker attempt used the wrong clip-space Y sign: it rendered at the
bottom-left while the probe sampled the top-left. Its reported tag mismatches
are therefore invalid diagnostics, not evidence of stale frames. A calibration
capture locates that marker, the corrected sign places it in the sampled corner,
and all nine boundary/route tags (0,1,31,32,1023,1024,5280,6239,32767) decode
exactly. The same run passes 77 rendered temporal checks across all 60 alternating
states. The corrected marker is now being tested on the actual archived route.

The marked archived short route completes 961 frames with no black/nonfinite
anomaly. 957 markers match the exact serialized camera key; four camera keys
are unmapped, rather than mismatched, because that lookup uses rounded transform
strings. All 961 marker values follow the expected tick sequence. Do not credit
the four unmapped rows as an independent exact-pose validation.

The original photo uses the editor's embedded Game view. Standalone native
windows do not test that presentation path. An owned editor opens the QA scene,
but automation clicks/keys in its Godot-drawn toolbar do not start it, while
native menus work. A process sample shows the main loop running with ordinary
frame-delay sleeps, not a compiler deadlock. A temporary EditorPlugin supplies
a native Project > Tools replay command calling `EditorInterface.play_custom_scene`.
The first attempted `override.cfg` is ignored by editor-mode setup; its settings
were moved temporarily into project.godot with an exact backup and expected hash.
They must be removed after this owned editor test. No embedded result exists yet.


## Embedded reproduction with verified frame identity

The first embedded original-adapter run reproduces the failure. Fresh GPU
frames 532/533 carry the correct scene markers for ticks 531/532. Of 9,216
samples, 7,762 and 6,606 are black; the second also has 2,598 nonfinite RGB
samples. The native Game window is visibly black while its editor toolbar
remains visible. Subsequent readbacks alternate the two frozen buffers and
are excluded from camera comparisons. `embedded-first-failure/manifest.json`
preserves SHA-256 hashes of the two previews, verified rows, log and later
whole-black viewport captures. The previews are HDR diagnostics; magenta marks
invalid values and is not actual game colour.

A second embedded original run completes 3,601 GPU frames without black or
nonfinite samples. Its completed numeric results are copied to
`embedded-original-repeat/`. This confirms intermittency. Rounded camera-string
lookup has 32 nonmatching/unmapped tags; these are not 32 corruption events.

The editor caches its run arguments: setting ProjectSettings from an already
loaded plugin did not change the launched command. A third original launch
is stopped without counting it as current. The on-disk arguments and editor
reload finally launch the current adapter; its `launch.json` and inspected
process command both confirm the adapter, separate output path, embedded mode,
and Godot 4.5.1 Metal Forward+. No effects or lights are disabled.


The verified current embedded run completes 3,601 frames; a separate 1,081-frame
repeat also passes. Both have exact expected marker sequences, zero nonfinite
RGB values and at most one black sample of 9,216. The two original fresh failure
poses match exactly in the repeat (camera string and scene marker), with zero
black/nonfinite samples at either pose. Both full-resolution current viewport
images are visually sound. `embedded-failure-pairs.png/json` show the diagnostic
pixel differences; invalid magenta samples are excluded from finite colour means.

The 32 baseline-repeat camera lookup failures all have expected_tick=-1; none
is a known mismatched pose. Independently, all 3,601 markers follow the exact
route tick sequence. The marker gate distinguishes these rounded-key lookup
limitations from stale buffers.

A fresh 12-pair photo replay covers all four pins and +/-8 degrees, using the
complete original adapter and current implementation in the full village
snapshot. All 24 images are valid; at most three pixels per 1920x1080 image
are below RGB 3. All three contact sheets and differences are judged. The
visible changes are the accepted larger bubble, with native geometry retained.
The static original poses do not reproduce its intermittent fault. Native
resource/render checks pass 13 tests / 143 assertions, exit zero.

No separate renderer/effect change is accepted. The earlier issue-1 resource
ownership repair removes buffer/mesh copies and repeated shader/material churn,
and the repaired implementation passes the measured corruption replays. This
is scoped behavioural acceptance, not proof that an upstream Metal defect is
fixed or that every possible intermittent GPU failure has been eliminated.

The owned editor is closed. The temporary run settings and plugin enablement
are removed by restoring the exact pre-test project.godot bytes; SHA-256 is
recorded in validation.json. No user project setting is changed for issue 4.
