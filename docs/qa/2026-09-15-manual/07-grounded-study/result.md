# Issue 07: unsupported study shelves

**Accepted in the mountain study.** Its three separate elevated slabs are
removed; intermediate ledges are now part of the complete rooted formations
from issue 06. The right-hand projection therefore has supporting rock all
the way to the valley floor.

The full native footprint also replaces centre-only ground sampling when
seating each formation. This closes floating toes on the sloping study floor,
including distant wide buttresses. The source geometry, palette, cameras and
analytic ground remain unchanged.

![Matched hero and difference](diffs/hero-comparison.png)

The failing reproduction found sixteen exposed formation bases, including
the three slabs at 12.40, 26.07 and 15.33 metres above their local floor. The
final test checks actual native bottom vertices on all fifteen remaining
formations. Every surveyed foot is buried; the least burial is 26.2 cm.
Three native tests pass **215 assertions**, including catalogue freshness
and full visual/collision correspondence inherited from issue 06.

Fourteen camera-matched pairs were inspected: seven planted views and seven
bare geometry views with their absolute RGB differences. Before captures are
the final planted/bare sets in `../06-terraces/`; camera pose/FOV strings agree
exactly. Hero/close/left show the removed slabs; wide/right/overlook show seated
toes and retained terraces. Static physics surveys retain **41 clear capsules**,
zero missing ground and **15 matching visual/physical surface contacts**.

This closes the reported study placement problem. It does not insert the
standalone mountains into the procedural world or close issue 08. Production
terrain must retain its native flat grid tops, exposed-face ownership and
walking/water boundaries.
