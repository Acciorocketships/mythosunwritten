# September 12–13 consolidated manual review

51 unique screenshots and one 4.45-second video. The September 13 batch repeats 18 September 12 screenshots and adds three new screenshots (P32–P34). `sources.json` records exact paths, byte counts and SHA256s. Twelve originals have moved into `Desktop/game/town feedback`; their hashes match the original manifest. All 51 screenshots are available. The evening September 13 batch adds P35–P51, indexed in attachment order. Original overlays were inspected at native resolution. The original video was also recovered from that folder and its hash matches; its temporal review remains queued under issue 25. Photo IDs below are stable across this review, independent of attachment numbering.

The owner’s request controls this work. Annotations are defect reports/design references; historical acceptance notes are not fresh verification. The previous ground-only result is retained as historical evidence, but visibility acceptance is reopened by P33. No issue below is closed merely because an older test passed.

Each issue proceeds through reproduction → alternatives/root cause → failing regression → implementation → native matched renders, pixel differences and explicit visual judgment → nearby/temporal/physical falsification. Only then accept an issue. A rejected alternative may remain open while an independent defect proceeds; its pending work and evidence stay in the ledger.

Camera matching uses the screenshot’s rounded player/crosshair coordinates through `ReviewCam.solve_cam`; the overlays do not contain full-precision camera transforms. Save the reconstructed transform and viewport with every capture. Before/after pairs use identical transforms, scene data and frozen animation clocks. Compare annotated regions and unaffected controls; a pixel difference alone is not proof of correctness. Black or invalid captures are excluded and retried, never accepted.

## Source index

