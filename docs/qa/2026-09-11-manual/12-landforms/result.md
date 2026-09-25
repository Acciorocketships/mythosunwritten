# Biome terrain, connected water landforms, and natural arches

Accepted for the implemented terrain vocabulary, inspected sites and measured
regressions. The fixed 32 m ceiling is replaced by biome-owned relief with a
128 m range and 32 storeys. The existing 4 m storeys and three-storey neighbor
step remain. This deliberately changes generated terrain and settlement locations;
it is not a promise that the old screenshot town remains at its old coordinates.

## What changed

Seven continuously blended profiles choose coherent 768 m geological provinces.
Highlands favor linked mountain peaks, ridgelines, passes and hanging valleys;
heath favors mesas, escarpments and clefts; forests and blossom terrain favor
bowls, sheltered hollows and terraced valleys. Meadows and wet biomes retain
lower relief. Wet gentle reaches can widen into alluvial fans with low retained
bars and water on both sides. Receiving lakes share their island/peninsula
reservations with their own incoming river, preventing it from excavating that
land away. Finite inlet/rim fitting rejects lake-land proposals that do not fit.

Natural overhead arches use a separate solid terrain volume because an ordinary
heightfield cannot represent an opening beneath rock. Complete opposite native
terrain bearings, clear central air and a reserved footprint precede emission.
The faceted arch has closed ends and matching actual triangle collision.

The larger height range also exposed three compatibility defects. Water source
thresholds now retain their physical elevations instead of scaling upward with
amplitude. Connected-water relaxation compares the exact stored float32 ceiling,
so rounding cannot endlessly requeue an unchanged value. Empty vertical intervals
from deeply buried water rims no longer create inverted swimming trigger boxes.
These repairs do not change the water mesh to hide a physics failure.

A complete neighborhood made entirely of native prefabs can now finish the same
parcel/room/support pipeline with zero modular rooms. Its native source ownership
and real lower bearings remain mandatory; an entirely empty or counterfeit town
is still rejected. The photographed floating-grass and isolated-tower rules from
[issue 10](../10-unified-city/result.md) remain in that common pipeline.

Steep moving interior water gains bounded light scattering from its existing
hydraulic head-loss and current. The face slope is measured along that current
and is invariant under two-sided normal reversal. Near-shore closure, stationary
water and flat surfaces do not gain this scattering. Ordinary refraction, waves,
ripples, geometry and swimming remain unchanged. Two material candidates were
rejected before the final one; no scrolling streak texture or separate fall mesh
was introduced.

## Rendered judging

All comparisons use actual Godot geometry and recorded/reconstructed matching
cameras. Pixel differences supplement visual and physical checks; they do not
alone establish a repair.

- Ninety landmark pairs cover ten forms at normal, broad and lower silhouette
  cameras. Changed pixels above 20 RGB levels occupy 2.68–18.93%, 1.30–7.35%
  and 2.21–22.57% respectively. Mountains, mesas, passes and clefts are clearly
  stronger. Forest amphitheatres, hollows and terrace valleys remain subtler.
  See [normal](landmark-differences), [broad](landmark-broad-differences),
  [lower](landmark-low-differences), and [camera sites](landmarks.json).
- Twelve [old-photo height comparisons](height-photo-differences) retain the
  original rounded player/crosshair inputs. New geography can leave the frozen
  player above or below ground; these are geographic context, not player collision
  or visibility-bubble evidence. Original full-precision camera recovery remains
  impossible from the 0.1 m overlay. The architectural repairs have their own
  original-source replays in the earlier issue reports.
- Eight [live alluvial comparisons](delta-low-differences) replace the rejected
  tall bank remnants with low bars and visible side channels; 14.83–23.87% of
  pixels change. Twelve intermediate native bar comparisons also informed judging.
- Eighteen [arch traversal pairs](arch-traversal-differences) show start, middle
  and end of six real-character swims. Each before image hides the arch visual
  at exactly the same pose; its collision stays active throughout. These are
  not pre-change physical-route claims. Earlier slab-like arch candidates were
  rejected. One native and one initial world camera inside terrain are excluded.
- Twelve [lake-reservation repair pairs](lake-repair-differences) compare the
  same new geography before/after shared land ownership. The small land changes
  are supported by physical sampling and [full-world peninsula views](lake-world-overviews).
- Eight [gorge material pairs](gorge-face-scattering/differences) use terrain-checked
  cameras. Exposed falling faces gain contrast; reverse/occluded views are context.
  The greatest changed-pixel fraction is 3.89%. Eight matched [lake controls](lake-scattering-controls/differences)
  have zero pixels changing by more than 20 levels; their whole-frame mean timing
  differences are 0.0235–0.1326 out of 255. The isolated GPU controls are exactly
  unchanged where they should be.
