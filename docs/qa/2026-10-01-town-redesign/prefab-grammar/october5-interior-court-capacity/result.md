# Interior raised court capacity — October 5

Study only. No production placement/support rule changed. Previous turn was progress: it resolved the suspected turret fragment and accepted the bounded court/frontage candidate. This turn identifies why that candidate does not deliver broad interior raised squares.

## Evidence

`court_site_supply.gd` now supports `--field` (all physically supported datums before boring, no entrance proof), `--share-flat-streets` (diagnostic waiver of house headroom only for supported level street floors), and detailed support refusal categories. It records minimum footprint ring depth. All studies use cut depth 6, mean cut budget 3, the existing shape/area bounds and house-admission rules; this is deliberately generous capacity, not production acceptance (production only grants six bands for three-sided broad sites).

The field-only count requires a broad footprint of at least 3×3, minimum ring depth 3 and majority buildable frontage on at least three sides. All counted field sites have floor band >=2. Counts include overlapping alternatives, **not simultaneously placeable squares**.

| Town | Interior field candidates | Three-sided sites at early reservation | Three-sided sites after carve, shared-floor study |
|---|---:|---:|---:|
| 31:large | 26 | 1 | 1 |
| 8:grand | 86 | 0 | 0 |
| 9:grand | 7 | 0 | 0 |
| 13:grand | 3 | 0 | 0 |
| 43:grand | 62 | 0 | 0 |
| 53:grand | 39 | 0 | 1 |
| 63:grand | 19 | 0 | 0 |
| 83:grand | 88 | 0 | 0 |
| 103:grand | 19 | 0 | 0 |
| 301:grand | 42 | 0 | 0 |

The early snapshot is immediately before `WarrenPlotPlanner.reserve(preview, profile, false)` in `_preview_reserved_columns`: the mandatory spine, gate access and house-site access exist; optional descent, perimeter and alleys do not. A reversible study inserted a read-only probe there and restored WarrenMazeCarver byte-for-byte in finally. Both runs completed. The study script is retained here; it uses the current harness to construct its temporary analyzer.

Examples before boring: 53/grand has a supported 3×3 candidate at (-2,-4), floor 6, minimum ring 5, four buildable sides, cut cost 24. 103/grand has (-4,-1), floor 10, ring 5, four sides, cost 24. 13/grand has (-2,-5), floor 4, ring 3, three sides, cost 2. These are diagnostic coordinates only; no seed or coordinate belongs in production selection.

## Findings and rejected shortcut

A square currently uses `plot_support_ok`, which requires empty house clearance and therefore rejects existing street headroom. This looks suspicious for a public floor, but waiving that condition alone yields no additional three-sided site in the corpus. Added sites in 13/grand have at most one majority buildable side. Do not ship the waiver as the requested square fix; it also needs explicit source ownership, paving and planting handling if pursued later.

Moving the existing reservation merely ahead of optional alleys is also insufficient: only 31/large has a three-sided broad candidate at that stage. The uncarved field, however, offers interior raised geometry in every reviewed town. The existing broad-floor tests therefore do not establish that the town field lacks room; the addressed floor heights and early route topology are the limiting interaction.

## Next implementation direction

Co-plan an interior supported square and its level entrance before the main spine is fixed. Select a site from current geometry with seeded, stable ranking; preserve its floor support and house frontage while finding a connected approach at its datum. No terrain/support waiver, forced cut through a plinth, seed-specific placement or later floating deck. Failed proposals must leave the ordinary town intact. Test complete source admission, final inhabited enclosure, court/door traversal, planted-core clearance, carried tunnels/skywalks and native visuals. The field study does not prove those downstream conditions and is not implementation of that feature.

Overall redesign remains active. No rendering claim is made for this diagnostic-only change. All study jobs are terminal; production carver is restored.
