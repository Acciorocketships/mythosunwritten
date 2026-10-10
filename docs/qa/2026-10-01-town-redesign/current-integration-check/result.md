# Current integration check

All checks use the current town implementation including ordinary wall rooms, native retaining corbels and masonry supports. The previous goal turn made production changes; this turn supplies broader verification and identifies a remaining failure.

- Quiet real-terrain production-site test: 149/149 assertions, 6,182 ms against unchanged 8,000 ms solve limit. This is the established compact production site, not universal performance acceptance.
- Integrated tunnel-host/skywalk/elevated-court/platform-relief suites: 12/14 tests pass, 608/612 assertions, 290.552 seconds. Final 24-town bridge-house count is 12 (minimum 12), with zero floating masses across the checked builds. September 29 skywalk endpoint/floor checks pass.
- Actual character: 7/standard, two skywalks, one source bridge and one underpass, both directions, 8/8 passed. This tests those published routes, not all possible routes.
- Two elevated-court tests fail because 58/large and 58/grand preselect band 4 instead of the asserted upper-tier band 8. 13/grand remains at band 8. The selected court still survives to the final layout; support, declared surface and public-air assertions pass. Failures are the four elevation assertions, not construction errors.

Do not repin these tests merely to obtain green output. The next investigation is upper-tier site availability/selection after early required gates and district connections. `_preview_reserved_columns` runs before plot partition/wall rooms, and rendering/material changes cannot affect that source-stage choice. This rules out the latest retaining rendering as the cause, but does not identify which earlier layout revision changed the sites. Compare candidate availability before changing ranking or reservations. Seed-specific fixes are prohibited.

All jobs terminal. Full redesign remains active: upper courtyard coverage, broad facade art, streaming/memory and full regression classification still require evidence. No production algorithm changed in this checkpoint.
