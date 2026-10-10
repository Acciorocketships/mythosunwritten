# October 3 central cross-gables

The remaining single 10x2 roof in 6/large (house.013) and 8x2 roof in
13/large (house.035) were the old 20% plain-range draw (.9479 and .8914),
not clearance rejections. Very elongated ranges (length >= 3*depth) now always
seek a legal transverse pavilion. That same seeded minority tries a central
pavilion first; other rolls prefer an end. Both strategies fall back to the
other positions. Central wings retain at least two modules of hall on each
side. Every candidate still passes roof-height and neighboring-gable checks,
uses existing occupied rooms and joins through KitRoofJunctions. Shorter ranges
can still be plain. No new room footprint or relaxed headroom rule.

Native 6/large and 13/large overviews inspected: their formerly uninterrupted
long roofs now have three-part crossed silhouettes. Both images are retained
here. This improves the targets but does not settle all town silhouette/art work.

The wider photo-town test found 40 missing gable samples in compact town
1998423929946073270, house.010. Re-running with the previous range rule produced
exactly the same failure. It was the existing native turret cap replacing part
of that gable: the audit counted the cut gable but omitted its cap. The audit now
reconstructs the measured cap interior from present native cap parts, not the
clipping request or an AABB. Interior slices share boundaries without artificial
1cm gaps. Existing roof/wall margins remain unchanged. A negative-control test
removes the native caps and correctly restores the hole failure. Both native
side views of the affected junction were inspected: closed junction; the close
framing clips the finial, so these images judge junction closure only.

Validation: range roofs 6/6, roofline variety 8/8, town towers 5/5: 19/19,
9,931 assertions, 88.039s. Six-town finished-roof/public-air audit 1/1,
19 assertions; zero finished walking-air intrusions in all six payloads.
Raw skin cuts and gable contacts remain separate diagnostics. No new character
walk for this roof-only increment. No commit/PR.

Open: broad retaining-wall faces, remaining silhouette variety and integrated
performance/regression classification. Native terminal-fallback and joined-range
fixtures still require classification. The full redesign is not complete.
