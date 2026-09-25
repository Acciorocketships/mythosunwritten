# Longer shelves and a gradual cliff profile — experimental

The owner rejects small crags in randomly selected patches. The new direction is larger, shallower divisions associated with actual ledge risers and mass junctions. The owner also confirms the direct crown-bulge fix but rejects its rapid return to full projection just below the crown: the wall should slope more steadily or curve outward toward its base.

**No pass-50 variant is promoted.** The last candidate passes the focused shelf/closure/bearing checks, but its tall native rendering exposes excessive repeated backing relief, plain vertical faces and too little useful shape detail. Passing measurements do not make this visually acceptable. Production retains the isolated pass-49 crown repair; overall cliff art remains open.

## Retained experiment

`retained.gd` begins from the preferred earlier production body, not the rejected small-cell fracture study. Sparse major shelves coexist with short shelves, with independent lengths, elevations, inclinations, curvature and thickness. Short optional shelves near a major shelf are suppressed to avoid fragmenting the long turf strip. Actual Nature-derived lower terraces remain: treating them as optional short decoration erased too much usable tread.

The body's fast initial growth (`t^0.17`) becomes linear; its extra tall-wall swelling becomes quadratic, and mass exposure increases toward the foot. A root-derived projection envelope with a soft intersection restrains exceptional high projections. This addresses the body geometry rather than shrinking every completed ledge. In the current candidate it still has an unacceptable side effect: too much repeated native backing shows through, and some saturated faces are too plain.

The random fine-wear patches, small noise and independent short fracture marks are absent from this trial. A larger 5 m shallow plane field is weighted by actual mass-blend regions and proximity to shelf risers. This is physical geometry; no crack texture is added. The last render is too restrained in places and is not approval of this detail treatment.

## Red-first measurements

The fixed 48-by-64 m control's connected upper ledges originally range from 3 to **9.25 m** (seven components), failing the existing 20 m long-shelf target. The last trial ranges from 2 to **37.25 m** (ten components), retaining varied lengths. Earlier broadening trials reach 42.5 m but lose lower shelf area.

The old short collar exceeds the new gradual root-envelope bound by **3.286951 m**. The final `retained` trial has zero excess across **257,506** measured upper-body vertices at heights 8/16/32/64 m. The bound remains unchanged. This is a shape constraint, not a complete aesthetic judgment.

The final focused run passes **11 tests / 25 assertions**: gradual projection, connected long/short shelves, photo/corner lower bearing, closed shells, reported ledge channels, pointed turf continuity, existing turf contacts, and curved/sloping tread checks. Photo recession is **0.286600 m**, corner recession **0.337442 m** across 188 columns. Substantial photo tread area is **128.053974 m²**, above the unchanged 80 m² bound.

The separate tall run passes **2/4 tests, 7/9 assertions**. Actual upper terrace width and lower bearing pass: 72.173992 m² upper turf, 41.913855 m² broad turf (58.07%), and recession 0.287400/0.289300 m at 32/64 m. The broad-outline correlation remains **0.682635**, failing the unchanged 0.65 maximum. The old direct short-fracture-injection test also fails its nonzero-depth assertion because this trial intentionally removes those independent fracture marks; its duplicate-cut assertion still passes. That historical API check does not validate the replacement detail. No test is silently relaxed or removed.

## Trials and rejection evidence

- `graded`: post-process full-height taper; reaches 42.5 m ledges but reduces broad photo tread area to 27.786494 m². Rejected.
- `supported`: compensates shelf strength through that taper and switches to larger shallow, shape-associated detail. Still only 49.657471 m² of broad photo tread. Rejected.
- `intrinsic`: tapers the body before shelves. Retains 76.237932 m² but fails the projection bound by 0.799361 m; 9/11 tests, 23/25 assertions.
- `bounded`: adds a root-derived upper envelope. Projection passes but broad tread area is 71.406369 m²; 10/11 tests, 24/25 assertions.
- `retained`: preserves authored lower terraces during long-shelf arbitration; all 11 focused tests pass. Still rejected as final art for the tall-wall defects above.

Each of the five variants has seventeen frozen-context game captures at reported ReviewCam and supplemental angles (85 total). `retained` also has five native tall views. P12 front/side and P20 oblique are examined through the iterations; final tall oblique/ledge views expose the decisive regressions. Do not call all 90 images independently judged.

These are native Godot/Metal renders. Context replays rebuild rock and crevice plants at saved anchors; they do not regenerate world terrain/grass/admission or establish player traversal. There is no performance, streaming, water or original-register acceptance.

## Reproduction

Headless tests select `STORY_COLUMN_GENERATOR`, `STORY_BUTTRESS_GENERATOR`, `STORY_BUTTRESS_CORNER`, `STORY_CHANNEL_GENERATOR`, `STORY_CURVED_GENERATOR` and `STORY_TALL_TERRACE_GENERATOR`. Exact test names and measurements remain in the logs.

Game replay uses `tests/harness/september16_cliff_transition_context.tscn` with `--generator=res://tests/fixtures/september18/cliff-long-shelves/retained.gd --corner-generator=res://tests/fixtures/september18/cliff-long-shelves/retained-corner.gd --corner-study --output=…`.

Tall native review uses `tests/fixtures/september18/cliff-long-shelves/retained-tall.tscn -- --height=64 --output=…`.

See [comparisons](comparison.md). Sources remain frozen under `tests/fixtures/september18/cliff-long-shelves`.
