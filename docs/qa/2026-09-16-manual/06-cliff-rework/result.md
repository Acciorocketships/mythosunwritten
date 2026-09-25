# Connected cliff outcrops — September 16 follow-up

The owner rejected the earlier widened mounds and green steep faces. The replacement uses six original closed rock formations whose upper shoulders enter the native cliff and whose lower terraces are part of the same solid. Gray stone reaches the wall; native turf and ordinary grass occupy the flatter ledges. The original native wall, crown, terrain heights and water exclusions remain authoritative.

The full screenshot inventory and proposed fixes are in [issues.md](../issues.md). This review addresses C01–C04, especially the owner's subsequent correction. It does not close the remaining water, town, streaming or biome-palette issues.

## References and judgment

| Reference | Reported problem | Final inspection |
|---|---|---|
| P20 — 12.09.34 PM | Striped turf and rectangular rock faces | One broad connected shoulder replaces separate upper/lower mounds; coherent grassy benches replace stripes. Gray contact geometry blends into the wall. |
| P17 — 12.09.43 PM | Thin, deep projections and blank wall faces | Outward depth is bounded by available wall width; short native remnants cannot grow narrow outcrops. Lower terraces descend within the same solid. |
| P05 — 12.10.16 PM | Small, sparse vines | Larger trailing clusters retain native alpha cutouts and biome foliage tint. |
| P12 — 12.10.42 PM | Gray strips across intended turf | Turf is assigned to complete flat bench faces. Wider context views verify the junction where the close actor camera obscures the rock. |
| P11 — 12.11.39 PM | Separate, evenly spaced formations | Broad varied shoulders join along the base of the native wall; independent front mounds are removed. |
| P23 — 12.32.18 PM | Highland control; broader palette complaint | Second-biome control for the same geometry/material rules. The separate palette request B01 remains open. |

I rejected the all-green mounds, regular stacked platforms, fully smoothed clay-like forms, fragmented turf patches, and the first three production candidates. [iteration.md](iteration.md) records those failures and the corrective changes. Production 04 is materially better: the cliff reads as joined stone with usable planted ledges, rather than objects placed in front of a wall. The native terrain still has a regular terraced rhythm; this repair does not represent a redesign of that larger landform system.

## Matched visual evidence

Original geometry and current geometry use matched recorded cameras in all twelve P05/P12/P17/P20 comparisons. Feet adjustments are explicitly recorded in [seated-poses.json](production-04/seated-poses.json). Cameras are reconstructed from the photographed coordinates; these are not pixel-identical recreations of the original screenshots.

P20, original geometry:

![Original separate rocks](matched-control-04/P20/P20_0.png)

P20, connected shoulders and planted ledge:

![Connected outcrop](production-04/P20/P20_0.png)

The five fixed inspection cameras in [context-verified](context-verified/poses.json) and [context-original](context-original/poses.json) additionally expose the wall contacts and the connected lower terrace. These are geometry inspection views, not evidence of player support at their decorative actor positions. The first P20 context angle was obscured by a foreground tree and was replaced. The first P12 side camera was inside terrain and is excluded; its replacement provides a limited oblique context, while the P12 front view is the useful wall-contact evidence.

Fresh [P11 wide view](wide-04/P11_0.png), [P17 nearby view](production-04/P17/P17_-8.png), and [P12 wall contact](context-verified/P12_front.png) cover distribution, depth, and attachment. The Highland run also exposed an unintended second fern population when grass support was enabled. Rounded shrubs now retain sole ownership of outcrop ledge planting; the final fresh Highland replay verifies that cleanup.

## Verification

- [20 current focused tests / 677 assertions](tests-current.log) pass: closed outward solids, one connected component per formation, buried upper ridges, gray wall contacts, flat turf, complete native collision, rooted placement, wet/public exclusion, deterministic workers and chunk ownership.
- [Grass follow-up: 3 tests / 8 assertions](grass-final.log) passes. The ordinary worker produced 496 elevated grass roots, zero escaped patch-edge samples and zero roots inside rock. Full/split construction owners produce identical grass buffers. Rounded shrubs retain ledge planting ownership.
- [Twelve actual bidirectional walks](walks-04/walks.json) pass across six sampled exposed ledges, with actual character physics, stable floor heights and zero underside contacts. Production 03 had two blocked walks; the broader final benches provide clear traversals on that same formation as well as the other sampled formations. This is scoped traversal evidence, not a proof that every possible point is walkable.
- The expanded historical terrace-grass run is [22/23 tests, 691/692 assertions](tests-13.log). Its sole failed test reports six pre-existing material UID warnings in the older KayKit terrace assets; no clean full-suite result is claimed.

The outcrops are original meshes exported through the ordinary GLB/catalogue pipeline. Collision uses the same final source triangles. Tests and screenshots are actual native Godot output; no generated image is used as game evidence. Several cold captures ran concurrently, so their startup times do not establish a performance change.

The apparent P11 fin was independently traced to an ambient `kaykit_rock_03_00` instance in [three visual triangle rays](fin-probe/probe.json). It was not an exposed outcrop rear. The broader final rock reservations exclude that ambient placement in the fresh P11 view; no screenshot mask was used.

The [final fresh Highland replay](highland-final/P23_0.png) completed; all three angles were inspected and the unintended dark fern clumps are absent. The [evidence manifest](evidence-manifest.json) hashes 78 source/evidence files and checks 17 camera pairs: equal FOVs and a maximum transform-component difference of 0.000001 from saved-transform reconstruction. The [before/after gallery](review.html) collects the useful native comparisons.

This is scoped verification of the revised outcrops and planting, not owner approval or a claim of perfect landscape art. Broad terrain steps, native cliff repetition and biome palette variation remain visible and separately open. Other issues in the original register remain queued or retain their explicitly limited water results.


## Superseding owner follow-up

The owner rejected remaining flat shelf profiles, the curled-in shelf end, sparse wall coverage, repeated vine patterns and spherical ledge bushes. Production04 is retained as a technical/art comparison, not final art acceptance. Follow-up reference: ../07-cliff-planting/reference/owner-shelf.png.
