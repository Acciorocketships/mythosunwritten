# Raised-district proportions

Accepted an early height policy for houses whose entire footprint stands on the raised district’s plinth. Their optional room roll is bounded by the planned massif crown, while reserving a complete room above neighboring passage headroom. Required upper streets and carried rooms retain `_building_top` authority. Ground and mixed-datum houses keep the prior roll. This is topology-derived, before optional balconies/overhangs become support obligations; there are no seed or coordinate exceptions.

## Result and explicit tradeoff

In 63/grand, source houses .010/.012/.015 previously all had five storeys above the raised datum. They now have three/four/three. In 103/grand house.019 and 83/grand house.011 shorten from four to three. The other seven sampled towns have identical source plots.

All existing ceilings within seven bands are preserved at exactly the same walk-quarter addresses in ten towns. Total coverage is **482→468**, because 63 loses fourteen distant ceilings at 8–11 bands overhead. One redundant high bridge-house also disappears with its endpoint storeys; the town retains five skywalks, including the low crossings. We accept these explicit losses of distant upper mass for the requested shorter, less apartment-like silhouette. This is not a claim that every old room or crossing survives, nor a revised definition of the overall redesign goal.

The freed crown space admits another supported corner turret in 63: one→two. Other towns’ turret counts remain unchanged. All ten towns have zero detected floating masses and roof/public-air intrusions.

## Tests and actual player evidence

- Four new behavioral tests / 197 assertions pass: raised crown proportions, required upper street/carried room support, unchanged ground/mixed-datum rolls, and neighboring overhead-room budget. Restoring prior code makes three of these tests fail (47 assertions), confirming the cases exercise this change.
- Existing back-room host and low-skywalk tests also pass: four tests / 31 assertions. Together, eight relevant tests / 228 assertions pass.
- The older September 29 platform suite remains red: five of six tests fail with **exactly the same 501 assertion failures before and after**. They include superseded native asset/hash expectations and existing layout/gate failures. No baseline assertions were weakened; this is not a global green result.
- Actual player: 63’s five skywalks in both directions, 10/10; 103’s three skywalks in both directions, 6/6. All pass.

## Native review

Matched 63 street views show the former shafts replaced by lower roofed houses while the nearer bridge still closes the street. Overview and focused renders of all three changed towns were inspected. The newly admitted 63 turret is supported on its host corner, with the same roof finish and a closed cap. The shortened houses in 103 and 83 retain roofs and facade attachments.

The automatic turret camera chose an unrelated prefab turret; the explicit new-corner camera is the actual generated placement. The reverse corner camera was inside nearby geometry and is excluded from acceptance. The first close 103 camera was too tight to judge silhouette; `after-103.png` is the wider replacement.

## Remaining work

This is a bounded improvement. One raised four-storey house remains in 63, and separate tall ground/mixed-datum shafts are visible in other towns. They need room/route/roof composition rather than this plinth-specific policy. The wider building grammar, enclosed massif geometry, court integration and overall art acceptance remain open. No claim of full redesign completion.
