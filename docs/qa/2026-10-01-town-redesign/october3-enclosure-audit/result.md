# Finished enclosure and natural-ground endpoint investigation — October 3

Production carver restored byte-for-byte to the state before this investigation.
Retained: expanded finished-town audit and current eight-town evidence. No bridge
admission/ranking change from this investigation ships. Candidate native images
and the candidate player walk below are evidence for a rejected candidate.

## Current finished towns

The enclosure probe now records each public macro cell's four construction
quarters, occupied room ceilings, and immediately adjacent occupied room cells
at street level. It separates floors above the massif bearing from floors at
bearing. This is an **inhabited-room** measurement: retaining walls, roofs without
rooms, trees and awnings are not counted. A quarter with no adjacent room is not
proof of an entirely exposed street. These metrics locate structural questions;
they do not replace native visual judgment.

| Town | Public cells | Quarters under occupied rooms | Share | Floating masses | Roof/public-air intrusions |
|---|---:|---:|---:|---:|---:|
| 7/standard | 45 | 40 | 22.2% | 0 | 0 |
| 13/large | 69 | 28 | 10.1% | 0 | 0 |
| 31/large | 39 | 12 | 7.7% | 0 | 0 |
| 43/grand | 98 | 72 | 18.4% | 0 | 0 |
| 58/large | 123 | 12 | 2.4% | 0 | 0 |
| 101/large | 61 | 20 | 8.2% | 0 | 0 |
| 103/grand | 82 | 28 | 8.5% | 0 | 0 |
| 211/grand | 99 | 68 | 17.2% | 0 | 0 |

`current.json` comes from the current material/geometry integration, before the
candidates. Three towns are additional holdouts. All eight build. Repeated
bridge-refusal records are retained verbatim; they are not unique opportunities
and should not be reported as a count of independent possible bridges.

## Experiments and decisions

1. Let a proved broad, grounded endpoint house satisfy its own neighborhood
   requirement. No finished coverage improvement in five towns; reverted.
2. Recognize natural ground as direct bearing. The existing helper requires a
   solid massif voxel at `foundation_floor - 1`, but `_column_is_solid_at` excludes
   every voxel below the natural base. A house exactly at natural ground therefore
   fails that direct-bearing check. The isolated repair passes six assertions
   (ground support, burial rejection, full footprint, public air and carved room
   interruption), but early admission changes the later street/house partition.
   31/large improves 12 -> 16 quarters; 101/large falls 20 -> 8. Not accepted.
3. Prioritize supported rising-street crossings. It does not repair that loss;
   reverted with the candidate.
4. Defer natural-ground links until after the complete street network, leaving
   early reservations for raised massif crossings. The five-town survey keeps
   four towns unchanged and improves 31/large 12 -> 16. Native forward/reverse
   views show an inhabited covered passage; the actual player passes both
   directions (`player.json`). However, holdout 7/standard falls 40 -> 28 covered
   quarters. 58/large and 211/grand are unchanged. Net eight-town coverage falls
   280 -> 272. The entire candidate is therefore reverted.

In 31, the candidate replaces one covered cell at (2,4,4) with two at (3,4,2)
and (3,4,3). In 7, several former upper-room connections disappear. No floating
or roof/public-air errors occur in the candidate, demonstrating why those green
checks alone cannot prove architectural success.

## Next structural work

Foundation eligibility, endpoint allocation, and preservation of existing
inhabited bore covers must be co-decided. A late source reservation can still
repartition the houses that supply other covers. Do not simply relax the support
or neighborhood guard, raise a bridge quota, add retries, or hardcode the sampled
seeds. Preserve the rejected ground-link patch and the isolated red regression
case as evidence for a coupled repair; neither is active production code.

No production timing or new full-suite acceptance is claimed for these rejected
candidates. Smooth-stone/Gothic composition, broader enclosure and final world
acceptance remain open. Current palette changes remain in production.