| ID | Reference | Reported issue(s) |
|---|---|---|
| V01 | [Screen Recording 2026-09-12 at 12.05.48 PM.mov](</Users/ryko/Desktop/game/town feedback/Screen Recording 2026-09-12 at 12.05.48 PM.mov>) | Water glitches during movement |
| P01 | [Screenshot 2026-09-12 at 11.56.57 AM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 11.56.57 AM.png>) | Floating water edge; ground cutaway reveals void |
| P02 | [Screenshot 2026-09-12 at 11.57.49 AM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 11.57.49 AM.png>) | Floating water field edge |
| P03 | [Screenshot 2026-09-12 at 11.59.20 AM.png](</Users/ryko/Desktop/game/town feedback/Screenshot 2026-09-12 at 11.59.20 AM.png>) | Near-camera obstruction should clear a larger screen area |
| P04 | [Screenshot 2026-09-12 at 12.00.30 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.00.30 PM.png>) | Timber/plaster wall blocks public path |
| P05 | [Screenshot 2026-09-12 at 12.00.37 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.00.37 PM.png>) | U-shaped stone fragments protrude into walkway |
| P06 | [Screenshot 2026-09-12 at 12.01.38 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.01.38 PM.png>) | Cutaway exposes house interiors |
| P07 | [Screenshot 2026-09-12 at 12.02.18 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.02.18 PM.png>) | Missing roof side/gable surfaces; inaccessible upper platform |
| P08 | [Screenshot 2026-09-12 at 12.02.53 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.02.53 PM.png>) | Loose railing ends and stone/facade intrude into corridor |
| P09 | [Screenshot 2026-09-12 at 12.03.37 PM.png](</Users/ryko/Desktop/game/town feedback/Screenshot 2026-09-12 at 12.03.37 PM.png>) | Join adjacent roofs as T; center bay windows with margins |
| P10 | [Screenshot 2026-09-12 at 12.08.20 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.08.20 PM.png>) | Missing whole upper wall; awkward isolated narrow tower |
| P11 | [Screenshot 2026-09-12 at 12.08.40 PM.png](</Users/ryko/Desktop/game/town feedback/Screenshot 2026-09-12 at 12.08.40 PM.png>) | Visually gentle village approach cannot be climbed |
| P12 | [Screenshot 2026-09-12 at 12.09.40 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.09.40 PM.png>) | Water divot at cliff corner; floating water shelf |
| P13 | [Screenshot 2026-09-12 at 12.10.53 PM.png](</Users/ryko/Desktop/game/town feedback/Screenshot 2026-09-12 at 12.10.53 PM.png>) | Another cliff/water divot |
| P14 | [Screenshot 2026-09-12 at 12.12.14 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.12.14 PM.png>) | Floating lawn mass; purposeless staircase/upper platform |
| P15 | [Screenshot 2026-09-12 at 12.13.54 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.13.54 PM.png>) | Bare repetitive cliffs; longer connected and stacked terraces, jagged rocks, vegetation/color |
| P16 | [Screenshot 2026-09-12 at 12.14.23 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.14.23 PM.png>) | Random ledge depths; detached cliff dressing |
| P17 | [Screenshot 2026-09-12 at 12.14.39 PM.png](</Users/ryko/Desktop/game/town feedback/Screenshot 2026-09-12 at 12.14.39 PM.png>) | Cliff/terrace context, no explicit annotation |
| P18 | [Screenshot 2026-09-12 at 12.15.37 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.15.37 PM.png>) | Jagged rock reference; jump-catching lip/collision; missing terrace grass |
| P19 | [Screenshot 2026-09-12 at 12.16.28 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.16.28 PM.png>) | Separate water dips; incoherent mountain pool/river flow |
| P20 | [Screenshot 2026-09-12 at 12.17.46 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.17.46 PM.png>) | Random protrusion depths seen from above |
| P21 | [Screenshot 2026-09-12 at 12.18.58 PM.png](</Users/ryko/Desktop/game/town feedback/Screenshot 2026-09-12 at 12.18.58 PM.png>) | Well too small; campfire clearing alternative without square path |
| P22 | [Screenshot 2026-09-12 at 12.19.59 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.19.59 PM.png>) | Purposeless upper stair deck |
| P23 | [Screenshot 2026-09-12 at 12.20.05 PM.png](</Users/ryko/Desktop/game/town feedback/Screenshot 2026-09-12 at 12.20.05 PM.png>) | Patchwork path with awkward grass holes/notches |
| P24 | [Screenshot 2026-09-12 at 12.20.18 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.20.18 PM.png>) | Steep village collar and exposed stone sliver/gap |
| P25 | [Screenshot 2026-09-12 at 12.21.02 PM.png](</Users/ryko/Desktop/game/town feedback/Screenshot 2026-09-12 at 12.21.02 PM.png>) | Folded/raised water pocket on terrace |
| P26 | [Screenshot 2026-09-12 at 12.27.00 PM.png](</Users/ryko/Desktop/game/town feedback/Screenshot 2026-09-12 at 12.27.00 PM.png>) | Ground cutaway void/reverse cliff |
| P27 | [Screenshot 2026-09-12 at 12.28.34 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.28.34 PM.png>) | Mismatched low timber/plaster patch in stone wall |
| P28 | [Screenshot 2026-09-12 at 12.29.32 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-12 at 12.29.32 PM.png>) | Flat village lighting, plain wood/plaster, improve shadows/glow/lanterns |
| P29 | [Screenshot 2026-09-12 at 12.30.00 PM.png](</Users/ryko/Desktop/game/town feedback/Screenshot 2026-09-12 at 12.30.00 PM.png>) | Remove white facade decoration |
| P30 | [Screenshot 2026-09-12 at 12.34.46 PM.png](</Users/ryko/Desktop/game/town feedback/Screenshot 2026-09-12 at 12.34.46 PM.png>) | Ground cutaway void/reverse cliff |
| P31 | [Screenshot 2026-09-12 at 12.35.28 PM.png](</Users/ryko/Desktop/game/town feedback/Screenshot 2026-09-12 at 12.35.28 PM.png>) | Ground cutaway void; adjacent-roof context |
| P32 | [Screenshot 2026-09-13 at 12.23.17 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 12.23.17 PM.png>) | Near-camera canopy needs expanding/full-screen reveal |
| P33 | [Screenshot 2026-09-13 at 12.28.32 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 12.28.32 PM.png>) | Cutaway removes buildings behind character |
| P34 | [Screenshot 2026-09-13 at 12.30.24 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 12.30.24 PM.png>) | Hard distance boundary between animated and smooth water |

