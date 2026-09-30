# P03: continuous cliffs, rounded shoulders and supported grass

**Reopened by the owner:** the constrained faces still have abrupt, overly steep transitions, and the new right-hand benches need further review. The visual acceptance below is superseded by [the continuity follow-up](../2026-09-26-p03-continuity/issues.md). Its dry-profile numbers did not establish acceptable slopes at the marked water-constrained faces.

The owner's [annotated image](owner-annotated.jpg) reopened the previous restoration. This follow-up preserves the surface-net rocky style and addresses its five reported defects. Final native iteration 23 was inspected against the baseline and pixel differences. This report does not close the broader original thirteen-image register.

## Findings and repairs

| ID | Image location | Cause | Repair and evidence |
|---|---|---|---|
| P1 | Circled left foreground edge; wall behind it | Neighboring water halos prescribed cliff heights up to 35.2645 m apart. Some cuts removed every raised column, leaving no replacement wall. | Choose the water domain by world position, never excavate existing ground with a water cap, and seed backing at ground discontinuities. All 1,449 shared height samples agree within 1e-6 m. Three rays formerly passing through the opening hit the nearby wall. |
| P2 | Top of repaired foreground wall | Shallow water films cut away the rounded bank. Rock carving could bite into the first shoulder. Independently meshed chunks also produced different lighting normals at the same vertex. | Ignore films too shallow to contain the submerged bank, protect the first shoulder from carving, and supply the full normal-gradient halo. The normal regression fails before the halo fix (0.422 vector disagreement) and passes afterward. |
| P3 | Main hillside and right foreground | Tight tall-relief shoulders and feet made the profile too steep. | Broaden the existing envelope, including its relief window so the wider foot cannot be chopped off. Median smooth-profile grades: 12 m cliff 52.99° → 40.56°; 24 m cliff 60.42° → 49.55°. Individual rock risers remain steep. |
| P4 | Circled upper-right clump and terrace edges | Bilinear support heights did not follow rendered rock triangles; checking only clump centres admitted overhanging blades. | Attach roots to the actual triangle mesh and test two rings across the clump footprint. Shrink or reject unsupported clumps; covered rocks suppress terrain fallback. Native blade-root samples changed from 3 misses / 127 roots to 0 / 134. |
| P5 | Pale right foreground strip beside dark moss | A nearly flat carved rock tread reverted to the pale lawn grade, despite sitting within the mossy hillside. | Carry the uncarved hillside grade into the tread's moss shading, blending it with the surrounding slope. Preserve the warm stone material. Water, native-wall and tint controls excluded alternative causes. |

## Verification

- 40 distinct focused tests / 953 assertions pass: P03 follow-up (10), restoration (6), bedrock (6), cliff-grass/support (8), profile/stacked profile (10). See [final geometry tests](final-tests.txt) and [grass/profile regressions](grass-profile-regressions.txt).
- The normal-seam regression was run red then green: [before](normal-seam-red.txt), [after](normal-seam-green.txt). The fully cut-wall regression also failed before its repair: [red evidence](cut-wall-red.txt).
- [Shared-height and opening-ray checks](seam-after.json), [blade-root contacts](grass-after.json), and [surface contacts](surface-audit-final.json) use the rebuilt native scene. Surface checks distinguish exposed contacts from sheet faces intentionally buried beneath opaque ground; they do not count covered faces as holes.
- [Native boundary normals](normal-seam-native.json): all 242 shared vertices match exactly. Final scene audits: 134 blade roots, zero missing contacts; 148 cliff samples, 123 exact exposed contacts and 25 faces covered by nearer opaque ground, zero missing contacts.
- A 5.5 × 7.1 mm triangle initially missed a short physics ray. A longer ray hits its exact surface within the 2 mm tolerance; see [contact control](contact-control.json). It was not removed or hidden to make the audit pass.
- [Profile measurements](profile-comparison.txt) compare original, moderate and selected gentler radii. These are geometric grades, not a claim that every rock face is walkable.

## Native comparisons

Baseline is iteration 11, captured before reloading production sources. Final iteration 23 rebuilds all nine surrounding chunks with production grass and collision. Cameras, resolution, lighting and seed are held fixed for the five comparisons below. Each montage includes before, after and a four-times amplified absolute pixel difference; full-resolution raw differences and numerical changed-pixel counts are alongside it.

- [P03 overview](diffs/p03-review.jpg)
- [Crest](diffs/crest-review.jpg)
- [Wall overview](diffs/wall-overview-review.jpg)
- [Grass ledge](diffs/grass-ledge-review.jpg)
- [Rock face and moss](diffs/rock-face-review.jpg)

Visual findings: the foreground opening is replaced by continuous textured cliff backing; the former dark straight crest seam is gone; the plateau rounds over into the broader slope. The long pale right-hand tread no longer resets to lawn colour. Unsupported ledge clumps are withdrawn, and surviving grass follows supported ground. Rocky faces retain the original material and mesher. The P03 pair changes 1,212,331 of 1,440,000 pixels (mean absolute channel difference 23.88/255); that confirms a substantial change, while the image inspection and independent geometry checks establish what changed.

The wider slope occupied the old `strip` and `missing-wall` close-camera positions. Their final detail views were moved outward; those two are **not** used as matched pixel comparisons.

Iteration 20 was rejected for an abrupt cut crest. Iteration 21 rebuilt only the two central chunks and was not treated as a complete neighborhood. Iteration 22 exposed the normal seam during visual review. The final halo correction is checked in iteration 23.

## Reproduction

Run `tests/harness/cliff_site_review.tscn` with:

```text
--seed 2697992464 --at 430,40,850 --radius 1 --grass --full --plain
--output docs/qa/2026-09-26-p03-followup
--mouse-shot p03:503.3,36,951.5:507,36,955.3
```

The test-only probe mechanism loads `cliff_p03_full_review.gd` into the settled scene to reload sources and rebuild every built chunk. `cliff_p03_verify.gd`, `cliff_p03_normals.gd`, `cliff_p03_audit.gd` and `cliff_p03_surface_audit.gd` record native verification. Generate comparisons with `cliff_p03_compare.py <QA directory> 23`.
