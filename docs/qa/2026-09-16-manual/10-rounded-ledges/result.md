# Rounded carved cliff candidate — art review OPEN

This candidate follows the owner's latest direction: rounded worn faces, sharp finite ledges, irregular composition and larger lower supporting masses. Neither the previous two-band version nor the inflated boulder version is restored. The supplied [gold-standard reference](reference/gold-standard.webp) governs shape/composition; [the earlier closer game version](reference/closer-earlier-direction.png) remains useful for the ledge treatment.

## Current change

- A shared world-coordinate rock profile joins canonical owners without pod ends. Four potential cuts have finite independent spans, staggered elevations and grades; they do not become continuous wall-wide courses.
- The lower body gains broad variable boulder relief, with restrained total projection. Gray attachment joins the native wall; exposed flatter caps use the native turf material/UV.
- Short staggered fractures and clefts break up large faces. Smooth stone normals remove the conspicuous triangle-grid shading while turf keeps a sharp edge.
- Exact coplanar shelf borders and actual overlying triangles support ordinary grass without treating triangulation diagonals as cliff edges. Ferns/ivy retain real crevice contacts, mixed native shapes and grass-colour ownership from the preceding work.
- Column-constant fracture data is calculated once. Eight panel records are byte-identical to the uncached implementation; the scoped benchmark improves from 19,024 to 10,194 ms under capture load.

## Judgment and evidence

Five current native studio views: [front](study-07/front.png), [oblique](study-07/oblique.png), [close](study-07/close.png), [wide](study-07/wide.png), [elevated ledges](study-07/ledges.png).

Study 05's smooth draped appearance was rejected. Study 06 added physical detail but showed too much small-triangle shading. Study 07 reduces that shading and increases ledge height/grade variation. It is a direction candidate, **not accepted final art**. Large faces still look smoother than the reference; transition into the unchanged repeating native upper wall needs further judgment. The studio is deliberately simple and does not establish biome, full-world composition or traversal acceptance.

21 focused tests / 1,397 assertions pass across `grass-06.log`, `ledges-01.log` and `integration-01.log`. Current geometry has closed physical shells and continuous owner boundaries. The actual grass worker produces 67 supported patches with zero escaped footprint samples or buried roots. Full/split owners match. A 72 m control has 16 substantial finite shelf components, eleven metre-height bins, lengths 1.74–8.35 m and 63.44 m² of turf. Current generated mesh UV/material/physical-vertex checks pass; some integration assertions also cover retained historical assets and do not prove current art.

## Incomplete production verification

Production-01 is an **older intermediate** candidate, captured before final geometry and grass changes. Do not present it as the current result.

Production-02 completed nine-chunk startup in 2,092.011 seconds, but did not save images or a world snapshot afterward. A process sample spends 743 of 754 main-thread samples in the Metal frame fence wait. This is evidence of renderer waiting, not a diagnosis of its cause. Unchanged water and feature stages also ran several times slower than the earlier capture. The live review process was stopped; no complete-world visual or performance pass is claimed.

A separate headless snapshot attempt used the same full production readiness checks but was stopped while still generating, after several minutes of slow feature/water work. It did not produce a snapshot. No review process is deliberately left running. The snapshot-only harness path is available for a later retry.

Still required: completed current production captures at the photographed sites, nearby oblique/context views and real character traversal on the final saved collision. Other water, town, streaming and palette reports in [the issue register](../issues.md) remain open. No owner approval, gold-standard match or complete original-task acceptance is claimed.