| P35 | [Screenshot 2026-09-13 at 5.44.41 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.44.41 PM.png>) | Projecting bay underside/support context; no explicit annotation |
| P36 | [Screenshot 2026-09-13 at 5.45.26 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.45.26 PM.png>) | Barrel embedded in floor; floor lacks plank detail |
| P37 | [Screenshot 2026-09-13 at 5.44.27 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.44.27 PM.png>) | Door-adjacent panels project and mismatch building |
| P38 | [Screenshot 2026-09-13 at 5.44.11 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.44.11 PM.png>) | Connect tall towers; remove white facade decoration and floating dark props |
| P39 | [Screenshot 2026-09-13 at 5.39.43 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.39.43 PM.png>) | Triangular hole at water/ground corner, circled without prose |
| P40 | [Screenshot 2026-09-13 at 5.45.47 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.45.47 PM.png>) | Stair and garden rails terminate without joined endpoints |
| P41 | [Screenshot 2026-09-13 at 5.45.53 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.45.53 PM.png>) | White facade decoration; dormers detached above and embedded inside roofs |
| P42 | [Screenshot 2026-09-13 at 12.27.57 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 12.27.57 PM.png>) | Interior L-shaped timber strips across lawn, circled without prose |
| P43 | [Screenshot 2026-09-13 at 5.36.42 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.36.42 PM.png>) | Horizontal cutaway boundary; capsule from player to camera; water must not fade |
| P44 | [Screenshot 2026-09-13 at 5.35.55 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.35.55 PM.png>) | Buried part of ledge cap revealed through terrain; reveal only exposed cap |
| P45 | [Screenshot 2026-09-13 at 5.37.13 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.37.13 PM.png>) | Irregular tree cutaway, background transparency and ledge artifacts |
| P46 | [Screenshot 2026-09-13 at 5.36.24 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.36.24 PM.png>) | Disappearing cliff edge, circled without prose |
| P47 | [Screenshot 2026-09-13 at 5.35.43 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.35.43 PM.png>) | Bush near player clears while foreground remains opaque; wants continuous tunnel |
| P48 | [Screenshot 2026-09-13 at 5.38.27 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.38.27 PM.png>) | Water poorly placed and dips below terrain shelf |
| P49 | [Screenshot 2026-09-13 at 5.35.09 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.35.09 PM.png>) | Horizontal cutaway boundary and cap seam, circled without prose |
| P50 | [Screenshot 2026-09-13 at 5.38.07 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.38.07 PM.png>) | Near-camera canopy remains opaque; water/cliff cutout artifact |
| P51 | [Screenshot 2026-09-13 at 5.37.49 PM.png](</Users/ryko/Desktop/Screenshot 2026-09-13 at 5.37.49 PM.png>) | Background cliff disappears despite being beyond player |

## Sequential issue ledger and initial alternatives

Initial approaches are hypotheses, to be revised from reproduction and code evidence. Written requests additionally inform 15, 18, 24, 32 and 33.

### 01. Near-camera cutaway coverage

References: P03 P32 P43 P45 P47 P49 P50. Status: Accepted for the reported foliage and boundary failures — [evening review](01-near/evening-review.md), 24 evening pairs plus 12 prior-site controls and focused native regressions.

Initial approach: Use a finite world-radius foreground corridor so its projected area grows as the obstruction approaches the eye. Compare against a widened cone; preserve the player-plane radius.

Acceptance: Increasing screen coverage at decreasing obstacle depth, full viewport near eye where real ground exists; no ground/void regressions.

