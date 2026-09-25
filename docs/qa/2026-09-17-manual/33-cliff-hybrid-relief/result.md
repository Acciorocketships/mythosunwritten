# Wider authored feet with retained curved terraces

Production selects `tests/fixtures/september17/cliff-hybrid-relief/full.gd`, combining the existing finite curved terraces with denser Nature-derived profiles. Those profiles widen toward the ground and retain downward bearing. Generic mass depth is reduced on short walls; taller walls retain more of it and gain a broader upper backing contribution. The neutral zero-depth union from pass 32 and shared warm/cool stone colour remain unchanged.

This is intermediate progress, not acceptance of the overall cliff appearance.

## Rejected candidates

The first hybrid candidate loses two corner triangles, tall-corner coverage and independent projections. Restoring two source-filter passes repairs closure. Retaining more generic mass depth restores eight prominence samples, versus two in the historical control. Increasing only the tall backing contribution repairs the remaining tall-corner coverage. `full-tests.log` records ten passing tests / 38 assertions for that final adjustment.

The new authored-foot test fails against `before.gd`: none of three admitted profiles has a sufficiently wider lower footprint. The selected version has twelve of twelve, with lower/middle width ratios of 1.219–1.351. These are source-profile measurements; physical rooting and worker grass support have separate checks.

## Verification and measurement corrections

The combined final run passes 36 of 37 tests, with 189 of 190 assertions (`final-tests.log`). The sole failure also reproduces against the preceding production geometry (`terrace-control.log`). That test incorrectly classified each subdivided triangle as a complete ledge, rejecting pointed ends attached to broad treads.

The corrected test measures connected physical tread width, retains the same broad-area and basal-projection thresholds, and rejects wholly narrow isolated turf components. An independent synthetic ribbon remains rejected; attaching it to a broad tread makes it a covered taper. Both follow-up tests pass all six assertions (`terrace-final.log`). Current measured broad tread area is 237.786 m², isolated narrow area zero, with 161 deep and 158 quiet basal samples. No production change was made to satisfy that measurement correction. The original test is preserved as `terrace_triangle_probe.gd` in the fixture directory.

The archived experimental continuity test also conflated steep rock sides with discontinuities by bounding total depth change over 2 cm. Direct samples through its worst interval are smooth. The new non-vacuous continuity test subdivides all coarse intervals changing more than 0.10 m into twenty 1 mm steps: 148 intervals, maximum fine/coarse ratio 0.0591 and maximum fine step 0.007705 m. The existing generic-mass continuity test and its thresholds remain unchanged.

Other passing checks include closed/nondegenerate photo shells, corner support, P05's 57/57 tread contacts, native root tangent, upper shelf coverage, curved treads, and eleven actual worker grass roots with no escaped or buried roots. Counts from separate runs are not summed into a fictitious clean combined run.

## Visual review

Frozen native candidates were inspected at P20 oblique and P12 side, with separate 64 m tall-wall oblique studies. The final tall candidate retains more upper relief. Short-wall geometry matches the balanced candidate because the last adjustment applies only to tall walls.

Fresh production generation completed for P20. All three saved-camera images were inspected: [reported](fresh-P20/P20_0.png), [left](fresh-P20/P20_-8.png), and [right](fresh-P20/P20_8.png). They retain pointed turf ends, wider rooted forms and the restrained shared stone colour. Broad faces still look too soft and upright in places; the native backing still repeats. Some narrow-looking ledges remain from these viewpoints. These are open art concerns, not excused by the passing geometry checks.

Fresh startup took 421.852 seconds during concurrent work. Grass capture reported 15,485 committed instances and 11,879 visible instances. This is neither a controlled performance comparison nor a traversal test. The snapshot utility emits its existing runtime shader-parameter-query warning. No universal cliff, water, streaming or full-suite acceptance is claimed; the original judging register remains open.
