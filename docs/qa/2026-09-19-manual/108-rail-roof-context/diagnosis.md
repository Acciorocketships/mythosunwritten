# P15 missing stair guards beside a prefab roof

Seed 2697992464, original player (-1999.3,33.6,1765.5), crosshair (-2002.6,34.1,1763.6). Saved ReviewCam poses from pass 05 identify `public-transition/volume.transition.11.mesh`. Its local flight runs from (3.75,9,8.25) to (3.75,7.5,11.25), with the reported guard at x=5.25.

Both rails originally stop at z=9.75, halfway down the flight. Coarse occupied cells (4,5,7) and (4,6,7) remove the rest of the rails and their posts. They belong to `spatial.fabric.spatial.feature.landmark.01.component.00`, recipe `anchor.prefab.16`, rather than retained earth. The whole prefab is not tagged as a roof, so the existing separate-roof exclusion does not apply.

The measured house begins at x=6.327571, more than a metre away from the guard. All native parts avoid the tested rail strip. The rounded-up construction reservation therefore incorrectly substitutes empty air for a physical fall barrier.

The fix intersects prefab-owned guard-cut cells with their transformed native placement bounds. Retained earth keeps its complete cell, and construction occupancy remains unchanged. The photographed payload changes only mesh 93, the reported stair. All native batches, generated collision boxes and the other 100 generated surfaces remain identical.

This uses measured per-placement bounds, not an exact triangle containment algorithm. It does not resolve arbitrary empty interiors inside a prefab's own bounds. Flat guard classification retains its existing occupancy rule. P04's upper rail/house joint remains separately open.
