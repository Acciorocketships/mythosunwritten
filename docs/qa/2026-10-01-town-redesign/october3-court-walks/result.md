# Finished courtyard entrance traversal

11/compact originally reserved plaza.00 beside(0,4,0). Destination pruning
removes that redundant approach while retaining connected landing(-1,4,1).
The actual final source graph proves the latter is reached from the entrance.
The player harness now selects a surviving adjacent graph landing, then visits
the court's finished walking cells. Route finding reads authoritative walk_edges
rather than reconstructing edges from potentially pruned lane-cell lists.

Two initial harness trials still called the old address at the court call site;
they produced no routes and failed. They are not production failures or passes.
After correcting the court-specific call, native collision player traversal
passes forward and reverse (2/2), climbs to the12m-high court and returns to the
entrance. Exact traces and floor hits retained. No production path was added.

The24m-high nested court13/grand also passes forward and reverse (2/2).
Total4/4 actual-player traversals across the two elevations. All jobs finished.
Native current views inspected:11_compact_court_plaza.00_0 and
13_grand_court_plaza.00_1/_3. Both retain planted seating space and a continuous
walking border, with surrounding native roof/wall enclosure. Flat preview turf
does not demonstrate production terrain grass; production grass has separate
world evidence. No claim of universal art acceptance or quiet performance.
