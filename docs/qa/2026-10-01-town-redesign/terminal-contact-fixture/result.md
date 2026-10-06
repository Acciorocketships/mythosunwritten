# October 3 — stable positive terminal-roof regression

The former 9/grand positive terminal count went stale after procedural layout
changes. Do not infer that the fallback or the contact ceased to need testing.
The historical rejection log `/tmp/town-grand9-seams.log` recorded the actual
contact: native partial gable strip at (-8,8,1)/r0 beside
`roof.square.blue.dormer.left` at (-7,6,4)/r3. Their measured envelopes overlap
only at the party contact. The regression now reconstructs those recipe poses
with explicit native room supports and socket bonds, then calls the actual
`_terminal_macro_cap_fallback` transaction.

Without the required neighbor closure it rejects every handed combination as
an unrelated roof intersection; the probe stays at its original three units.
With the closure it admits two complete native terminal strips. Exactly the
contacting strip gains the prior roof seam. Both commit with their real bearing
bonds, leaving no unrelated visual-envelope conflict. This test fails if the
fallback stops calling the measured-required-seam helper. It neither broadens
the seam tolerance nor changes any production geometry.

Current 9/grand still has its separate full-town test: valid fabric, native roof
closure/dormer/payload checks, zero finished public-air intrusion and zero
floating mass. The other native/mixed town cases also remain in the suite.
The first full-file run passed all three whole-town tests; the small fixture's
attempt to validate a nonexistent public street network was rejected. It now
asserts its actual contract (atomic roof admission/bearings/visual contacts),
while whole-town validation stays in the separate test. Focused positive test
passes 7,258 assertions / 5.247 s; most assertions are recipe registration.
The full October isolated regression includes a fresh run of this complete file.

No new render is needed for this test-only change. Existing terminal-roof art
and broader town art acceptance are not re-certified by this fixture.