- Eight [native-only town world views](town-world-overviews) show the three
  prefabs and retaining beds seated on actual terrain. Bare-stage native views
  alone were not credited as ground-support evidence.

The final [native lake/gorge recapture](water-landmarks-complete/differences)
adds twelve judged old-geography/current pairs with identical serialized camera
transforms (12/12), no invalid-volume errors and a clean exit. The native lake
water is visually subtle against its bare green bed; the full-world views provide
its appearance evidence. Close gorge occlusion is retained as context.

The fresh [island arrival](island-live) completes in **327.947 seconds** with all
nine startup chunks. Three player views and eight [recorded overviews](island-world-overviews)
are judged: the dry island has water around it; one low angle is partly obscured
by trees. Its 4 m dry center and twelve wet perimeter points are independently
surveyed. The one-time snapshot exporter logs Godot's warning about querying the
global shader parameter list outside the editor; it is not a generation failure
or part of normal gameplay. The overview replay exits cleanly.

## Physical and regression evidence

- [Final related run](final-complete-related.log): **64/64 tests, 10,009 assertions**,
  clean exit, 308.528 seconds. The later [water material run](fall-shader-related.log)
  passes **7/7 tests, 47 assertions**.
- [Actual GPU material probes](fall-material-probe/results.json) and the
  [reverse view](fall-material-probe-reverse/results.json): ten cases pass. The
  moving steep patch changes by 0.322876 normalized mean RGB; the eight stationary,
  flat, transverse-face and near-shore controls change by exactly zero. The
  [baseline probe](fall-material-red.log) fails the missing falling response.
- [Native-only corpus](prefab-only-corpus.json): **48/48** constructed towns;
  **11,868** clear public centers and **17,038** clear crossings. No blocked
  centers/crossings, split public components or unreachable public positions.
  **24 off-center pillar contacts remain.** The fingerprinted [composition gate](prefab-only-gate.log)
  passes **95/95 assertions**, without timing-pin changes.
- The newly admitted native-only source has **76 clear centers / 114 clear
  crossings** against complete actual collision, recorded in
  [its physical survey](native-only-clearance.json). Five recorded production
  sources validate after that construction repair, without a separate outskirts
  pass; this is not an exhaustive survey of all geography.
- [Six alluvial bars](bar-physical-census.json), across three seeds, have dry
  4 m centers and wet channels on both sampled sides over 0 m ground.
- [Six lake-land cases](lake-physical-census.json), across three seeds, pass all
  **63** dry-center/wet-perimeter or flank positions. Three peninsula-to-bank
  lines pass all **39** sampled dry positions in [the connection survey](peninsula-connections.json).
  Dry non-finite water levels are serialized as JSON `null`; raw console values
  remain in their logs.
- Six actual-character arch swims at offsets -2/0/+2 m in both directions pass.
  Five take 366 physics ticks and one 314, each traveling over 20 m. The earlier
  360-tick timeout reached +9.68 m continuously; it is retained as an inadequate
  test deadline, not described as a collision fix.
- The [three-seed joined river census](river-survey-joined.json) has **160 rivers**,
  **11 widened fans**, **15 bars** and **7 fitted lake-land reservations**, of
  which **3 are peninsulas**. The old 31 lake-land proposals were not all physically
  valid. These occurrence counts do not establish every site's physical state.

## Limits

The established 24 m cell vocabulary is visible in large contours and shorelines.
The result adds form and relief; it does not provide smooth naturalistic erosion.
Waterfalls remain broad stylized clear cascades with stronger steep-face contrast;
plunge spray is still unwired. Forest bowls and valleys are restrained rather than
uniformly dramatic. Finite native render patches have visible outer boundaries;
those boundaries are not streaming-void findings.

Cold arrival remains expensive: the measured lake/gorge/arch/native-town runs take
261.286 / 270.426 / 272.884 / 320.957 seconds; the final island takes 327.947 seconds. Some overlap other bounded QA work
and are not isolated benchmarks. The saved fine-water solve now finishes in
1.312 seconds instead of its reproduced endless rounding requeue, but that does
not establish a general startup speedup or long-session streaming acceptance.

Initial negative-volume water captures, cameras inside terrain, and frozen actor
pins below new ground remain excluded from complete physical/visual acceptance.
Historical water/contour, cliff-corner and cold-start failures outside these
focused runs are not claimed fixed. `project.godot` retains SHA-256
`7fc4cfdab9570925f688f0b6a6ff0602c5d8153ad9f536cbb2668593043437e4`.

The full rejected-candidate history is retained in [iterations](iterations.md).
