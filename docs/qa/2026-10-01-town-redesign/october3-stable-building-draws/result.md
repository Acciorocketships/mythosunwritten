# Stable building draws — October 3

Retained: footprint-budget and storey-budget draws are keyed by the house seed
column, floor and entrance, not its index among admitted seeds. Removing an
earlier seed no longer rerolls surviving houses. Actual footprints may still
change through growth competition and support/clearance constraints. Diagnostic
house IDs and downstream styles remain index-derived; this is not a claim of
complete town-wide edit stability.

This changes existing seeded towns once. It is groundwork for coordinated
crossings and massing, not an enclosure gain by itself. No seed exceptions,
retries or selected-town configurations were added.

## Controlled comparison

Eight towns were built with stable draws, then rebuilt with the earlier deferred
natural-ground bridge candidate (including reserved-green exclusion). With
stable draws, the candidate's earlier 31/large house-coverage gain disappears:
12 -> 12 quarters. 7/standard still loses house coverage 36 -> 32; the other six
are unchanged. Candidate carver changes are fully reverted. Current carver
matches its pre-investigation copy byte-for-byte.

A measurement defect was also corrected: the probe formerly counted `houses`
only, omitting separately emitted enclosed skywalk masses. It now includes
`kit.skywalk.*` masses with actual storeys, while excluding open decks and
retaining supports. The historical 280 and later house-only figures must not
be compared directly with the corrected total below.

| Town | Public macro cells | Quarters below inhabited rooms, including enclosed skywalks |
|---|---:|---:|
| 7/standard | 45 | 36 |
| 13/large | 69 | 36 |
| 31/large | 39 | 18 |
| 43/grand | 98 | 68 |
| 58/large | 124 | 14 |
| 101/large | 61 | 24 |
| 103/grand | 80 | 40 |
| 211/grand | 99 | 92 |
| Total | 615 | 328 |

All eight build; floating masses and roof/public-air intrusions are zero.
`finished-room-audit.json` is the corrected current-state evidence. Candidate
and initial house-only measurements remain separate artifacts. This is not a
before/after coverage-improvement claim.

## Verification and visual judgment

- 7 targeted tests / 158 assertions pass: draw locality, platform foundation,
  occupied climbing cover, native attic closure, odd private crown, dormers,
  skywalk landing/guard continuity.
- The odd-crown regression now finds the five-cell 2x4 L by actual transformed
  roof geometry rather than the incidental `maze_back.13` room number. Two odd
  crowns still build. The first is now room 14; the geometry remains protected.
- Native 7/standard and 43/grand: both overviews and all six street views reviewed.
  Covered boardwalk and masonry passages remain intact. Coordinated wood/blue/
  green palettes and small corner towers remain visible. Tall central faces
  still look too plain, and open stretches remain; these are not art acceptance.
- Actual-player 101/large entrance-to-gate climb passes both directions.
- Real-terrain production test passes 1/1, 125 assertions; 6196 ms against the
  8000 ms limit, with no competing heavy job (`production.log`).

## Outstanding

Extra ground crossings remain disabled pending coupled endpoint/upper-room
planning. Stable budget draws remove one source of unrelated variation but do
not solve topology or mutable downstream style identity. Taller compounds need
more meaningful setbacks/outcroppings and corner planning. Broad enclosure,
Gothic material/composition, wider holdout/world/full-suite acceptance remain
open. Do not declare the redesign complete from these targeted checks.
