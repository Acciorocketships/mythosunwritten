# Streaming return-handoff visual judgment

Six same-pose pairs use the reconstructed photo-11 camera, left/right eight-degree views, two jitter views and the collision-resolved gameplay camera. Camera JSONs have identical poses. Original 0.1 m overlay rounding prevents recovery of the full original camera.

I inspected the full exact before/after and all six three-column comparisons and heat maps (`pixel-diff/all-views.jpg`). The before release has an empty distant tree line and missing adjacent terrain ownership; the after release supplies the surrounding forest, ground and its shadows. The nearby foreground remains continuous in both images. **This particular return sequence does not reproduce the large foreground void in the original screenshot**; it cannot be used to claim a pixel-for-pixel removal of that original void. The instrumented physical baseline separately reproduces the nearby chunk-edge freeze, and the long-distance traversal remains the decisive streaming check.

The before game releases movement with three built chunks, after with all nine support chunks. Graphical return readiness is 120.651 s before and 24.891 s after; startup is 222.340 s and 169.326 s. These are separate from movement freezing, and this fixture uses the same equivalent optimized water computation in both runs. The original headless baseline remains the timing reference for the full telemetry comparison.

Across the six images, mean absolute RGB change is 6.02–7.86/255 and 5.07–7.92% of pixels exceed 20 in a channel. Changes cluster on the previously empty tree line and its ground shadows. Shader time and render ordering contribute small foreground differences, so the metric alone is not acceptance evidence. Grass latency is still a separate pending issue.
