# Roof extent and alignment — in progress

Photo 14, seed 2697992464. The same frozen town as issue 7 reproduces the
reported roofs. The main foreground gable belongs to `spatial.maze_back.03.room00`.
Its actual roof envelope covers the complete 6 m world footprint, but the
plaster gable is about 1.0 local metres from the ridge midpoint instead of the
wall's 1.5 m boundary. The roof's projecting ridge tip had determined the end
registration. This leaves a large exposed ledge despite a correct bounding box.

Alternatives considered: change whole-roof translation, allow ordinary end
projections, or fit the measured internal gable datum inside the existing end
stock. Translation moves the shared seam; unrestricted projections can collide
with neighboring reserved roofs. The candidate fits the native end's internal
bearing while preserving its outer boundary and party seam. It changes only
longitudinal coordinates, retaining the native transverse section, height,
triangles and UVs. No new texture or cover strip is introduced.

The initial actual-native-gable regression fails all 72 samples, across both
material families and both end hands, for full and half terminal sections.
The selected eight tight end assets receive a manifest-owned monotonic axis
profile. Their gable is fitted to 1.48 m, inside the wall's final 5 cm, while the
outer boundary stays at 1.5 m and the inner seam stays at zero. The current
candidate must still pass visual review; a thinner end ornament is a possible
tradeoff that needs direct inspection.

Baseline: six full-game views in `before`, and `native-before.png`. The matching
camera uses ReviewCam from rounded player/crosshair pins, not a recoverable exact
original camera. Other roofs are not yet accepted by this record.

The first candidate native image removes the large gable ledge. All 72 gable samples now pass, alongside 16 existing roof tests (17 tests / 55,169 assertions total). All eight changed assets retain the original triangle stream, X/Y coordinates, UVs and exact seam/outer boundaries; no triangle is degenerate. The paired actual-collision surveys are identical across 132 cells and 188 crossings. Native rear/upper seam views and final full-game pairs remain pending.

The first full-game candidate fixed the foreground gable but left the second,
smaller circled roof unchanged. Its partial roof cells are replaced by a
continuous roof. That join expanded the original end boundaries by about
1.16 m in world space at each end. The second regression freezes this actual
component and fails both longitudinal bounds. Selecting the existing bounded
end alternative alone would expose another inset gable; all 12 short-range
native ray samples fail on its four material/end variants.

Candidate two carries the original partial-gable boundary into the continuous
roof assembly, selecting its existing flush end alternatives. Complete roofs
retain their ordinary eaves. Four tight flush assets also fit their internal
gable datum to 1.48 m, preserving their 0.75 m inner seam and 1.5 m outer end.
The profile operation follows the existing visual-bounds fit. All twelve
changed assets preserve actual triangles, X/Y, UVs, seams and outer boundaries,
with no degenerate triangles. Final visual and physical checks are pending.

`candidate1` and `candidate1-diff` retain the rejected first full-game pass;
`native-after-candidate1` and `native-diff-candidate1` retain its native views.
The original native-array snapshot contains twelve assets. Its cache-only
replay option restores geometry but does not undo candidate two's continuous
roof selection, so the original saved before images are the authoritative
visual baseline.
