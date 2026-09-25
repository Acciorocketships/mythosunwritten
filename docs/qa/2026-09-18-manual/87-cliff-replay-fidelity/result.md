# Correct corner replay — pass 87

The transition-context review harness reconstructed every saved rock as a straight wall, including four convex corners. It inferred the straight width from each corner's asymmetric bounds. That created false flat panels and abrupt ends in the pass-84–86 rebuilt context images. The underlying production corner and the directly saved pass-83 world were not rectangular panels. Those earlier corner-image judgments are superseded here; their straight-face and separate tall-wall evidence remains scoped as recorded.

Saved formations now retain a construction recipe: wall versus corner, dimensions, end conditions and seed. The review helper uses that identity and preserves the saved buried floor. Legacy snapshots migrate only recognized backing shapes. Native four-metre storey heights are recovered exactly rather than accepting float32 AABB rounding as a different height.

A native-renderer inventory of the pass-83 world finds 35 nearby formations, including four corners. Rebuilding all 35 with the original frozen generators now produces **exactly identical rock and turf arrays**, with zero mismatches. The first audit exposed sixteen 4 m height-rounding differences; these were corrected before acceptance. Five replay tests plus the unchanged physical-variation regression pass **6 tests / 17 assertions**. The initial legacy-corner regression fails before the helper repair.

[Identity audit](historical-identity.json) · [Corrected outer corner](final/P17_front.png) · [Corrected inner-corner context](final/P12_front.png).

This pass changes review reconstruction and adds production snapshot metadata, without changing production geometry. The corrected outer corner exposes real fanlike ridges, and the inner corner lacks dressing; these are the subject of pass 88. Full cliff art and the remaining original judging register remain open.
