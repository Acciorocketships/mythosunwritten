# Larger shallow divisions with a thinner attachment skin

Production keeps the large, geometry-linked geological sections, long curved ledges and local rooted lower rocks. The independent covering skin now uses half the geological displacement and a 1.09 m base instead of 1.16 m. The existing full-height, root-derived envelope still constrains the body. This reduces the remaining early projection beneath the turf without fading away the entire upper wall's detail. No small random crack patches or extra shader cracks are introduced.

This is a scoped improvement. The tall wall still has excessive upright organization, and some game faces remain broad and plain. Overall cliff art and the original judging register remain open. See [matched comparisons](comparison.md).

## Alternatives and visual judgment

The first two candidates investigate lower composition. `fanned` scales neighboring ledge support to ordinary wall heights; its proposed bearing test changes from red to green and all eight focused tests / 47 assertions pass. `layered` adds independently sized Nature bodies with released lower projection and also passes eight tests / 47 assertions. Both remain unselected: the native yellow-world views still contain broad plain faces and ramp-like lower masses. These mechanisms are not in production.

`taper` spreads the full cover transition over wall height and passes eight focused tests / 16 assertions, but reveals the repeating native backing. `skin-taper` retains the cover and fades its independent relief: eight tests / 16 assertions plus fourteen integration tests / 50 assertions pass, yet the tall upper wall becomes blank. `low-cover` retains full relief on a thinner skin; it reveals periodic details in the joints and still fails the proposed upper-envelope bound (0.099067 m excess). Those variants are rejected.

`shallow-cover`, the selected change, keeps the broad partition layout while reducing the skin displacement. Native tall, reported and neighboring game views retain recognizable large divisions and continuous turf. The corner control uses the same mapped corner construction on both sides of the comparison. The prototype and production sources differ only in explanatory comments.

## Geometry and regression evidence

`collar-red.log` records the original skin exceeding the proposed near-crown envelope by 0.231739 m. The selected candidate reduces that excess to 0.068267 m over 152,478 samples, below the unchanged 0.08 m tolerance. This is a relative projection bound over the upper quarter of 16/32/64 m walls, not a claim of zero curvature or a measured perceptual score. The registered guard is `tests/test_september18_cliff_attachment_relief.gd`.

The selected prototype passes eight focused tests / 16 assertions and fourteen integration tests / 50 assertions. The complete production run, including the basal footprint guard and registered new test, passes **23 tests / 71 assertions** in 265.666 seconds (`production-tests.log`).

The old basal test treated any upper movement as failure, including inward movement explicitly requested by the owner. `basal-original.log` preserves that failure (0.1883 m absolute change). The corrected test measures outward change, retaining the original 0.001 m bound. It still checks both recessed and widened root intervals and the original maximum added reach. Current upper outward change is zero; 228 of 356 root samples widen relative to the pre-basal control, 102 remain effectively unchanged, and maximum added reach remains 3.008 m.

The candidate retains 57/57 reported cap probes, closed and nondegenerate photo shells, and five connected upper ledges spanning 6.25–40.25 m. The local lip-bearing survey finds zero breaches over 32,334 samples; maximum recession is 0.092 m. The grass worker roots 416 whole patches without escaped or buried roots. Corner closure at 16/32/64 m, all orientations, detached workers, complete wet/public exclusions and independent halo ownership pass in the candidate integration run.

## Native capture and fresh verification

Each ordinary game variant has seventeen frozen Forward+/Metal views. Three cover variants also have five tall views each, and the selected corner control adds one view. Frozen scenes retain old terrain, grass and collision; they verify appearance, not fresh admission or walking.

The first fresh run omitted the harness's required `--offscreen` flag and failed on a missing capture viewport. It was stopped explicitly and is excluded (`fresh-P12.log`). The corrected run enables `--offscreen --grass` and completes at **425.430 s** with three native captures and a new saved world. The grass capture reports 53 committed tiles / 14,880 instances, with 11,683 visible. The snapshot utility emits its known editor-only shader-parameter warning; saving and all captures complete with exit zero. The old fixed actor position intersects the changed rock, so that screenshot pose is not presented as evidence of player support.

Twelve actual-player ledge walks (both directions on six ledges) pass against the fresh world's collision. Each travels at least 1.7 m, retains ground support and records no underside contact. A separate native terrain survey finds 368 rooted-foot samples with zero exposed or missing ground contacts. These validate the inspected location, not universal traversal or loading performance.

No water, town, streaming or biome implementation changes are included. No global or full-suite acceptance is claimed. Production source identity and all retained study evidence are recorded in `source-identity.txt` and `source-evidence.sha256`.
