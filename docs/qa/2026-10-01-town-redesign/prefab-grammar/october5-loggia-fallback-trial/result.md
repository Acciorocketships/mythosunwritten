# Loggia fallback trial — rejected, production restored

The candidate searched alternate two- and three-bay recessed galleries when the sampled facade position was blocked, and protected measured bracket bearings. It did not improve the remaining apartment-like shaft sufficiently to accept.

## Evidence

- New doorway fallback fixture failed before the change and passed with it. The bearing negative fixture passed (2 assertions).
- Existing `test_recesses_face_street_air_without_occupying_it` fails identically before and after: one loggia versus expected two, 107/108 assertions. The successful baseline run excluded candidate-only tests because their changed method signature otherwise prevents parsing; the initial parse-error run was not evidence.
- Six towns retained all 244 previously measured covered quarters; floating-mass and public-air intrusion audits stayed zero. No new actual-player traversal or holdout validation was performed for this rejected trial.
- Seed 63/grand, house.010: top floor lost three room cells, but the longest repeated wall-slot run remained five storeys. House.015 was unchanged. Slot diagnostics are potential facades, not a visibility oracle (party walls may be included).
- Matched native context renders of house.010 from both sides show altered crown gables but the same tall shaft and mushroom-like upper mass. The changed roof is not a convincing improvement toward the owner's reference. Merely finding another recess does not solve the underlying arrangement.

## Disposition

Restored `KitLoggias.gd`, `KitVillageBuildings.gd` and the loggia test file byte-for-byte to their pre-trial contents. Candidate code and tests are retained only in `rejected-candidate.patch`. All earlier accepted bay-material, parallel-roof, corbelled-turret, covered-route, court-address, planting and broad-court-deck changes remain. The diagnostic `tall_frontage_probe.gd` remains available.

Next investigation must address room/route composition jointly: these upper floors carry doors and balcony contacts, so generic height caps or arbitrary room removal lose access or support. The broad town redesign remains open. This trial is not an accepted visual improvement.
