# Raised courtyard canopy

The planted upper court can now shelter its surrounding walk with the actual native tree crown. Previously, fitting the full tree AABB inside its small planting island shrank the entire tree. Root and low-branch bands must remain supported inside the island; higher crown bands may cover a street only above its finished walking headroom. Selection tries measured native tree sizes, then the previous small fit, and can omit a tree if none fits.

`TownCourtTrees` uses the baked triangle height bands in `TownTreeProfiles`. Branches cannot enter recipe boxes, retained skins, finished native instances or generated pitched roof triangles. Exact triangles avoid treating all the empty space under a sloped roof as solid. Production and the native review harness pass the same finished geometry into courtyard dressing. Benches may stand below the crown but cannot enter roots, trunk or low branches; underplanting observes these same bands.

## Verification

- Final focused suite: 7/7 tests, 6,558 assertions, 41.681 s (canopy, courtyard seating, underplanting).
- The test builds the native 13/grand payload, checks that the full selected tree is actually emitted and that every measured crown band clears generated roof surfaces. It also checks walking headroom and the baked trunk collider. Synthetic cases reject higher obstructed walks, unsupported roots and intersecting roof triangles, while accepting empty space below a slope.
- Actual-player 13/grand courtyard route passed forward and reverse. This run preceded the additional native-roof gate; the final payload retains the identical tree pose.
- Final native courtyard views 0 and 2 inspected under `final/`: crown visibly shelters the court; benches sit below it; planting stays beside the trunk and the surrounding walk is clear. This is local canopy acceptance, not whole-town art acceptance.
- Earlier holdout probes admitted trees in 2/grand, 58/large and 31/large, with no native building-instance bounds intersections; 103/grand had no centre feature. Those probes preceded the exact roof gate and do not establish final holdout roof clearance.

The overview still has tall apartment-like massing and exposed climbing walks. Stepped-wing tower integration, shallow projecting wall facades and more supported enclosed streets remain open. Fresh quiet production timing passed at 7,545 ms against the unchanged 8,000 ms gate (149 assertions; total fixture time 55.333 s). This replaces the earlier 8,621 ms failure for this revision, but is one compact production site, not broad performance acceptance.
