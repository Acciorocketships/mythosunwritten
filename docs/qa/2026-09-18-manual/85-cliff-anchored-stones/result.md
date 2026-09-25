# Cliff volume and physical shelf-distance review — pass 85

The selected production change gives the existing detached Nature-rock profiles wider, taller and deeper physical footprints, with more separation between their centers. It also corrects a source of unwanted smoothing: the ledge protection used only x/y separation and projected complete long support triangles into vertical protection intervals. A shelf several metres farther out could therefore flatten unrelated rock behind it. Protection now measures the actual 3D separation from retained support vertices. The crown envelope, full blend-search radius, fixed tread vertices and connected-face slope bound remain active. No material, texture, shader-normal, crack network or native wall asset changes are selected.

Production is `scripts/terrain/field/CliffRockCrags.gd`, frozen here as `tests/fixtures/september18/cliff-anchored-stones/final.gd`. The rendered `natural.gd` differs from the final only in comments. [Production delta](production.patch).

## Visual judgment

Five matched native game-context pairs were inspected: P12 front/side, P17 front, P20 oblique and P05 vines. They rebuild rock and plant visuals on the pass-83 fresh-world snapshot with the same camera and surroundings. P20's exposed lower faces and P17's oblique shoulders gain more visible irregular rock depth. P12 retains its wider curved shelf, pointed turf ends and flush upper attachment. The selected tall-wall view has broader uneven rock forms than the dense small-facet alternatives. [Current game view](natural-world/P20_oblique.png) · [Before](before-world/P20_oblique.png) · [Current tall wall](natural-tall/oblique.png).

This is a scoped improvement, not acceptance of the entire cliff composition. Broad smooth areas, long upright organization on tall walls, the inherited straight panel end visible in P17 and angular lower turf joins remain. The selected change does not replace those underlying shapes. P12/P20 reported-camera +8-degree views were also inspected; they retain the same nearby ledge/face structure. The harness additionally writes other original-camera/offset captures, but these are not all judged, and previously embedded original camera positions are not claimed as clear views.

## Rejected studies

- `candidate`: independent anchored convex volumes produced attached rounded pods.
- `rooted`: extending those volumes downward retained broad soft panels.
- `integrated`: composing Nature bumps before tread construction made relief clearer but introduced jagged/pinched joins.
- `filtered`: smoothing the integrated field retained overly soft forms and uneven ledge joins.
- `broken`: seven-plane physical stones added too much small-scale relief on tall walls and failed the upper projection envelope (0.681 m excess).
- `rocklets`: shorter supports and the crown budget reduced that issue but left folded-looking formations.
- `faceted` and `spatial`: plane-defined stones passed their focused geometry checks but looked too densely embossed on the tall wall. Their replacement stone shapes are not selected; the physical-distance correction is retained with the Nature profiles.

A separate native town-corner stock study (`town-native-corners`) was inspected in front/side views. It leaves bright mismatched vertical strips and is not selected. Pass-84's bottom-soffit repair remains; T05 vertical joints remain open.

## Verification

The new regression gives one owner a front face and a physically distant shelf. The original geometry loses 447 face samples merely from the shelf's projected x/y overlap. The selected version loses zero while retaining 4,692 measured relief samples. The initial red harness omitted resource preparation and is invalid/excluded; the corrected red run fails the intended invariant with no script error.

Native Godot physics probes hit all 345 changed sampled faces. Across 887 contacts there is one unchanged historical miss; maximum measured contact error is 0.00001114 m. This does not claim every possible contact or a new full-world character walk.

The full focused/integration run passes **35 tests / 113 assertions**. It retains 31 closed photographed shells, all nine corner checks, 57/57 covered ledge samples, 460 treads with no missing endpoints or steepening, and 311 actual grass-worker roots with no escaped or buried patches. Full/split grass ownership agrees. Ordinary/tall turf area remains exactly 69.137629 / 48.922539 square metres. Added relief has zero excessive transitions among 191,364 short-edge incidences; the prior ledge-transition probe is 0.1544 m. The upper crown and projection-envelope checks pass. See [test log](logs/cliff85-final-tests.log) and [native contacts](physical-changes.json).

Game comparison replays retain frozen terrain, grass and collision; they are visual controls, not a new streamed-world startup. Native collision is tested separately from the changed mesh. No full-game performance, hydraulic, streaming, village or complete original-register acceptance is claimed.