### 02. Preserve objects behind the player

References: P33 P45 P46 P51. Status: Accepted for the reported background cliff/vegetation failures — [evening review](01-near/evening-review.md). Earlier building ownership evidence remains in [02-background/result.md](02-background/result.md).

Initial approach: Carry foreground object/solid ownership into cutaway eligibility rather than extending the cutaway indiscriminately behind the player.

Acceptance: Background buildings remain complete; selected foreground buildings reveal context without reverse walls.

### 03. Ground/void and interior visibility

References: P01 P06 P26 P30 P31 P44 P46 P49. Status: Accepted for the reported buried cap and cliff boundary failures — [evening review](01-near/evening-review.md). Actual physical heightfield burial, retained grass receivers and a moving-camera control pass; renderer/performance scope remains limited.

Initial approach: Retain actual-ground receiver gating; recheck it with both visibility changes. Do not substitute a color, fake cap, or actor glow.

Acceptance: Only bubble pixels backed by actual ground reveal; soft boundary; no underside, house interior or reverse face.

### 04. Timber/plaster barrier across public walk

References: P04. Status: Accepted — [result and evidence](04-path/result.md). Three matched photo poses, six actual crossings, native closure/support views, 51 focused tests / 511 assertions and 48/48 towns pass. Historical broad-suite failures remain.

Initial approach: Trace public-air ownership into facade emission and reserve the complete traversable opening.

Acceptance: Annotated obstruction gone, native player crosses in both directions.

### 05. Exposed U-shaped stone in path

References: P05. Status: Accepted — [result and evidence](05-stone/result.md). Existing issue-04 repair removes the six panels; three native photo pairs, 125 clear capsule stances and ten actual traversals pass.

Initial approach: Resolve masonry course/floor interface from actual public floor instead of overlapping independent surfaces.

Acceptance: No protruding stone lip; full swept walking width clear.

### 06. Loose rails and facade intrusion

References: P08. Status: Accepted — [result and evidence](06-rails/result.md). Three photo pairs, native detail/wide controls, ten traversals, 12 tests / 368 assertions and the 48-town / 95-assertion gate pass.

Initial approach: Make guards terminate at actual supported endpoints and consume the final facade envelope.

Acceptance: No detached bars or masonry in corridor; physical crossing clear.

### 07. Unreachable public platform

References: P07. Status: Accepted — ordinary full-width perpendicular flights share a landing; 22/22 actual traversals, 48/48 layouts and 95/95 gate. The half-width connector remains rejected. See [review record](07-platform/result.md).

Initial approach: Trace floor and transition graph to the photographed landing and construct its complete approach.

Acceptance: Actual player reaches platform from surrounding public route.

### 08. Missing roof side/gable

References: P07. Status: Accepted — [review and evidence](08-roofs/result.md). Opposite native half-roof hands close both street gables, with matched views and the 48-town gate passing; historical broad-suite failures remain documented.

Initial approach: Inspect actual native triangles, roof partition/end ownership and clipping. Preserve complete side stock.

Acceptance: Both circled roof ends closed at original and oblique angles.

### 09. Missing upper wall

References: P10. Status: Accepted for the half-backed upper bay — [review](09-upper-wall/result.md). Complete rear-wall contacts and exact full-width sockets replace point-only attachment; six matched pairs, ten focused tests / 475 assertions, unchanged local clearance and the full 48-town matrix pass. Separate live-panel discrepancies are tracked under 45.

Initial approach: Trace wall ownership under the selected roof and neighboring room instead of adding an overlay panel.

Acceptance: Entire exterior envelope closed with native material.

### 10. Mismatched low wall patch

References: P27. Status: Accepted — [review and evidence](10-low-wall/result.md). Incomplete facade courses use fitted masonry; six matched pairs, native bounds, unchanged local clearance and the 48-town gate pass.

Initial approach: Unify facade material/course choice through the full exposed surface.

