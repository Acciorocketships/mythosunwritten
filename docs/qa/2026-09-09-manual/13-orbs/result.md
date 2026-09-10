# Spirit orb size and motion — accepted

Spirit orbs now render a visible, larger soft glow and drift slowly through a wider horizontal space. Their 3.2m billboard contains a soft halo and bright core; the real light remains attached to the same moving parent. Horizontal travel spans 3m, with a gentle 0.8m vertical bob and a slower pulse. No additional lights were introduced.

Visual iteration found a separate shader defect: the unshaded additive sprite was invisible while a nearby particle made the location appear luminous. Outputting glow radiance through ALBEDO repairs the sprite. Diagnostic material/shader images distinguish that repair from the size change.

All 12 paired frames (three cameras at 0, 5, 10 and 20 seconds) were inspected. Both close views show a soft orb moving coherently; the distant scene is preserved. A rendered-pixel regression finds 572–1,043 new bright core pixels at the four projected moving centers, with 0.22–0.72px centroid error. It verifies the rendered sprite, beyond merely checking its node size. All 17 related tests pass with 1,190 assertions (0.885s, exit 0), including slow bounded motion and sprite/light attachment.

This is a replay of actual generated world geometry from issue 2 with the 11 existing orb adapters rebuilt using production code. The frozen positions are shared comparison anchors. It isolates orb rendering and does not establish that the older fixture's water/buildings are current. Both replays exit 0; three known fixture AnimationPlayer path errors and resource/RID teardown warnings remain disclosed in the iteration notes.

[Before/after at 0s](diff/second_orb_00_comparison.png) · [At 5s](diff/second_orb_05_comparison.png) · [At 10s](diff/second_orb_10_comparison.png) · [At 20s](diff/second_orb_20_comparison.png) · [Pixel verification](pixel-verification.json) · [Tests](tests.txt)
