# Crevice canopy spacing

Added-rock foliage now competes using its actual transformed native canopy bounds. A stable local priority over the canonical neighboring formations removes heavy overlaps while permitting light leaf interleaving. Surviving plants retain their original crevice contacts, size, pose and grass tint. Owned plants receive the existing water admission after halo arbitration; halo candidates conservatively reserve space without querying outside the prepared hydraulic domain. Native-wall planting remains a separate unchanged pass.

The photographed 31 formation anchors produced 186 plants and 24 pairs with more than 15% overlap of the smaller canopy volume. The revised result has 165 plants and zero such pairs. [The saved original fails](photo-red.log); [six initial tests / 37 assertions](first-tests.log) and [six final tests / 14 assertions](halo-tests.log) pass: **11 distinct tests / 50 assertions**, including the added [31/31 formation planting-preservation assertion](coverage-test.log), covering canopy overlap, reversed input, split ownership, independent real chunk halos, actual crevice contact and worker grass ownership.

Seventeen native game-context views were captured using the preceding triangulation repair as the exact visual baseline. P12 front and +8 degrees separate crowded crevice fans; P20 oblique retains readable plants across the face; P17 −8 degrees keeps the lower seam planting. P05 loses a central crowded group and is somewhat sparser there. This is accepted only as a canopy-overlap repair, not a density redesign or overall cliff-art approval. Uneven coverage and broad soft rock faces remain.

| View | Before | After |
|---|---|---|
| P12 front | [Before](../01-cliff-lighting/context/P12_front.png) | [After](candidate/P12_front.png) |
| P12 +8° | [Before](../01-cliff-lighting/context/P12_reported_8.png) | [After](candidate/P12_reported_8.png) |
| P20 oblique | [Before](../01-cliff-lighting/context/P20_oblique.png) | [After](candidate/P20_oblique.png) |
| P17 −8° | [Before](../01-cliff-lighting/context/P17_reported_-8.png) | [After](candidate/P17_reported_-8.png) |
| P05 | [Before](../01-cliff-lighting/context/P05_vines.png) | [After](candidate/P05_vines.png) |

The replay rebuilds current rocks/plants at frozen anchors; terrain, grass and collision are retained. No fresh traversal, startup or global performance claim. Headless saved-MultiMesh extraction returned zero transforms and was discarded; the native extraction retained all 31 anchors. The earlier generic test already passed and is not red evidence. The corrected photo-red log is the credited regression.

Reproduce: `tests/harness/september16_cliff_transition_context.tscn -- --output=res://OUTPUT`. The exact starting dressing is saved in `tests/fixtures/september17/cliff-plants/before.gd` and native anchors in `anchors.bin` beside it.