Acceptance: No stray timber/plaster rectangle in masonry; native seams remain sound.

### 11. Joined T-shaped roof composition

References: P09 P31. Status: Accepted for the reported compact T junction and supported finite family — [result](11-roof-joins/result.md). P31 retains its complete two-sided dormered roof as a negative context.

Initial approach: Use connected roof domains with an owned valley and complete gable alternatives.

Acceptance: Requested joined silhouette and watertight native junction without roof overlap.

### 12. Centered bay windows

References: P09. Status: Accepted — [review](12-bay-spacing/result.md). Complete facade-panel centering and plain native backing retain both photographed windows; nine matched pairs, four focused tests / 215 assertions, identical local clearance, 48/48 towns and 95/95 composition pass.

Initial approach: Reserve bays relative to complete facade/window centers with measured side margins.

Acceptance: Bays replace centered windows rather than straddling panel edges.

### 13. Floating lawn/stone/timber platform

References: P14. Status: Accepted — [review](13-floating-lawn/result.md). Actual jamb ownership removes the full unsupported bed; twelve matched pairs, six tests / 92 assertions, identical 76-position / 108-crossing clearance, 48/48 towns and 95/95 composition pass.

Initial approach: Require complete structural bearings before reserving a raised garden.

Acceptance: No suspended unsupported bed; public circulation preserved.

### 14. Purposeless upper stair decks

References: P14 P22. Status: Accepted — [review](14-deck-purpose/result.md). Actual destinations trim unused terminal flights and lookouts; 24 matched pairs, eight tests / 99 assertions, 48/48 towns and 95/95 composition pass. Three identical historical carver failures remain.

Initial approach: Require an actual destination for elevation changes: room entrance, connected route or supported useful terrace.

Acceptance: Small towns no longer center on an empty isolated upper landing.

### 15. Isolated modular towers/houses

References: P10 P38. Status: Open — [connection investigation](15-tower-massing/investigation.md). Lowering the towers alone was rejected; actual connections remain pending.

Initial approach: Use complete native prefab recipes for standalone buildings; retain modular composition for connected warrens.

Acceptance: Photographed isolated tower becomes a coherent supported building.

### 16. White facade decoration

References: P29 P38 P41. Status: Accepted — [result and evidence](16-facade-props/result.md). General removal of white ivy and mug signs; 21 native/game/wide pairs, 28 focused tests / 49,707 assertions, unchanged physical clearance and 48/48 towns.

Initial approach: Remove the requested decoration family from production selection.

Acceptance: No white facade foliage in source and nearby views.

### 17. Village collar gap and steep slope

References: P24. Status: Open — [bank investigation](17-village-grade/bank-investigation.md). Camera rays expose a residual cliff between independently graded owners. A continuous shoulder experiment passed its seam test but was rejected for a new fold and remaining artifacts; production was restored.

Initial approach: Unify village grade, rendered ground and exposed cliff boundary using the final shared height field.

Acceptance: No stone sliver/gap or abrupt artificial trench beside house.

### 18. Unclimbable gentle slope

References: P11. Status: Accepted — shared distance-based collar removes the artificial steep ridge; all six actual-player ascent/descent runs pass. [Review](17-village-grade/approach-result.md): six inspected visual pairs, 20 tests / 19,240 assertions, 48/48 towns and 95/95 composition.

Initial approach: Compare physical triangles, ground normals and actual controller ascent before changing slope limits.

Acceptance: Player runs uphill/downhill on the photographed gentle approach.

### 19. Patchwork paths

References: P23. Status: Accepted — unused enclosed parcels join the public street plan; level exit paint requires an actual road. Six matched native/game pairs, 96/144 clear local positions/crossings, 48/48 towns and 95/95 composition. Two older road-coordinate pins remain unchanged. [Review](19-streets/result.md).

Initial approach: Resolve a shared connected street footprint and native edge ownership around occupied plots.

Acceptance: Coherent path shape without accidental grass holes or leftover strips.

