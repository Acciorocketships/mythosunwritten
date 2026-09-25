# Curved and inclined broad ledges

Selected as a scoped geometry improvement, not overall cliff-art acceptance. Broad selected treads now bend across their depth as well as along the wall. Concave and convex cross-sections vary with the selected grade; resting shelves remain among them. Lower bearing, existing mass profiles and crown retreat are retained. Native wall repetition, tall soft vertical faces and some angular shelf endpoints remain visibly unresolved.

## Geometry and planting

`CliffRockCrags.gd` increases selected broad tread grades from 0.06–0.14 to 0.10–0.25 and introduces a middle depth sample. Eased monotone descent keeps both outer endpoints and lower bearing fixed. Tread triangulation follows corresponding depth fractions rather than sorting vertices by height. The selected source is frozen in `tests/fixtures/september17/cliff-curved-treads/candidate.gd`; production is byte-identical. The prior continuous-foot and fixed-mass-seed repairs remain.

The cross-depth curvature probe fails on the previous geometry with zero curved columns; the selected geometry has 248. With the old grass lattice, however, this geometry supports only four patches and fails the unchanged planting gate. A bounded twice-resolution layer now supplies unmet density only on actual native support faces. Full footprint, boundary, occlusion, wet and public-space checks remain. The final fixture has twelve supported patches, zero escaped and zero buried. Ordinary ground grass buffers remain byte-identical in two seed controls.

Support faces are indexed in 2 m cells, preserving original order and exact triangle queries. This prevents the finer sampling from repeatedly scanning every face. 4,107 boundary/overlap/tie probes and nine complete actual tile-buffer comparisons match the unindexed implementation.

Tread-width checks now measure connected physical width, rather than mistaking each subdivision edge for a shelf boundary. Original width/area thresholds remain unchanged. A separate control verifies identical width and area with one, two and four subdivisions.

## Verification

- [Original curvature failure](red.log): zero curved columns.
- [New geometry with old grass sampling](probe.log): three of four tests pass; four supported grass patches fail the unchanged minimum.
- [Refined planting](grass-refined.log): four tests / nine assertions pass.
- [Main focused run](final-tests.log): 63 tests / 1,062 assertions pass across fourteen scripts.
- [Post-index run](index-tests.log): 30 tests / 365 assertions pass, including ordinary grass, streaming grass, actual ledge planting and support equivalence. These overlap the main run and are not additive totals.
- Photo buttress recession remains 0.6762 m; crown excess is zero; corner recession is 0.3403 m. All tested 16/32/64 m corner solids remain closed and nondegenerate. Seven independent prominence samples remain. Turf thin-face count is zero under the unchanged physical-width threshold.
- [Scoped CPU benchmark](index-cost.log): three tiles per measurement. Old coarse/full-scan times were 1,838 / 2,074 / 1,423 ms; refined/full-scan times were 2,865 / 3,227 / 3,822 ms; refined/indexed times were 219 / 182 / 164 ms. All nine compared complete buffers match. This is support-query evidence, not global generation or frame-time acceptance.

The expected invalid-configuration diagnostics in the grass tests are asserted controls. The macOS certificate diagnostic is unrelated to terrain execution.

## Native visual review

Seventeen frozen game-context captures retain saved camera/lighting and regenerate the candidate rock and plants. Inspected [P05](candidate/P05_reported_0.png), [P12 side](candidate/P12_side.png), and [P20 oblique](candidate/P20_oblique.png) show finite broader sloping shelves, with subtle cross-depth bending. No new crown overhang or hard attachment gap was observed in these inspected views. These frozen world captures do not demonstrate regenerated grass.

Five tall study views provide a 64 m control. The [ledge view](tall/ledges.png) still exposes strongly repeating native wall relief and is not accepted as the final art direction.

Six [native grass pairs](grass-native/) compare old versus refined sampling on the same selected geometry using actual worker output and grass shader buffers. Final pairs disable wind and use front lighting. [Root 0](grass-native/root_0_current.png) and [root 2](grass-native/root_2_current.png) show small additional patches seated on the ledges; root 1 is largely hidden by its fern and is not counted as independent visual root confirmation. The [tread close view](grass-native/tread_current.png) shows the curved surface, but planting remains sparse. White space outside the low side is the limited fixture extent, not a complete production terrain view. Initial backlit captures were replaced by the final front-lit pairs.

This revision makes selected ledges physically nonplanar without losing planting or bearing. It does not resolve the larger vertical/horizontal organization of the native backing, all cliff composition, original water/town/streaming reports, or the reference-image quality target. No fresh-world, player-traversal, hydraulic, streaming or global performance acceptance is claimed.
