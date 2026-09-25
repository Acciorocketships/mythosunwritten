# Layered Nature-body investigation — not promoted

Production remains pass 55. Smaller overlapping Nature bodies at varied heights do not by themselves remove the tall column composition. Exposing stronger body relief introduces visible folds and shortens the longest upper ledge. A new production regression guard rejects abrupt loss of support immediately below a ledge; it passes on unchanged production. No overall cliff art or original issue is accepted.

## Controlled alternatives

All variants start from the captured pass-55 generator in `tests/fixtures/september18/cliff-layered-bodies/before.gd`. Each has its own corner, dressing and tall-scene companions.

| Variant | Change | Native judgment |
|---|---|---|
| layered | Native bodies occupy finite staggered vertical ranges instead of spanning most of the wall; support fans below their origins | Broad faces and vertical fluting persist |
| release | Gradually releases the final projection limiter below mid-height, preserving its upper region | More lower relief, but still columnar and blank in game |
| authored | Removes generic masses and increases the native-body reach | Does not resolve repetition; one P20 ledge becomes a dark diagonal edge |
| rounded | Allows bounded recession beneath native-body maxima | Little visual improvement in the tall wall |
| exposed | Removes the additional global height envelope from native-body relief | Stronger outcrops expose jagged teeth/folds in P12; rejected |
| bearing | Carries the exposed outer lip downward with bounded recession | Repairs the measured bearing discontinuity, but visible folds and short long-ledges remain |

Five tall alternatives have five views each (25 captures). Layered, release, authored, exposed and bearing each have seventeen matched frozen game views (85 captures). Seven additional exposed lighting controls are separate. The game replays reuse saved terrain, grass and collision: these are art comparisons, not new placement or physical-seating validation.

## Regression evidence

The focused suite includes actual photo-shell closure, pointed turf, close tread channels, cap coverage, long connected upper ledges and the upper projection envelope.

| Exact variant | Tests | Assertions | Material result |
|---|---:|---:|---|
| release | 6/6 | 12/12 | 31 closed nondegenerate shells; 57/57 cap probes; upper spans 2–42.25 m; zero upper-envelope excess over 304,256 samples |
| exposed | 5/6 | 11/12 | Longest upper ledge falls to 17.75 m, below the 20 m guard; other focused checks pass |
| bearing | 6/7 | 13/14 | Added lip-bearing check passes, but longest upper ledge remains 17.75 m; 31 shells and 57 cap probes pass |

The other shape variants do not inherit these test results. Full-suite acceptance is not claimed.

The new lip-bearing diagnostic measures actual exterior columns on 31 photo formations, excluding the crown and end collars. Consecutive samples separated by at most 35 cm vertically must not lose 50 cm of outward bearing. It also requires more than 10,000 samples.

| Exact source | Samples | Breaches | Worst recession |
|---|---:|---:|---:|
| before / production control | 32,334 | 0 | 0.101600 m |
| exposed (red) | 32,374 | 44 | 0.901200 m |
| bearing repair | 32,374 | 0 | 0.030001 m |

The registered `tests/test_september18_cliff_lip_bearing.gd` passes one test / two assertions against unchanged production. This is a guard against a demonstrated prototype regression, not a claim of a repaired production bug. It relies on the current fixed-x column architecture; lateral-warp variants require section-based sampling instead. The worst measured breach is not proven to be the same location as the visible P12 folds. Passing the check does not remove those folds.

The experimental bearing carrier runs after existing foot sampling. Its changed lower footprint has no fresh seating or terrain-admission verification and is not eligible for production on these results.

## Lighting control and limits

The exposed tall close view retains strong divisions with sun shadows disabled. The diagnostic named `no_bump` targets a relief expression absent from the current shader, so it is not an independent bump-removal result. No general lighting diagnosis follows from that control.

All native jobs and test sessions have terminal results. No production generator, material, water or streaming change is included. Larger shallow partitions, restrained upper projection and the pass-55 lower shoulders remain in production. Persistent upright organization, broad blank faces, thin treads and the visible folds prevent selecting any candidate.

See [matched comparisons](comparison.md), the individual logs, and `source-evidence.sha256`. The goal and original judging register remain open.
