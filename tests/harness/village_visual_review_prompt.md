# Generated village visual falsification review

Your task is falsification, not approval. This review is successful when you find a
real, evidenced issue. An issue-free report is not a successful outcome by itself and
must never be produced from a cursory scan. Inspect every capture critically. Do not
reward the implementation for looking plausible; try to prove it wrong.

Inspect the original-resolution image for every screenshot id before using a contact
sheet. For every finding, report:

- screenshot id(s), seed, settlement id, and camera recipe;
- the precise visible region and pixel evidence;
- the violated invariant;
- severity P0–P3 and confidence;
- whether an adjacent or reverse view corroborates it;
- exact reproduction metadata from the sidecar.

Retain uncertain observations as suspicions. Do not inflate them into findings without
visible evidence. Conversely, do not dismiss a defect because another part of the
village looks attractive.

Try to find:

- a weak or absent ground market: the central streets should form connected right-angle
  alleys with stalls along both sides, not a plaza-only cluster or wheel-and-spokes plan;
- a weak stacked read: the dense core should put nearby inhabited roofs, doors, alleys,
  platforms, and overhangs above or beside lower activity, including visible 6 m
  half-level offsets and irregular terrain-derived floors rather than uniform tiers;
- broad empty suspended decks, skirts beneath terrain-supported building portions,
  platforms that do not serve nearby same-floor doors, stairs that fail to connect
  different-height public surfaces, or long aerial links between distant buildings;
- an inverted density gradient: ground buildings should cluster around the market and
  become sparse only in the connected 36–60 m outskirts annulus;
- asset monotony despite the reviewed four furnished house designs, blue/orange themes,
  and four physically enterable tent families available to production;
- floating, buried, stretched, unsupported, or terrain-intersecting structures;
- foundation holes, exposed outline rings, terrain bleed, bad thresholds, and doors
  that are visually or physically inaccessible;
- overlap, z-fighting, cracks, missing faces, broken pivots, and scale mismatch;
- misleading stairs, railings, vertical transitions, headroom, or passages;
- structures/supports crossing roads, alleys, protected entrances, or one another;
- path discontinuities, dressing intrusion, block seams, or partial streaming commits;
- excessive repetition, implausible radial/starburst composition, weak silhouettes,
  unreadable entrances, and incoherent districts;
- camera/roof clipping, occluded interiors, and views that fail to expose their named
  target.

The report is incomplete until every screenshot id is accounted for and every P0–P2 is
either pinned for repair, explicitly accepted by the owner, or dismissed with
pixel-level or invariant-level evidence.
