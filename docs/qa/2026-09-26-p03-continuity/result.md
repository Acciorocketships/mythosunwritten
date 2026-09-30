# P03 constrained slopes and rock joins

**Current reviewed build: iteration 07, all nine chunks rebuilt.** The owner's [annotated image](owner-annotated.jpg) reopened the prior pass. Its unconstrained slope measurements did not prove acceptable shapes at the marked water-constrained cliffs.

## What was wrong

1. **Sharp, overly steep marked edges.** A fixed five-metre water cut could halve a 12 m cliff's height in the first half metre, overriding the rounded dry profile. Rock carving then reintroduced metre-scale cuts beside otherwise rounded crowns.
2. **Oversized right-hand shelves and thin fins.** A third of the rock blocks were intended to have no bench, but instead used a three-times-larger bench interval. Winner-only changes between block phases made narrow fins and slots. Large displacement from the underlying hill could still create slab-like projections even after removing single-cell spikes.
3. **Additional angles were needed.** The P03 camera concealed the side profile of these shapes. Layer controls confirmed that the fins belonged to the generated rock surface, not the leftover native walls.

## Repairs

- Carry a parabolic continuation of the dry bank into water. Preserve a submerged two-metre-wide receiver between opposing banks; tiny wet patches inside the permitted bank runout cannot cut isolated slabs into the slope. Round the bank-to-channel join.
- Protect the whole crown transition from bedrock carving. Exact-site tests check all four marked upper sections, including the foreground corner, rather than only a dry synthetic wall.
- Make unbenched blocks follow the sloping surface. Blend neighboring block phases, bound the rock's displacement to 1.25 m from the hillside, and remove only artificial single-cell reversals. The original surface-net mesher and stone material remain.
- Retain the fitted foot-boulder assets without extra terrain ellipsoid mounds. Their bases are already buried against the sheet; these redundant mounds could protrude and make adjacent chunks shade their common boundary differently.

## Evidence

- [Initial constrained-shoulder failure](constrained-red.txt): 12 m → 6 m in the first 0.5 m.
- [Rejected candidate channel test](channel-candidate-red.txt): simply widening both banks could dam the channel. The final implementation retains a submerged receiver.
- [Exact marked-crown failures](native-crown-red.txt): carving displaced points by up to 2 m in the first 2.5 m of the shoulder.
- [Rock-fin regression](fin-red.txt): a 4.04 m reversal across a single half-metre cell. This alone was insufficient for art acceptance, so the later candidate also bounds the entire rock patch's displacement.
- [Foot-mound regression](foot-mound-red.txt): a neighboring rock's presence changed shared mesh positions/normals. Bedrock now has the same continuous sheet with or without a halo's foot assets.
- A compact [native-input fixture](../../../tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz) preserves terrain, water and exclusions at the actual marked site; it does not freeze expected output geometry.

## Visual provenance

Seed 2697992464; native production world with grass, collision and the same P03 camera as the annotation. `00` is the fresh baseline. Four original cameras are matched: `p03`, `crest`, `wall-overview`, and `ledges-above`. The final P03 camera remains above the surface but nearby rock occludes its right foreground; that pair records the change, and is not used alone as evidence of acceptable geometry. The crest and overhead views expose the joins.

The initial `ledges-side` camera was inside the hill and is excluded. The initial `ledges-front` view had poor foreground occlusion and is also excluded from the final comparison set. Replacement exterior cameras are `(516,49,963)` and `(508,50,934)`, both looking toward `(497,40,955)`; their target hillside is visible without placing the camera inside it. These are additional views, not falsely labeled matched baseline pairs.

Iteration `01` repaired the water cut; `02` added exterior views. Iteration `03` was rejected after visual inspection: some slots were gone, but large protrusions remained. Iteration `04` is also rejected: an over-broad minimum blend recessed otherwise tangent crowns, and a native normal seam remained. Neither candidate's passing contact samples constitute final art acceptance.


## Additional shader finding

The exterior view revealed isolated green triangles on the stone. A back-face-culling control retained them, while changing grass coverage from facet normals to continuous surface normals removed them. These were material cutouts, not absent triangles. Stone still uses facet lighting. See [before / after / pixel difference](shader-triangles.jpg).

## Programmatic verification

- **48 focused tests / 689 assertions passed**: [30 shape tests](shape-tests.txt) and [18 neighboring profile/support tests](neighbor-tests.txt). The eight new tests cover tall wet crowns, opposing-bank clearance, tiny wet patches, the actual four marked crown profiles, unbenched blocks, narrow rock reversals, bounded rock displacement and foot-asset halo independence.
- [Six real production-character walks](crown-walks.json) cross three marked crowns in both directions, all on floor and passing. These prove the upper transitions, not that every exposed stone face can be climbed.
- [Exact-site profiles](native-profiles.json): the first 2.5 m of the four marked crowns have maximum sampled grades of 20.2°, 26.0°, 26.8° and 20.2°. The two rear sections formerly fell 0.6 m in their first half metre; they now fall 0.026 m and 0.020 m. This is a crown measurement, not a whole-bank grade.
- Final native rebuild: 115 sampled surface contacts, including 109 exact exposed contacts and six covered faces, with zero misses; 173 grass roots with zero misses; 1,449 shared height samples differing by at most 3.2e-14 m; 224 shared native vertices with exactly matching normals. See [surface audit](surface-audit-final.json), [grass audit](grass-after.json), [height seams](seam-after.json), [normal seams](normal-seam-native.json).
- All nine surrounding chunks were rebuilt before final captures. No new script or shader errors occurred during that rebuild. Earlier rejected-candidate failures remain in the historical log.

## Scope

This follow-up addresses the two marked plateau edges and the right-hand rock geometry in the latest annotation. The original thirteen-image register is not declared globally complete. Wet channels necessarily constrain the lower bank; exposed rock risers remain steeper than walkable grass crowns. No claim of universal cliff walkability is made.


## Final visual review

Inspected all four native before/after pairs and their amplified pixel differences:

- [Marked crowns, closer view](diffs/crest-review.jpg): rounded foreground and rear transitions; the old broad shelf is withdrawn into the hillside.
- [Wall overview](diffs/wall-overview-review.jpg): upper slopes continue into the marked flat tops; constrained lower water faces still expose steep rock.
- [Overhead](diffs/ledges-above-review.jpg): shows the rock patches joined to the hillside, with the oversized intermediate benches removed.
- [Original P03 camera](diffs/p03-review.jpg): preserved for transparency. Its right foreground is now obscured by nearby rock; this is not an adequate stand-alone review view. Camera ground clearance is 5.45 m.

Additional requested angles: [front](07/ledges-front-exterior.png) and [side](07/ledges-side-exterior.png). The side view makes the remaining narrow exposed rock risers visible; they are attached to the hillside, but remain angular and steep. The broad original art register remains open rather than treating contact tests as universal visual acceptance.

Pixel differences verify where rendering changed; grass animation also contributes small differences. They are not automatic quality scores. Iteration 06 was the shader-only comparison; 07 is the complete surrounding rebuild.
