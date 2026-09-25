# Small-crag comparison

The owner rejected pass 34's smaller crags as wrinkled fabric and requested three alternatives. All three were implemented as separate deterministic geometry studies and rendered at matching cameras. **None is promoted to production.** The refined narrow-groove study is the preferred detail direction, not a claim that the cliff composition is finished.

## Judgment

| Alternative | What improved | What remains wrong |
|---|---|---|
| No small crags (`clean`) | Removes the fabric-like physical noise and shader relief. Broad grey colour variation remains. | Too smooth on large exposed faces. Makes existing upright organization more obvious. |
| More outcroppings (`outcrops`) | Adds larger independent grounded shoulders without small crags; more depth is visible in 16 m and 64 m studio views. | Still produces too many upright columns. Changes at the amber photo sites are too subtle to solve the requested composition. Not selected. |
| Narrow, deeper grooves (`grooves`) | Fractures read distinctly from broad stone faces instead of creating all-over wrinkles. | Initial cuts are too long/dark; vertical clefts reinforce block outlines. Retained as the initial trial, not the preferred version. |
| Shorter narrow grooves (`grooves-refined`) | Shortens fracture spans, weakens vertical clefts and samples the thin physical cuts more finely. The amber head-on view is calmer while retaining recognizable fractures. | Some cracks still resemble dark slits; large faces are smooth, upper turf remains thin, and the tall wall remains too vertical. Preferred for further detail work, not accepted as final art. |

The three comparison buttons in [the local viewer](index.html) use `grooves-refined`, `outcrops`, and `clean`. Direct matched amber views: [narrow grooves](grooves-refined/P20_oblique.png), [more outcroppings](outcrops/P20_oblique.png), [no small crags](clean/P20_oblique.png), [current](before/P20_oblique.png). Studio oblique controls: [grooves, 16 m](grooves-refined-16/oblique.png), [outcroppings, 16 m](outcrops-short/oblique.png), [clean, 16 m](clean-short/oblique.png); [grooves, 64 m](grooves-refined-64/oblique.png), [outcroppings, 64 m](outcrops-tall/oblique.png), [clean, 64 m](clean-tall/oblique.png).

## Construction and verification

Every alternative preserves the current shared world-space warm/cool grey material, native wall attachment and ledge builder. The clean and outcrop variants remove the small physical crag field and use a quiet shader without the extra procedural normal relief. The outcrop variant adds world-owned rounded shoulders with stronger lower amplitudes, actual grounded support and unchanged crown/depth bounds.

The first groove trial uses 0.18–0.28 m cut half-widths and deeper finite cuts, with no secondary chip field. Overlapping cuts combine by maximum instead of addition. The refined trial shortens nominal lateral half-spans to 1.1–2.8 m (up to 3.4 m on tall walls), reduces vertical cleft strength and uses 0.125 m lateral / 0.1 m vertical sampling. Its nominal isolated cut is 0.65 m deep before attachment/envelope constraints. The denser mesh is study-only and has no performance acceptance.

Each of `clean`, `outcrops`, `grooves` and `grooves-refined` passes the same six focused tests / twelve assertions: reported ledge channels, pointed turf coverage, closed nondegenerate photo shells, lower bearing and crown clearance. The refined groove also passes the new fracture-overlap regression: one cut erodes 0.65 m; supplying it twice adds zero erosion. Current production reproduces 0.493115 m additional erosion in the duplicate-owner control. This repairs that defect in the experiment only.

There are 27 views per version: seventeen frozen-game context views and five studio views each at 16 m and 64 m. The 17 `before` context images are byte copies of pass 29's latest production review; `before.gd` is byte-identical to production. All studio images and alternative context images were rendered natively for this comparison. `captures.sha256` records all 135 images, including the initial groove trial.

Judged views include P20 oblique and P05 reported close views for all three initial alternatives and the refined groove; P12 side for the groove and outcrop alternatives; 16 m and 64 m oblique controls for all alternatives; and the refined 16 m close view. Other retained views are available for inspection, not individually accepted. The studio uses each variant's own stone shader; it does not silently restore the production shader.

Context captures rebuild rocks and crevice plants in the same frozen world/cameras. Plants resample their contacts, so placement changes are expected. These are not fresh-world admission, streaming, regenerated grass, character traversal, hydraulic or universal collision tests. The separate tall-terrace acceptance investigation from pass 36 remains red on production; no full-suite pass is claimed.

The optional comparison HTML was created with local image paths. Browser-skill connection was unavailable, and the browser security policy blocked automated navigation to its local file. No workaround was used. Native PNGs were inspected directly; browser layout/interaction testing is not claimed.
