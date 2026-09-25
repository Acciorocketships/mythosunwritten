# Convex cliff join study — rejected

The ordinary `CliffRockDressing.compute` receives native outer-corner rows but constructs new relief only from straight rows. At the synthetic 16 m plateau's exposed convex corner, zero of five diagonal rays at heights 2, 5, 8, 11 and 14 m see added relief beyond the native column. The baseline failure is saved in `red.log`; its recurring fixture is `tests/fixtures/september17/cliff-corners/red.gd`.

A closed straight crag surface was mapped around actual sampled native corner geometry. Native depth/normal sampling needs a bounded one-sided vertical ray at an exact authored groove boundary. The successful probe is `prepare-probe2.log`; the two initial failed prepares are not accepted evidence.

Three candidates were rendered in all 17 saved context views: `study`, `compact`, and `rooted`. The original P05/P12/P17/P20 camera transforms come from the ReviewCam-derived saved pose records; nearby front/side views supplement them. P17 reported -8 and +8 expose the corner most clearly. The first candidate covers the column with a large round mass and wrapping turf ledges. Compression reduces its reach but retains a cylindrical stack. A shallow native-based candidate retains more native relief but still creates an unconvincing wrapping ledge and soft rounded shoulder.

All three are rejected for art. No corner geometry or corner rendering branch is enabled in production. The native-root renderer and final generator remain isolated in `tests/fixtures/september17/cliff-corners/` for further investigation; `--corner-study` is an explicit harness-only opt-in. No fresh production placement, wet/public admission, rooting, collision or traversal acceptance is claimed. The corner gap remains open.
