# Local lower outcrops and retained upper profile

Production now adds locally wider, grounded lower rock to the larger shallow divisions and gradual upper profile selected in pass 51. This is a scoped improvement to the lower footprint, not acceptance of the complete cliff art. [Native comparison](comparison.md) shows the selected and rejected candidates.

## Change

Nature rock cross-sections supply independently shaped lower shoulders. Their rise is bounded by wall height and 14 m; widths and lateral positions vary deterministically in world space. Their widest bearing carries downward to the foot, rather than curling back inward beneath a protrusion. Added depth fades above the lower part of the wall and is applied after the existing upper-profile constraint. Ground seating uses the expanded footprint. The upper wall therefore retains the restrained pass-51 silhouette.

The first candidate exposed three nearly coincident ledge channels. Widening the existing ledge merge interval from 0.3–1.0 m to 0.7–1.4 m resolves those contacts. Corner quantization also collapsed two tip triangles; coincident mapped vertices now suppress only those zero-area triangles. Actual shared-edge closure is checked on 16, 32 and 64 m corners.

No material, water, biome or streaming production changes are included.

## Red-first and regression evidence

- `red.log`: the original production adds zero visibly wider roots at the two saved photographed formations and fails the new footprint invariant.
- `spaced-tests.log`: 356 root samples retain 102 unchanged positions and widen 228 by more than 0.5 m. Maximum added reach is 3.008 m; maximum upper-face change is 0.000101 m. The independent upper-envelope survey has zero excess over 304,189 samples.
- The first candidate, constant-tread alternative and narrower merge leave three, three and one channel failures respectively. The selected merge has zero, with turf at all 57 reported cap probes. Thirty-one photo shells remain closed and nondegenerate. Four major connected upper ledges span 6.5–40.75 m.
- `production-tests.log`: final production passes **20 tests / 65 assertions** in 238.679 s. Coverage includes the footprint, upper envelope, channels, turf, closed photo shells, long ledges, grass support, corner closure, wet/public exclusion, orientations, detached workers and independent halo ownership.
- Grass sampling retains **407 supported roots**, none escaped or buried. This is fewer than the immediate pass-51 control's 450; the test also contains an older 176-root reference, which is not the immediate comparison.
- `closed-tests.log`: the corner correction passes nine assertions with no bad edges or degenerate triangles at all three heights.

The registered footprint test is `tests/test_september18_cliff_basal_rocks.gd`; the identical fixture was exercised in the production run. The later `registered-test.log` selected only the existing corner test and is not an additional footprint run.

## Native review and fresh world

`spaced-world/` contains 17 Forward+/Metal captures in saved frozen production context. P20 oblique and the P05 close view show locally wider feet while preserving the upper attachment and turf shelves. Large central faces remain too plain. Frozen captures retain old placement and collision and do not prove fresh admission or walking.

`fresh-P12/` is a newly generated nine-chunk native world with three saved camera poses. Startup takes **419.473 s**, an uncontrolled observation rather than a performance comparison. This capture omitted `--grass`: it verifies fresh geometry and terrain, not regenerated grass blades. The historical fixed actor pose intersects the changed rock and is not support evidence. A snapshot-related editor-only shader-parameter warning occurs, but saving and all three captures complete with exit zero.

`walks/walks.json` records **12 passing actual-player traversals**, both directions on six ledges, against the fresh world's collision. The actor travels at least 1.7 m, stays supported and has no underside contact. These use the character's physics update, independently of the fixed screenshot actor pose.

`root-probes.json` and `isolated-roots-native.log` record **368 actual lower-closure positions, zero exposed roots and zero missing native terrain hits** across 26 nearby formations. In the isolated review scene, only added-rock collision is disabled, so rays measure the underlying terrain rather than overlapping outcrops. Native ground remains unchanged. The final native process exits zero.

Earlier root diagnostics are excluded: headless MultiMesh transforms could not identify the nearby formations; early corner selection included side vertices; repeated ray stepping through overlapping rocks produced missing or misleading hits. The final diagnostic selects downward-facing closure triangles and isolates the native terrain. Excluded JSON files and logs remain labeled for audit.

## Rejected alternative

`shaped-world/` scales the entire face with height. It exposes a dark tapered strip, reduces the longest connected upper ledge to 6.75 m and loses turf at six of 57 cap probes. It fails three of seven focused tests and is not selected. The first short-wall captures in `short/` show the intermediate tread candidate, not final production.

## Scope and remaining work

Lower support and physical seating improve. Broad upright faces, tall-wall composition and the overall visual target remain open. Fresh grass-render acceptance, global performance and the original water, town, streaming and biome issues are not claimed. The ongoing goal remains active.

Production SHA-256:

- `CliffRockCrags.gd`: `f82eb7a70cc9f64f7f755548f33a1d217ae4d2365a52342cb8a9d6c222a67fbe`
- `CliffCornerCrags.gd`: `bd2f4d8c71a5c831721243dd8e2fc3bc30d42a5f0865f970970e3a2f337af6d6`

`source-evidence.sha256` records the source and evidence files for this pass.
