# Cliff scale and connected-detail study

**Unselected. Production geometry/material remain exactly at the pre-trial pass-34 state.** The owner rejected the earlier tall column/scratch study. This follow-up tests real geometric detail, finite curved shelves, support profiles and upper joins. It does not declare the cliff art fixed.

## Findings

The pass-43 fixed 8 m stone cells and 10 m shelf pitch leave ordinary 4–12 m cliffs too plain. A 4.8 m partition and 5.5 m independently omitted/jittered shelf pitch add variation, but constant-depth shelf shoulders still create slab-like supports. A descending support envelope can also erase the smaller rock relief. Separating the bearing operation from bounded stone relief preserves it, but dense full-face detail becomes noisy and produces jagged creases.

The final three detail controls compare absent, subtle and stronger connected relief under identical native studio lighting. The small relief is actual geometry; its joints follow the same irregular partition. No crack texture is added. Subtle detail is preferable to the noisy stronger treatment, but the shared large forms remain too upright. The no-crag control makes this failure especially clear.

A subsequent `unified` prototype limits crown recesses to 2.6 m rather than a third of tall-wall height, increases the buried upper backing and uses a broader 6.8 m physical stone partition. It reduces the native wall's obvious tiled strips. The saved short-wall game views still show overly plain/slab-like faces and an angular crown transition. **Rejected for promotion despite passing scoped geometry tests.** The next work must address the larger support shapes rather than add more surface detail.

[Matched native comparisons](comparison.md) include the three controls and the later join prototype. Five fixed studio cameras exist for each review control and the join prototype. Seventeen frozen game views exist for each of four iterative shape trials, including `unified-context`. There are 93 captures total; this is an evidence inventory, not 93 independent acceptances. Earlier `subtle-context`, `relief-context`, `seated-context` and `final-subtle-tall` are explicitly intermediate/rejected. Unrendered variant source files are not judged results.

## Red-first checks and rejected candidates

The inherited production tall-outline test was red at 0.907952 mean correlation between lateral profiles eight metres apart (pass 43). It remains a narrow repetition diagnostic, not an art metric.

- First scale trial: 6/7 tests, 12/13 assertions; full-height recession 0.888900 m exceeds 0.85 m.
- Post-bearing relief trial: 6/9 tests, 14/17 assertions. Only 51/57 reported cap contacts retain turf; immediate recession reaches 0.934000 m. Rejected.
- First reduced/detail-protected trial: still 6/9, 14/17. Protecting exact tread vertices alone is insufficient; nearby upward stone can enter the tread's physical interval.
- Restrained `review-subtle`: 9/9 tests, 17 assertions. An expanded near-cap quiet zone restores 57/57 turf contacts; full-height recession 0.614300 m, immediate recession 0.450700 m, crown excess zero. Broad tread area 414.119095 m². Tall correlation 0.303945.
- `unified`: 9/9 tests, 17 assertions. All 31 photo shells closed/nondegenerate; 57/57 turf contacts. Full-height/immediate recession 0.626000 m; convex recession 0.603917 m; crown excess zero; broad tread area 383.261952 m². Tall correlation 0.330624.

The physical run retains the old whole-height bearing threshold; it has not been relaxed. A separate two-metre diagnostic has positive and negative controls. The already-green tests do not overrule the visual rejection.

## Support and diagnostic follow-up

The separate support run passes 17/17 tests / 59 assertions: four production baseline grass tests (176 roots), the same four on the study (582 roots), and nine study corner tests. Every sampled whole grass patch is supported, none is buried, and split-owner buffers agree in the fixture. Corner shells are closed/nondegenerate at 16, 32 and 64 m, including detached-worker/public/wet-admission checks. This is a focused fixture corpus, not full-world acceptance. Runtime was 259.296 s; no controlled performance comparison is made.

A second outline diagnostic filters lateral profiles with a 4 m triangular kernel before comparing elevations. Production is red at 0.933572; `unified` is green at 0.369848. Even that filtered diagnostic misses the locally slab-like appearance seen in the short-wall camera. It establishes reduced global outline repetition, not acceptable rock composition. The next iteration must retain direct short-wall judgment rather than chase this statistic.

## Reproduction

Use `/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story` with a unique `--log-file` for every process. Study sources are under `tests/fixtures/september18/cliff-scale-study/`.

Tall capture: `res://tests/fixtures/september18/cliff-scale-study/review-subtle-tall.tscn -- --height=64 --output=res://docs/qa/2026-09-18-manual/44-cliff-scale-study/review-subtle-tall`. Replace the variant stem for the other studies.

Game replay: `res://tests/harness/september16_cliff_transition_context.tscn -- --generator=res://tests/fixtures/september18/cliff-scale-study/unified.gd --corner-generator=res://tests/fixtures/september18/cliff-scale-study/unified-corner.gd --corner-study --output=res://docs/qa/2026-09-18-manual/44-cliff-scale-study/unified-context`.

Focused tests use `STORY_CHANNEL_GENERATOR`, `STORY_BUTTRESS_GENERATOR`, `STORY_BUTTRESS_CORNER` and `STORY_COLUMN_GENERATOR` to select the study, then run `test_september17_ledge_channels.gd`, `test_september17_cliff_buttress_support.gd`, pass-43 `column-diagnostic.gd` and this study's `local-bearing-tests.gd` through GUT. Logs retain all printed measurements and failures.

The replay rebuilds formations and resamples plants in the frozen September 16 world; it does not regenerate world grass or prove fresh-world ownership, live traversal, hydraulic clearance or performance. No broad suite or original issue-register acceptance is claimed. The editor import check completed but could not save user-level editor settings inside the sandbox; the native scenes and headless tests ran independently.
