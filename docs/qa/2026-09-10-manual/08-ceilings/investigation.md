# Tunnel ceilings and city masonry — investigation record

Photos 4, 8 and 9, seed 2697992464. Issue 8 is accepted; see result.md for final evidence.

The initial native probe found six singleton exposed stone faces in photos 8/9
whose full two-band modules extended down through an unowned band. A failing
native-triangle regression confirmed their lower vertices at 2.838947 m instead
of at least 4.33 m in the photographed town's local coordinates. Fit the stock
to the one owned band while retaining its original top interface.

Candidate 1 passes that regression and removes the tails from photos 8/9.
All 18 game views are in `candidate1`; photo 4 still mixes the KayKit garden
rock with the SFV tunnel masonry. Height correction alone is insufficient.

Candidate 2 fits full native city masonry beneath the original grass lip.
A four-orientation native-ray regression rejects its square corners: actual
stone vertices extend beyond the rounded grass silhouette. This is not accepted.

Candidate 3 retains every source face and UV while fitting the two incident
masonry walls to one continuous rounded profile. The shared mapping fits within
the four-chord quarter circle of the native lip. Straight runs retain native
meshes as instances; corner faces use the existing main-thread-prepared wall
arrays and ordinary worker surface payload. Logical turf-wall collision remains
with the same wall owner, shortened only when the lower band is not owned.
Native triangles and UV preservation pass in four orientations. The one-micrometre
silhouette witness tolerance classifies float32 shared edges; it does not move
source vertices. The 24 related tests / 4,788 assertions passed after supplying
the existing prepared interfaces to the compiler's audit path. Additional native
preservation checks pass (2 tests / 57 assertions). Final verification continues.

This changes the earlier September 8 choice of terrain rock under city gardens,
in response to the owner's explicit September 10 request for coherent city
materials. The rounded grass lip itself is unchanged. Ordinary world terrain
continues to use its existing rock. Nearby prefab, grass, rail and roof views
must be inspected before this issue is accepted.

The short-course ownership also needs to reach facade-miter selection. A full
facade end cannot be removed on the false assumption that its neighbor still
closes two bands. This collateral regression is being checked before final renders.

Baseline game images are `before`. Rounded player/crosshair coordinates permit
matched camera reconstructions, not recovery of the original full-precision pose.

The facade-miter regression failed before the ownership fact was passed into
miter selection, and now passes. The 7-test / 202-assertion run includes the
previous photographed wall-return regressions. Final game rendering is in
progress in `after`; candidate3 predates the last miter/audit adjustments.

The isolated baseline retained accepted issues 1–7. Its assembler SHA-256 is
`2f8f360403bc4438241ffd7c5188e9ec188bcf27399aaec183e9526177a9b6c5`: starting
revision plus the accepted private-floor recess and exposed raised-turf soffit.
The compiler used the recorded accepted skywalk candidate. A try/finally capture
runner restored both current source files byte-for-byte after baseline captures.
The two frozen towns had identical public clearance in the initial comparison:
120 cells / 175 crossings and 297 cells / 424 crossings. The final miter change
is being resurveyed.

Final source checks pass: focused 25 tests / 4,806 assertions; production 31 /
1,131; facade return plus new ceiling tests 7 / 202. Removing repeated ceiling
tests leaves 57 distinct tests / 6,021 assertions. Both final clearance records
match their baselines exactly, with zero blocked samples. All ten isolated
native before/after/difference triptychs were inspected, including collateral
photos 1/2/3/5/7/12/17. The prefab floor, grass silhouette, public guards and
skywalk bearings remain intact. Photo 3 is pixel-identical in that fixture.
Photo 12 additionally exposes the preexisting native timber when the incorrectly
hanging stone is withdrawn. Final full-game nearby comparisons remain pending.

Final full-game review completed: all 18 pairs and the three complete image/difference pairs pass. All camera records match. See result.md.
