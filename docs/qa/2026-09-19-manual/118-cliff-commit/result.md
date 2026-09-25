# Prepare cliff render arrays before main-thread publication

Cliff normal-fan construction and native-wall attachment blending previously ran
inside `CliffRockCrags.mesh()` on the main thread for every formation. Production
now prepares detached vertex, normal, colour and UV arrays in the worker, after
owned geometry has been joined and accepted. Main-thread commit only uploads those
arrays and binds the existing materials. Historical study callers can still use
the uncached mesh adapter. No geometry, turf, collision or material style changes.

For the nearest **16 actual formations / 32 surfaces / 755,472 vertices** from N01's
fresh production snapshot, native Metal timing changes from **2.796 s** on the main
thread to **20.3 ms**. The worker takes 2.701 s while frames continue rendering.
This removes a large freeze source; it does not eliminate the computation or prove
an overall startup improvement. GPU upload and physics publication can still stall.

Every native surface array is byte-identical to the saved pre-change mesh builder.
The ordinary chunk-payload test confirms preparation occurs before publication;
threaded controls cover two real wall formations and a corner, with unchanged source
data. The focused test has 2 tests / 18 assertions. The related run, including normal
continuity, saved recipe/floor replay and stream observers, passes 11 tests / 44
assertions. The first fixture used single-storey steps and exercised no formations;
that invalid case was corrected to a genuine four-storey wall before acceptance.
The API absence provides the valid red regression in `logs/cliff118-red-valid.log`.

`before.png` and `after.png` retain the reported camera and original biome/grass
bindings. The earlier replay without those globals was only diagnostic and is not
used as an art comparison. No new scene collision is generated or replaced by the
native comparison. The saved pre-change builder is
`tests/fixtures/september19/cliff-commit/baseline_crags.gd`.

This is a scoped commit optimization. Cliff art, missing corners, waterside dressing,
town layout/path finish, bank water and the broader generation bottlenecks remain
open; pass 117 records the new reports and loading-boundary fog.
