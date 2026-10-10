# Compound end-facade windows — October 4

The compound house now exposes both ground-floor gable panels as window
sockets. Long-wing corners retain their adjoining side-wall posts. Short-wing
end panels own their outer posts, so replacing those panels explicitly adds
native Wood_Beam_3x30_2 posts at their original corner lines. The post's native
height is preserved and its bottom meets y=0; horizontal scale 1.2 makes its
roughly 0.346 m width match the approximately 0.406 m authored end post.
No generated material or custom cuboid is used.

The first render revealed that the short return panels did not carry the
missing outer posts; this was corrected before accepting the facade change.
The final front/back samples retain visible corner timbers and coordinated
window families. Extended outer side panels still have blank areas: these
samples are not the final production art target.

Evidence:

- Eight source reconstruction tests / 10400 assertions pass unchanged.
- Twenty seeded facade layouts: 1 test / 3721 assertions pass. The two added
  native posts are explicitly accounted for; roof and non-socket parts retain
  their original poses and modules.
- Actual window glass clears the roof at every middle/end socket on both
  X-extended and Z-extended samples: 1 test / 8 aggregate assertions.
- Native post triangles intersect corner probes at y=.05, 1.5 and 2.95 m in
  three size combinations: 1 test / 21 assertions. Each has exactly two added
  native posts, corresponding to the two replaced short-wing owners.

Still required: foundations/entry support, richer side facades and projections,
corner-tower rules and production placement/access/clearance integration.
