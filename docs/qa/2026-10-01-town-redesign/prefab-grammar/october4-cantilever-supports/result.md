# Native cantilever supports — October 4

One-module upper-room projections now receive intact Pure Village Support_8
curved timber brackets. Their rear bears on lower wall joints (not window
centres); their upper arm meets the existing boarded floor. The source reaches
about 1.5 native metres under the two-metre projection. It is not stretched.
The existing house finish mapping also applies to these brackets.

Eligibility requires an actual exposed soffit cell, a two-band bearing wall
in the same building and an overlapping room above that wall. Inset or displaced
lower walls are excluded. Neighbor-carried floors are not cantilevers. Every
whole bracket passes the existing public-air/tower/bay/projection callback.
Longer projections require another structural rule and do not receive a short
bracket pretending to reach their edge.

The native fixture close-up shows continuous wall-to-floor contacts and
brackets between windows. In generated 7/standard, two brackets survive on
house.004's upper one-module projection. Its larger, lower wing projects TWO
modules (eight world metres), so remains unresolved. The host probe records
all floor cells; do not claim that the owner's large cantilever is repaired.
A future room/support assembly must reconcile that span with public headroom.

An initial helper-name collision caused a parse failure and incomplete frame
variant bake. The helper was renamed; the complete finish bake was rerun.
No failed run is used as verification.

Six focused tests / 48 assertions pass on the final code: four directions,
unique wall joints, no mesh stretching, whole obstruction rejection, longer
span exclusion, neighboring-room support and actual generated 7/standard air
clearance with surviving brackets. A production run passes 125 assertions,
7695ms at factor1.058; it started before the final neighbor-carried-soffit
exclusion and overlapped later focused testing, so it is not a quiet final
performance measurement. The final exclusion is covered by the six-test run.
