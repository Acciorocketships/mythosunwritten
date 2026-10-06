# Central greens belong to the routing domain

The 17/large holdout exposed an unnecessary outer approach. Its central lawn
was absent from the town height/routing domain. Only thin spanning-tree
shoulders connected the lobes, so even the shortest legal path had to trace
the outside. Trying nearest-district-first ordering did not solve it and was
reverted completely; `WarrenMazeCarver` is unchanged by this pass.

`WarrenTownField` now fills missing ground inside the existing lobe-centre
convex hull for central-green towns. These cells enter `height_domain`, never
`solid`; the normal reserved-ground rule keeps them unbuildable. An
`open.central_ground` reservation carries them to planting and dressing. The
existing core-selection rule retains a planting island, and natural ground
bands remain the sampled datum. No town or coordinate special case.

For 17/large, district-access cells fall **64 -> 48** and the longest branch
falls **31 -> 20**. Native before/after overviews show a direct central route
instead of the far ring; short bends still avoid actual construction and the
planting island. This does not claim that every town path is globally optimal.

Validation:
- 60 selected-profile source towns: **60 valid**, 11 central greens, no unbuilt
  districts, **104/104** reserved cottages built.
- Before/after field comparison: **49 ordinary towns identical**; all 11 central
  cases preserve solid building mass, lobes, house sites and platform sampling.
- Access + current construction + datum tests: **10 unique tests, 5,945
  assertions** across the saved focused runs. The complete 17/large and
  24/large towns have zero floating masses, gable holes, open exposed ends,
  unsupported roofs and finished public-air intrusions.
- Real player-controller traversal: **10/10**, all five 17/large district
  approaches in both directions. This is exterior traversal, not interiors.
- Native 17/large and 24/large overhead/green views rendered and inspected.
  Town17 intentionally rolls woodland=0 and remains treeless. Town24 keeps
  44 trees including17 natural-pocket trees. No forced trees were added.

The central route is an improvement, not final art acceptance of the whole
redesign. Large plain facade panels, the unresolved positive terminal-roof
fixture, and broad final regression/performance classification remain open.
The holdout central lawn can still benefit from more purposeful dressing.
