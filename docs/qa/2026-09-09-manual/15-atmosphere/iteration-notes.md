# Atmosphere review iterations

The latest owner request asks for darker average lighting, brighter exceptions and twilight biomes. This supersedes the earlier fixed-global-lighting policy. Considered options: keep the sky fixed and tint only materials (cannot deliver twilight), hard biome switches (visible pops), or blend the real continuous biome weights through a three-second exponential response. Selected the last, retaining a fixed sun direction and spatial ground-following mist.

First controlled renders compare seven pure lighting profiles over identical generated geometry. Sunwash and Opal are brighter, Lanternwood subdued, Moonfen blue twilight, Cherryveil pink, Amber golden, Jade green. The player, roads and house silhouettes remain readable. The equal-profile mean sun energy is 0.927 versus 1.2 before; mean ambient energy 0.513 versus 0.65. These parameter averages do not assert a geographic occupancy-weighted world average.

Native lantern close-ups rejected the first lighting-only candidate: the two LPFV families lit the ground but their opaque gold panes remained dark. Source mesh/atlas inspection identifies the private glass swatch at U=(0.34375,0.375), V=(0,0.03125); only that swatch now emits. Measured pane centres also replace approximate point-light anchors. Metal, chains and timber retain ordinary shading. Both native lamp variants will be rendered again before acceptance.

The first all-related test run failed because the light-count test matched node names; Godot renames duplicate siblings. Counting OmniLight3D by type corrected the test and found all 12 expected lights. An attempted mist density in Opal Highlands violated its established clear-air contract and was reverted before the first visual review.

Controlled replay uses the existing frozen real-world fixture. It isolates lighting; its older geometry does not revalidate current water or construction. Production-streamed Moonfen is checked separately. Original pure-profile screenshots have no user camera to reconstruct; both replay cameras are identical across before/after.

The final related suite after pane emission and measured anchors passes 40 tests / 1,379 assertions in 11.214 s (eight scripts, exit 0). A prior command misspelled three existing test paths and ran only 18 tests with three discovery errors; that incomplete run is not acceptance evidence. The corrected complete log is `tests.txt`.
