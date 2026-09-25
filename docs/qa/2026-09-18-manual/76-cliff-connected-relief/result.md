# Connected physical bumps on cliff sides

Production now adds sparse, asymmetric rounded shoulders to the existing closed
cliff mesh. These change actual vertex positions and collision, not the stone
shader, normal map, or color texture. The existing curved turf ledges remain.
The broad cliff-composition review remains open; this is an incremental response
to the request for more physical bumps in-game, not full art acceptance.

## Retained implementation

`CliffRockCrags.gd` samples finite compound stone fronts with independently
varying width, height, depth, lean and slope. Deterministic world-coordinate
selection leaves quiet stretches between formations. Larger walls use broader
forms. A bounded downward bearing retains support beneath each front; the
additional volume fades out in the upper quarter, preserving the repaired crown.
Actual foot sampling includes the added depth before choosing the buried base.
The rendered shell, collision triangles, placement bounds and plant projection
continue to consume the same geometry. Preparation/worker resource rules are
unchanged. No new material or CSG operation enters production.

The photographed wall at seed 2697992464, anchor (-480,32,-253.5), has 485
sampled exterior vertices displaced by more than 0.35 m across 55 columns.
Maximum added depth is 1.3028 m; crown displacement is zero. The unchanged
control fails both the physical displacement and width assertions. The tall
fixture retains 31,129 quiet samples out of 38,081 relative to the prior
outcrop control; the denser candidate failed this existing requirement.

## Visual review

`production-world/` contains the 17 established frozen-world camera views,
including photographed ReviewCam poses and the supplemental P20 oblique.
P17 front, P12 side, and P20 oblique were inspected. `production-tall/` contains
the 32 m oblique study. These reconstruct current cliff/plant geometry against
frozen terrain; they are not a fresh full-world load or new character traversal.

The retained bumps create local volume and less uniform lower faces. The game
view still has broad smooth areas, and the tall study still has inherited long
uprights and thin ledges. These larger composition concerns remain open.
The shader/palette was intentionally not used to manufacture the added detail.

## Validation

The final run passes **24 tests / 78 assertions**. All 460 measured tread
endpoints remain in the physical shell, with zero steepened caps. The actual
grass worker places 385 supported patches, with zero escaped or buried roots.
Godot collision rays verify 334 turf contacts with zero missing/wrong bodies
and a maximum error of 0.000006914 m. Results are recorded in
`production-tests.log` and `physical-treads.json`. The test suite covers actual displacement, crown
and lip limits, tread slope, shell closure, turf coverage, corner ownership,
public/wet admission, detached workers and actual grass worker roots.

The tread regression now observes semantic endpoints immediately before and
after the real shaping pass in a test-only instrumented script. It verifies
those endpoints exist in the final physical shell. This preserves the original
grade assertion while allowing legitimate changes in endpoint depth. Its
negative control disables only the previous width/drop correction and reproduces
182 steepened treads. No audit data was added to production geometry.

## Rejected experiments

All trial sources remain under the matching fixture directory. Fine relief,
continuous/coarse relief, unclipped depth, source-profile changes, finite
bearing and joined native-rock fields failed the art review: they retained
plain faces or produced small creases/attached-looking patches. The physical
triangle probe confirms the plain region is a densely sampled slope; missing
mesh resolution was not the cause.

The exact polyhedral CSG union preserves closed volume but looks like separate
plain blocks attached to the wall. It is not shipped. Dense compound shoulders
make small bumps too pervasive on tall walls; unrestricted high placement also
makes an upper bulge. The final sparse selection and upper fade replace those
studies. `dense-production-*` retains the superseded evidence.

No broad performance, startup, hydraulic, streaming, full-suite, or universal
cliff-art acceptance is claimed. Other items in the original issue register
remain unchanged.
