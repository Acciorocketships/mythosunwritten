# Recovered references, localized fractures and longer shelves

**Experimental; no production promotion.** The owner's selected short-wall reference is exactly the existing pass-34 production geometry. The selected tall-wall image is the stronger pass-45 `rooted-joints` study. This pass recovers both sources and combines their composition by wall height, with additional lower rooted rock profiles. Subsequent owner feedback requests thinner/deeper localized cracks, smaller fractured sections, a nearly flush upper join and substantially longer, more varied ledges.

## Exact recovered references

- Yellow-world `download.png`: SHA256 `d4d5c895c5776ad18eebdd2ac913b4cf0e2f1d6eec333633bc9bfe0c0bf48e1d`, identical to `2026-09-17-manual/37-cliff-detail-options/before/P20_oblique.png` and the pass-29 production-review view.
- Tall-wall `oblique.png`: SHA256 `d2bcf805abaeaa51f432d05eaf2135e026320e670d1fc63ffc3c593853651b4a`, identical to pass-45 `rooted-joints-tall/oblique.png`.

These are positive owner references, not approval of every remaining feature. The earlier rejection of pass-45 as a finished implementation must not erase this later preference.

## Retained experiment: `long`

Normal-height walls retain the recovered broad body and curved ledges. Taller walls blend into the selected connected-stone composition. Actual sampled Nature-rock front sections add localized lower formations; a downward support envelope carries their widest sections to the base. Taller shelf supports also retain their bearing.

Small fractured panels use a 2.7 m oblique partition inside smoothly fading selected patches; broad rock remains outside those patches. The same local partition produces panel relief and physical recesses. The nominal narrow recess is 19 cm deep, reduced near turf, the crown, thin attachments and patch edges. This is mesh geometry, not an overlaid crack texture. It is still an art experiment: the native close views retain serration along some joints and the broad tall silhouette remains too upright.

Most ledges retain the shorter family. A separate sparse family supplies much longer curved/sloping shelves and suppresses overlapping short shelves near their elevation. Simply widening every shelf failed: overlaps split them back into short connected pieces. The corrected family produces actual connected upper turf spans from **2.5 to 41.75 m** in the pinned 48-by-64 m fixture, versus the prior approximately 14.5 m maximum. The longer shelf does not span the full wall at one fixed elevation, although some long treads remain visually thin.

The upper join now stays nearly flush throughout its upper metre, then introduces depth below that interval. A short-wall-specific failure was found: the initial proportional taper ended at 1.28 m on a four-metre wall, already permitting a large projection inside the upper metre. A minimum collar depth fixes that mechanism without moving the native turf lip.

## Red-first checks and retained failures

- Upper-metre projection: original combined `supported` study **2.695677 m**, initial `cracked` / snapped `tucked` **0.785917 m**, final **0.035050 m** across 67,816 sampled photographed front vertices. The unchanged bound is 0.35 m.
- Updated long-ledge target: earlier `tucked` fails the new 20 m minimum; broadening all ledges (`patchy`) still fails at **14.25 m**. Sparse long-shelf arbitration passes at **41.75 m**, retaining 22 measured upper components and shorter shelves.
- Final nine-test gate: **8/9 tests, 17/18 assertions**. The single failure remains the existing large-outline repetition diagnostic: **0.763078** versus an unchanged 0.65 maximum. This supports the visual judgment that upright forms remain unresolved; the threshold was not relaxed.
- The other final checks retain 31 closed, nondegenerate photographed shells, all **57/57** reported turf contacts, no reported narrow shelf-channel cluster, pointed turf continuity, and photo/corner lower bearing. Photo recession is **0.399700 m**, corner recession **0.369998 m** across 380 columns.
- Separate tall support/width gate: **2 tests / 6 assertions** pass. Upper turf totals **142.999591 m²**, including **105.678613 m²** with substantial tread width (73.90%). Recession is **0.422100 m** at height 32 m and **0.437100 m** at height 64 m; crown excess is zero.
- Earlier recovered-to-`varied` lower-foot check: 1,687 samples; max added foot reach **1.577800 m**, 572 extended by more than 0.35 m, 973 unchanged below 0.01 m. This result belongs to `varied`, not a substitute for a fresh `long` footprint/traversal test.

## Intermediate trials

`merged` widened too many shelves and retained permanent column supports. `evolved` and `composed` progressively restored the selected support model. `varied` preserved more short shelves but failed tall lower bearing (3.530300 m recession at height 64 m). `supported` carries the upper envelope down and passes bearing, but does not solve upright composition. `cracked` adds narrower physical joints everywhere and fails the upper-metre join check. `tucked` tests a coordinate-snapping hypothesis; it does not fix that failure. `patchy` fixes the actual short-wall collar and localizes smaller fractures, but still misses the longer-ledge target. `long` adds sparse major shelves. `soft-joints` changes the smoothing angle only; its native render introduces visible dashed shading seams and is rejected.

## Visual judgment and scope

The retained preview improves the reported crown bulge, allows long/short shelves, and confines finer cracks to selected patches. It is **not a finished cliff**: tall vertical support shapes, some triangular broad facets, thin-looking long treads and serrated crack edges remain. No trial is copied into production. Production `CliffRockCrags.gd` remains byte-identical to `recovered.gd` (SHA256 `b6eb92244bec2c64c8e032e6c31e6d3a0535f8e838e0d1b48d209f44075cff0e`).

Native captures use Godot 4.5.1 / Metal. The tall fixture has fixed lighting/cameras. Context replays rebuild rocks and crevice plants at saved anchors; reported views use the existing saved ReviewCam poses. This does not rerun world grass, hydraulic admission, actual player traversal, streaming or fresh-world generation. Dense experimental sampling has no performance acceptance. Broader original-register issues remain open.

See [selected comparisons](comparison.md). Logs preserve failed as well as passing measurements.

## Reproduction

Tall: `/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story --log-file /tmp/cliff-review.log res://tests/fixtures/september18/cliff-recovered-composition/long-tall.tscn -- --height=64 --output=res://docs/qa/2026-09-18-manual/47-cliff-recovered-composition/long-tall`.

World: use `res://tests/harness/september16_cliff_transition_context.tscn` with `--generator=res://tests/fixtures/september18/cliff-recovered-composition/long.gd --corner-generator=res://tests/fixtures/september18/cliff-recovered-composition/long-corner.gd --corner-study --output=…`. `--shot=P20_oblique` selects the exact supplemental reference view; omit it for all reported and supplemental views.

Headless GUT selectors are `STORY_COLUMN_GENERATOR`, `STORY_CHANNEL_GENERATOR`, `STORY_BUTTRESS_GENERATOR`, `STORY_BUTTRESS_CORNER` and `STORY_TALL_TERRACE_GENERATOR`. The final gate comprises this folder's `crown-flush-test.gd` / `long-ledge-test.gd`, `test_september17_ledge_channels.gd`, `test_september17_cliff_buttress_support.gd`, and pass-44 `macro-column-diagnostic.gd`. The tall gate runs `test_september17_tall_cliff_terraces.gd` with `-gunit_test_name=test_tall_`.