### 20. Well scale

References: P21. Status: Accepted for the inspected scale/clearing change; see [result](20-civic/result.md).

Initial approach: Fit a larger native well to a measured civic reservation.

Acceptance: Well reads at appropriate village scale while routes stay clear.

### 21. Campfire clearing variant

References: P21. Status: Accepted for the inspected scale/clearing change; see [result](20-civic/result.md).

Initial approach: Reserve a native fire/seating clearing as a civic alternative without an imposed square path.

Acceptance: Deterministic reviewed variation with supported furnishings and clear circulation.

### 22. Floating water sheet edges

References: P01 P02 P12. Status: Open.

Initial approach: Trace wet-domain support, mesh extents and domain boundary ownership.

Acceptance: No exposed straight water-sheet cutoff across dry/empty space at reported sites.

### 23. Water corner divots

References: P12 P13 P39. Status: Partial — P12 corner interpolation is repaired and verified in [corner result](22-water/corner-result.md). P39 wave exposure is repaired and verified in [turf result](22-water/turf-result.md). P13 remains open.

Initial approach: Reconcile continuous hydraulic surface through shore/corner interpolation using actual terrain constraints.

Acceptance: No independent corner sag; shared edges agree.

### 24. Incoherent mountain water and folded pockets

References: P19 P25 P48. Status: Open.

Initial approach: Define connected contained pools and actual downhill outlets; remove unsupported independent wall attachments.

Acceptance: Continuous smooth water/pool-to-river flow, no folded or raised pockets.

### 25. Water glitches while moving

References: V01. Status: Open.

Initial approach: Inspect paired video frames then trace streaming, simulation ownership and shader state across the recorded movement.

Acceptance: Replay movement and alternate times without popping or corrupted water.

### 26. Water animation distance seam

References: P34. Status: Open.

Initial approach: Blend simulation detail continuously into a shared far-water field, preserving phase and surface normal continuity.

Acceptance: No hard band at fixed distance during camera/player movement.

### 27. Detached/uneven cliff ledges

References: P16 P20. Status: Accepted — [native seating review](24-cliff-layout/result.md). Seventeen reproduced native contact failures are removed; 216 placements in four orientations pass five-height probes. Fifteen native pairs, nine fresh game views and three retained jumps pass, with 15 tests / 351 assertions.

Initial approach: Derive embed depth and cap alignment from native cliff contact rather than arbitrary offsets.

Acceptance: All ledges touch their intended cliff and form consistent recess/projection.

### 28. Cliff terrace hierarchy

References: P15 P17 P18. Status: Partial — [native hierarchy review](25-cliff-hierarchy/result.md). Wider 12/8/4 m supported stacks pass 18 tests / 3,927 assertions, 24 native and six fresh game jump approaches. Fifteen native pairs and nine fresh game views were inspected. Wide repetition and continuous terrace paths remain open.

September 15 owner feedback rejects the sparse pyramid-like stacks as the visual direction. The physical checks above do not constitute art acceptance. The [asset survey and revised proposal](27-mountain-art-direction/proposal.md) calls for long irregular shelves, attached rock ribs and greenery spanning the cliff face.

Initial approach: Build longer tileable terraces and subordinate stacked shelves using complete native proportions and bearings.

Acceptance: Broad cliff composition has connected multi-scale relief, not isolated tiny dots.

### 29. Cliff rocks and vegetation

References: P15 P18. Status: Open.

September 15: 36 existing source models reviewed from two angles each, including green MegaKit vines, UltimateNature moss rocks/plants, LPFV tall rocks and Crafting roots. See the [shortlist](27-mountain-art-direction/shortlist.jpg) and [composition proposal](27-mountain-art-direction/proposal.md). The sparse ambient-rock candidate does not close this issue.

Initial approach: Review jagged mountain-rock assets at appropriate scales and rooted vegetation/color accents.

Acceptance: Cliff faces visually varied at wide and close views, with no floating dressing.

