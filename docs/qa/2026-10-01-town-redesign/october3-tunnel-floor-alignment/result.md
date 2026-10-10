# Inhabited tunnel covers and floor alignment — October 3

The tunnel-cover planner now accepts the first existing house storey above a
solid crown on either two-band storey phase. The old one-band lift limit excluded
same-phase houses beside the common two-band bore: their next floor is two bands
above the crown. The limit now derives from `WarrenBuildingParcel.STOREY_BANDS`.
It does not grow a house or accept a distant higher floor. The complete room and
roof reservation must fit within the host's existing top, and the original jamb,
edge profile, citadel, headroom and plot-placement checks remain.

Composition reserves the entire solid bearing thickness between the crown and
the room floor before other rooms/roofs can use it. The built cover re-proves all
of those courses. The existing unborne-stone cleanup still releases the complete
run when no real room is constructed. This restores some inhabited bores without
adding decorative standalone bridges or raising bridge quotas.

## Investigation and rejected intermediate state

The eight-town host probe found 18 rejected bores with a sufficiently tall
adjacent house whose next floor was exactly two bands above the crown. Other
rejections have short houses or more distant floors; those remain ineligible.
The first planner-only candidate gained cover in four towns of a sixteen-town
sample and passed the floating/public-air audits, but the older whole-or-absent
cover test caught a partial crown on 7/large, outside that sample. The room was
whole but one of four ceiling columns lost both bearing bands. Reserving only
the first crown course left the intermediate course available to other
composition; later stone cleanup could not restore a whole bearing.

The planner-only candidate is not the retained implementation. Reserving the
full run and checking every course fixes the partial crown. `partial-crown.log`
and `repaired-crown.log` expose the actual fine-grid uses. The final regression
includes 7/large and checks every intermediate course, rather than just the
first crown.

## Final evidence

Two focused tests / 44 assertions pass: both floor phases, insufficient-height
and distant-floor rejection, and actual whole-or-absent covers with unchanged
public headroom in 13/large, 31/large and 7/large. The older twelve-town
whole-or-absent test has no remaining partial-cover failure: 42/43 assertions
pass, with the remaining failure being 4/large's null town. Running the unchanged
one-band rule also fails that town and fails the positive-cover assertion.
That pre-existing generation failure remains open; the legacy test is not green.

All sixteen main/holdout towns build with zero floating-mass and roof/public-air
intrusions. Inhabited street quarters increase from 764 to 800, with no town
losing coverage. Changes: 13/large 36→42, 17/grand 56→60, 23/grand 76→84,
71/grand 22→40; the other twelve are unchanged. This metric includes finished
house/skywalk rooms and downstream composition changes; it is not a count of new
source bore plots or new bridges.

`final-native/` contains retained-code views of 13/large. Forward and reverse
views show an enclosed inhabited walkway with a complete native timber soffit.
The earlier reverse camera in `candidate/` was inside neighboring geometry and
is not acceptance evidence. `holdout-native/` shows the planner-only candidate's
longer 71/grand cover; its obstructed forward camera is likewise not evidence.
Native source assets and materials are unchanged.

The planner-only 13/large player traversal passed both directions. The initial
final-code 7/large player invocation was refused by a harness assertion requiring
opposite edges: this bore turns a corner. The harness now prefers opposite
edges, then follows two actual adjacent edges through the centre waypoint.

Broader massif enclosure, long compound silhouettes, Gothic stone architecture,
full-world review and baseline generation/test failures remain open. This pass
is an enclosure improvement, not final acceptance of the full redesign.

Final repaired-corner player check: 7/large passes both directions, including
the turn, with the actual player and published route waypoints (`turn-player.json`).

Final quiet real-terrain production gate: 1/1 test,125assertions,
6,170 ms town generation against the unchanged8,000ms ceiling.
