# Repack partially blocked crowns

103's remaining thin2x1 crown was not best solved by a new end-backed shed. Its exposed crown is L-shaped: greedy packing creates one blocked4x1 rectangle and a clear2x1 strip. Repartitioning to a clear2x2 wing plus the blocked2x1 remainder was refused because the remainder cannot take a roof, although that same area already fell back to a deck. The neighbouring actual room atband7 occupies the western cells; it does not require the eastern clear half to stay thin.

The repacker now remembers cells of initially unroofable rectangles. A candidate wing must pass the existing roof clearance proof; a failed remainder may survive only on those already-unroofable cells. Crown coverage stays exact, with no new room footprint or stretched asset. Later assembly handles the remaining flat area by the existing rules.

Red-first fixture fails on the missing full-width wing, then passes with exact nonoverlapping cell coverage. Final focused roof suites13tests/122assertions pass. Four-town204-roof survey103grand/127large/83grand/8grand: zero tiny roofs, exposed open ends, gable holes, unsupported roofs and eaves cut; previously103 retained one thin crown. Matched native front and closer side inspected: complete gable, no detached shed trim from the rejected experiment. The larger surrounding building/deck composition is unchanged in scope and not certified as overall art completion.

Actual-player skywalk/source-bridge routes: 6/6 pass. git diff --check passes. Exact incremental patch, logs and images archived here. Bounded repacking accepted; full redesign and broad performance/art acceptance remain open. All jobs terminal.