### 30. Cliff/terrace collision and jump lip

References: P18. Status: Accepted — [result](23-terraces/collision-result.md). Sixteen native approaches and three frozen plus three fresh game jumps pass without underside contacts; 31 related tests / 649 assertions pass. Actual flat tops and rounded outlines are retained.

Initial approach: Compare native cliff and terrace collision; use the same close-fitting physical treatment.

Acceptance: Real jumps from both sides clear intended lip; render/physical boundaries agree.

### 31. Grass on terraces

References: P18. Status: Accepted for exposed native cap grass — [result](23-terraces/grass-result.md). Five matched native pairs, three fresh game views, 29 tests / 594 assertions, and 140 actual worker roots across 15 local tiles. Ledge layout and collision remain separate issues.

Initial approach: Feed supported terrace top surfaces into the ordinary grass placement/sampling pipeline.

Acceptance: Terrace caps receive matching grass with correct roots and edge containment.

### 32. Collision audit for new objects

References: P18. Status: Accepted for the nine native terrace columns and their rock dressing — [inventory and measured cost](23-terraces/collision-result.md). Closed ground profiles use 64–188 triangles; native rock collision stays unchanged. Isolated character timings improve, with no whole-game performance claim.

Initial approach: Inventory shape provenance; compare authored triangles and measured convex compositions against existing precedents and performance.

Acceptance: Document actual shape choices, physical fits and measured cost rather than blanket assumptions.

### 33. Landscape relief

References: P15 P17 P19. Status: Open.

Initial approach: Review continuous geological profiles for hills, ridges, hollows, basins, canyons and tall narrow mountains.

Acceptance: Varied supported landforms and shorter uninterrupted vistas without broken water/routes.

### 34. Village lighting and shadows

References: P28. Status: Open.

Initial approach: Tune direct/ambient contrast, contact shadows, restrained bloom and actual lantern illumination with matched controls.

Acceptance: More readable depth and warm atmosphere without haze washing out material detail.

### 35. Wood and plaster surface detail

References: P28. Status: Open.

Initial approach: Add restrained native-compatible texture/roughness detail with consistent scale and UV ownership.

Acceptance: Wood/plaster read as materials at close range while retaining the stylized palette.

### 36. Restore paths between towns

References: Owner's September 13 follow-up: “paths between towns are gone now, can we add them back?” No additional reference image supplied. Status: Functionally accepted for the reviewed links — [result](36-world-paths/result.md). Timing remains open: the unchanged 60 s path-context bound fails on original and candidate.

Initial approach: Trace canonical inter-town road planning through terrain sampling, rendered path surfaces and settlement gate handoffs. Determine whether links were removed from the plan, omitted during streaming, or hidden by terrain/grass. Restore continuous intended connections using the existing road system and actual town entrances.

Acceptance: Connected town pairs have visible, continuous paths through the landscape; paths meet usable town entrances, retain terrain/grass treatment across chunk boundaries, and pass real traversal in both directions. Capture matched views along the route and at both gate handoffs, plus pixel differences and walking evidence. Preserve the sequential review order.

Issues 01–12 and 43 are accepted within their documented scopes. Inter-town paths (36) are restored for the reviewed routes, with their timing bound still open. Each remaining issue requires its own falsification and review.

### 37. Barrel embedded in public floor

References: P36. Status: Accepted for the photographed defect and general surface-clearance rule — [result](37-barrel/result.md). Six matched pairs, native clearance and the 48-town matrix pass.

Initial approach: Resolve furnishing support height and full occupied volume against the final public floor, including the space below it.

Acceptance: Barrel rests on its intended support and does not penetrate the route; actual passage remains clear.

### 38. Missing plank detail on public floor

References: P36. Status: Accepted. Shared production/review plank material and metric ramp/stair UVs. Six matched native/live pairs, eight GPU orientation controls, 19 tests / 187 assertions and unchanged 48-town clearance. See [result](38-floor/result.md).

