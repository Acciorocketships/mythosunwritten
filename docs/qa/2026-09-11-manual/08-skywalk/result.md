# Skywalk integration

The two half-storey voids beneath the first occupied skywalk now use complete
native city masonry within their existing timber frame. The inaccessible crown
planter is removed through the support reservation, before decoration selection.
Both occupied spans and all 27 warren rooms form one connected constructed mass;
the separate small roofed house remains freestanding. This joins construction,
not playable interiors: the existing room assets still have closed walls/doors.

The course requires a complete actual lower room beneath every cell and an
actual upper root above it. Public air, daylight and other protected reservations
veto it. Emission additionally proves the lower building against the completed
foundation graph. Unsupported or taller gaps retain their existing native frames.
The full-width native stone panels retain their source triangles and normal
horizontal repeat; native miter alternatives close perpendicular joins. Vertical
fitting spans the measured lower slab and upper floor interfaces.

All 28 source room records and every unrelated recipe choice remain identical.
Two course units replace eight individual post units (the posts are retained
inside the new course recipes); the inaccessible garden is the ninth withdrawn
unit. See [construction delta](construction-delta.json) and the isolated
[implementation patch](implementation.patch).

The final candidate is number 4. The first admission policy produced no infill;
two later candidates were rejected after close underside views exposed openings.
The actual fault was selecting a 1.770 m wall for a 3 m interval. The final course
uses the complete 3.085 m native panel on its ordinary repeat. The strengthened
native tests cover 23,850 radial, off-centre and individual near-face segments
across all five supported footprints, plus actual slab/floor contacts and
protected-air refusal. See [iterations](iterations.md).

Twelve live pairs from the four photo reconstructions and their ±8° views,
sixteen native town pairs, and ten unobscured close/wider detail pairs pass visual
judging. Two other detail cameras are excluded because adjacent geometry obscures
the target. The close underside PNG was inspected at full render size after the
previous versions failed. [Image audit](image-audit.md) records every judgment.
[Photo 3 comparison](live-diffs/03_block_0_comparison.png) and
[close underside](details/diffs/course0_close_underside_comparison.png) include
pixel differences. All twelve paired game camera records are exactly equal;
original screenshot precision cannot be recovered from its rounded overlay.

Native town whole-frame mean absolute RGB changes are 0.639–1.426 /255. Live
changes are 0.648–2.899 /255, concentrated on the new support courses and removed
planter, with small animated-light/dither residuals. These metrics locate changes;
visual inspection and geometry/clearance tests establish their correctness.
The local collision survey remains exactly equal at 88 walking positions and
124 crossings. Live cold startup took 181.335 seconds; no startup-speed claim is
made.

The final focused and related checks pass 10 tests / 266 assertions with clean
exits. This includes all native near-face segments, missing-bearing/protected-air
refusal, the earlier skywalk fixture, roofless-column ownership, architectural
variety and existing native facade corner closure. An earlier invocation with a
mistyped optional filename is retained as `focused-invocation-error.log`; the
clean rerun and separate related run cover every intended file. The mandatory
48-town sweep constructs 48/48 towns, retaining all 11,112 clear public positions
and 15,923 clear crossings. The same 27 off-centre pillar contacts remain, with
zero blocked centres, crossings or disconnected public routes. The composition
gate passes 94/95 assertions; its only failure is the existing 3/standard timing
pin: 17,856 ms versus a scaled 16,200 ms limit. Calibration is an invalid 3.35x
host factor (capped at 2x). No geometry, fingerprint, completeness or support
assertion fails. This accepts the reported visual/construction repair; broader
solve-time performance remains unresolved, as in issues 5/6, and no pin changes.
The earlier broad compiler/reservation run passed 28/29 tests, 7,542/7,545
assertions. Its three failures all belong to one pinned historical fixture
(partial gable census, stone facade census, outcropping census). An isolated
pre-issue-8 source copy reproduces all three, 7,426/7,429 assertions; this repair
did not introduce those failures. No pinned counts or timing limits are weakened.
