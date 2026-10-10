# Seat retaining caps below real floor undersides

Measured rejection of seed41 candidates showed many cap/floor overlaps were
only 0.001688 native metres: the nominal 0.05 cap setback did not quite reach
the authored deck underside at floor-0.051688. Public-air bounding boxes were
not the culprit in this sample; their exact convex tests agreed.

The complete cap now seats 0.001 m below overlapping deck undersides when the
required correction is at most approximately 0.1 m. All original public-air,
other-piece and tower checks run again after seating. Floors intersecting the
body still reject the proposal. There is no clipping, scaling, collision bypass,
world-seed exception or broader obstacle relaxation.

Regression reproduced the rejection before the fix. Three suites pass8/8,
73 assertions. Additional lowered-air/body-obstacle cases in the focused
regression pass1/1,16 assertions. Actual41 embedded-wall-room entry/return2/2.
Native41/67 overview/street images generated;41overview inspected. Admitted
supports41:7->17 and67:16->17. The41overview shows relief on the previously
blank face. The custom close camera entered a neighbouring structure and is
NOT exterior art acceptance; saved explicitly as such. A properly located
public-street close view is still required. Support counts include hidden
faces and do not measure exposed facade quality.

All jobs terminal, diff check clean. Full architecture acceptance, wider
regression/performance and remaining plan requirements remain open.