Initial approach: Trace floor ownership and native board emission; inspect whether an overlapping support slab obscures the boards.

Acceptance: Continuous native plank appearance at original and oblique angles without coplanar flicker.

### 39. Protruding doorway panels

References: P37. Status: Accepted — [native doorway fitting and review](39-door-panels/result.md). Horizontal full-depth native returns have correctly handed front jambs; 11 judged native/game/control pairs, actual local collision, the 48-town matrix and 95/95 composition gate pass. Two historical assertions reproduce with original assets.

Initial approach: Resolve measured native doorway returns and adjacent facade planes as one owned envelope.

Acceptance: Panels align with the surrounding building and the complete doorway stays closed.

### 40. Unjoined stair and garden rail ends

References: P40. Status: Accepted for the reported stair-side defect — [result](40-rail-ends/result.md). Level garden guard, six actual stair/landing traversals, ten judged native/game pairs and the 48-town matrix pass. The roof-side guard is present and occluded by its gable.

Initial approach: Join ordinary guard segments to measured posts or supported wall endpoints, including stair-to-garden turns.

Acceptance: Both annotated rail junctions close without loose ends or blocked walking width.

### 41. Dormers detached from or buried in roofs

References: P41. Status: Accepted — [native fitting and visual review](41-dormers/result.md). Both photographed shed junctions close; four native tests / 12,018 assertions, matched game/native controls and the 48-town gate pass. The related historical circulation assertion remains unchanged.

Initial approach: Fit native dormer bearing and roof opening to the actual selected roof profile.

Acceptance: Dormers meet the roof, keep visible windows and close their junction at both reported placements and rotated controls.

### 42. Interior timber strips across lawn

References: P42. Status: Accepted — continuous same-height lawns share their exterior frame; both interior strips are gone. [Review](42-lawn-strips/result.md): six matched pairs, 15 tests / 4,635 assertions, identical 356-stance / 502-crossing clearance, 48/48 towns and the 95-assertion gate pass.

Initial approach: Trace internal versus exterior garden frame ownership and shared turf surfaces.

Acceptance: Remove unintended interior border strips while retaining complete exterior support and guards.

### 43. Exclude water from obstruction cutaway

References: P43 P50. Status: Accepted — native water remains outside camera adaptation; three-position material/mesh regression and the evening paired views pass. See [review](01-near/evening-review.md). Separate water geometry/animation issues remain open.

Initial approach: Trace water material participation independently of ordinary optical transparency and shoreline rendering.

Acceptance: Camera cutaway leaves the water surface intact during movement, with no rectangular or capsule-shaped holes.

### 44. Projecting bay underside review

References: P35. Status: Reviewed — the original roofed projection was already relocated/omitted by issues 09/16. [Underside review](44-bay-underside/result.md): six native/game pairs and 249 actual native contact columns verify the inspected geometry; no additional production change.

Initial approach: Inspect the unannotated bay/support close-up against native geometry and its structural contacts; do not assume a specific defect from the image alone.

Acceptance: Document observed support, material and contact defects, if any, and verify any repair at the supplied pose.
### 45. Live-world panels absent from the native assembly comparison

References: P10 reproduction, discovered during issue 09. Status: Resolved as a review-harness readiness error — [result](45-live-panels/result.md). The harness now drains feature visuals before capture; eight tests / 40 assertions and all 345 current wall/window pieces pass in a fresh run and frozen replay. No production renderer change.

Evidence: Several window/front-wall panels exist in the direct native payload but are absent in both the saved-world replay and live before/after captures. The upper bay fix does not repair them; the completed investigation identifies an incomplete capture, not missing production emission.

Initial approach: Compare the emitted entries, committed instance transforms and materialized geometry for the same owners before attributing the discrepancy to visibility or rendering.

Acceptance: Complete native exterior panels survive the live pipeline and frozen replay at matching cameras, with no duplicate surfaces or route changes.
