# September 13 water investigation — in progress

P12 is reproduced in a fresh complete-world capture at seed 2697992464,
feet (1088.9,12,12.8), crosshair (1090.5,12,18.2). Startup took 305.472 s.
The three views in live-before/P12 retain the reported V-shaped depression
against the cliff. Grass was not present in this capture; it is not grass
acceptance. The snapshot global-shader enumeration warning is diagnostic.

Eight isolated terrain/water sites were captured in before/. Bare green ground,
clear water and absent live packet simulation make those views unsuitable for
judging the original water appearance. Opaque blue diagnostic views preserve
actual geometry at P12 and P39; their materials are diagnostic only.

At P12, actual emitted triangles sample approximately 6.315 m beside a 7.95 m
lower reach. A 601-point scan beside the high bank finds 4.109342 m minimum
and a 3.840657 m discontinuity between consecutive 1 cm samples. The new
regression fails both continuity and lower-reach constraints (601/603 asserts).

The coarse dry edge crosses an existing fine-grid water channel. Its shore
correction is reapplied to fine interpolation, manufacturing a low boundary
inside connected water. The final repair gives fine interpolation its own
physical dry-edge constraints and uses bounded coarse fallback corners. P12
is accepted narrowly; see corner-result.md for the rejected first candidate,
33 passing tests / 2,929 assertions and six game comparison pairs. Other water
reports remain open.

P39 wave exposure is now verified separately in turf-result.md. Static field
domains remain open; see origin-investigation.md. A GPU rest-state probe finds
neutral 0.5-centred ripple/packet textures through 90 frames, so initialization
bias is not established as the remaining animation-distance cause.

The recovered 12:05:48 video is archived as metadata and nine extracted frames
under video/. It has no F3 overlay. Its camera cutaway artifacts overlap the
previously repaired visibility issues; the water motion itself remains under
review, and its location has not been inferred as fact.
