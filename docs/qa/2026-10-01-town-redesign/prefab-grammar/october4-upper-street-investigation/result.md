# Upper-street enclosure investigation, October 4

Status: diagnostic checkpoint; no production layout change accepted. The town redesign remains open.

Finished houses and emitted bridge-houses in seeds 7/standard, 31/large and 103/grand cover respectively 36, 22 and 40 fine public quarters. In 31/large, 34 of 36 uncovered raised quarters have no immediately adjacent inhabited facade. This measures inhabited frontage, not all visual enclosure: a new separate structural-volume measure finds 11 of those 36 quarters beside at least one retaining/support wall. The measures are not additive and do not measure distant facade or tree canopy enclosure.

Native platform renders show the remaining problem: the citadel climb wraps around exposed outer edges beside tall uninterrupted house fronts. `31_large_platform_far2.png` and `far3.png` are useful views. The old automatic `platform_gate_flight` camera lands inside wall geometry; that image is NOT acceptable street-level evidence. No player walk was performed in this checkpoint.

## Rejected experiment

The carver's `_column_carries_house_at` reads raw massif height and carved air but not the later cottage/edge/huddle height caps. A trial shared construction cap made two small synthetic regressions pass (red: 1/3 tests, 4/6 assertions; green: 3/3, 6/6). However, all three finished towns were unchanged: coverage, inhabited flank histograms, source tunnel count, and bridge count. Floating and public-air intrusion audits remained zero. The experiment was removed from production; its tests and outputs are archived here as evidence rather than left as failing active tests. It does not solve the photographed route.

The added `tunnel_limits` diagnostic also disproves a tempting local repair: the two 31/large covers rejected by the citadel huddle limit need minimum top 8 (crown 2, host floor 4, full room and roof reservation), but their permitted top is only 4. Truncating the host would not fit even one complete room. No height limit, bearing or headroom rule was relaxed.

## Retained changes

`tests/harness/suntail/inhabited_enclosure_probe.gd` now reports minimum complete cover height versus huddle/edge caps, and separate per-quarter structural flanks. Validated by completed headless seed 31/large run. Existing layout is preserved.

## Next work

Co-design the `WarrenPlatformStreets` gate climb with inhabited room/covered-passage reservations and load paths. The source's platform sides can legitimately count retaining walls, but the current climb still stays on the exterior. Preserve stairs, entrance access, actual support, clearance, optional platform frequency and green spaces. Judge a candidate with actual character traversals and properly placed street-level cameras as well as matched overheads. Also retain the unresolved tall flat frontage as a separate art failure; this checkpoint does not fix it.
