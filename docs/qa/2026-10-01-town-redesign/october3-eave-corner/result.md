

## Native verge repair

The clipped Pure tight eave was a projecting end cap crossing a perpendicular
landing. `KitRoofEaveFits` now also checks already-tight profiles and tries the
existing flush native verge assembly at one end, the other, or both, accepting
only a complete eave that clears the public volume. This repositions whole
end caps with the matching ridge/barge finish; it does not remove a cap, alter
the landing, or relax headroom. Clear roofs retain their existing profiles.

The new geometric regression failed before the edit (10/12 assertions), then
the eave and September27 roof suites passed together:9/9,262 assertions.
The previously failing real compact town now passes the closed-roof/eave audit.
Native isolated corner and underside views were inspected in `fixed-isolated/`: the
retracted corner cap is complete. Isolation intentionally omits adjoining
buildings and public geometry, so this is local cap evidence, not whole-town
visual acceptance. The temporary harness and exact source hashes are retained.

This is the fifth production edit during full regression session24812; earlier
full-suite output remains tied to its original run. The unrelated world3 market
canopy/bridge-support conflict remains unresolved.

Fresh quiet production-site solve after the verge edit:6246ms under the unchanged8000ms ceiling;149 assertions pass. Total test51.144s includes world/site setup. This is one production-site cost check, not a town-distribution or streaming-memory certification. Session20743 completed.
