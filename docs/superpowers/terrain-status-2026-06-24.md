# Terrain status — 2026-06-24

**Branch:** `refactor/terrain-field-driven` @ `af73e18`. Full suite **218/218**.

## What was broken, and what I did

Your screenshot showed **brown void chasms** and **missing/misaligned cliff edges**.
Diagnosis: both were caused by my FR-1 field-driven-water work, not the baseline.

- **Brown chasms** = I disabled `WaterRule` (FR-1 plan) and the field-driven water
  that was meant to replace it was too sparse / didn't fill those cells, so former
  water areas rendered as empty voids.
- **Missing cliff edges** = the FR-1 descriptor changes (`cell_descriptor_v2`)
  dropped some cliff/bank wall tiles.

**Fix: reverted the entire FR-1 water work** back to the clean baseline (heightfield
+ `WaterRule`). Verified in-game:
- No chasms — former chasm areas render as **real water** (blue, at y=0, with banks).
- Cliff edges/walls are back.
- 218/218 tests green.
- Also shrank `WATER_CLEAR_RADIUS` 130→40 so water appears nearer spawn (it was
  suppressed out to ~220 m before).

The FR-1 attempts are preserved as git tags `fr1-water-attempt-1` and
`fr1-water-v2-nondestructive` (recoverable, but they break terrain — do not re-merge
as-is).

## The remaining issue: cliffs don't visually "mesh"

This one is **pre-existing** (it's in the baseline too, not something my revert can
fix). The cause:
- **Ground tiles use a rounded mesh** (`hill_top_e_center`) → smooth rolling green hills.
- **Cliff tiles are flat-faced blocky terraces** (the `slope/` generated meshes).

So sharp grey cliffs sit on soft rounded hills and clash. This is exactly what **FR-2
(unify the mesh layer)** was scoped to address, but it needs an **art-direction call
from you**, because there are two opposite ways to make them mesh:

1. **Flatten the ground** — make ground/level tiles clean flat platforms so cliffs are
   crisp steps between terraces (a sharper, more "blocky/terraced" look).
2. **Soften the cliffs** — give cliff faces rounded/sloped profiles that blend into the
   hills (a softer, more "organic" look). The slope generator already produces sloped
   faces, so this is feasible.

I did **not** pick one unilaterally — it's a visual-identity decision for your game.
Tell me which direction (1 or 2) and I'll implement it.

## Where this leaves the field-driven rewrite (FR-1/2/3)

The FR-1 multi-elevation-water feature proved risky: carving the height field breaks
the cliff/corner system, and non-destructive water is too sparse to be worthwhile. My
recommendation:
- **Keep the baseline water** (`WaterRule`, y=0) for now — it works.
- Treat **"make cliffs mesh"** as the real next task (it's the visible problem), via
  FR-2 once you pick a direction.
- Revisit field-driven *multi-elevation* water only if you specifically want lakes at
  altitude — it's a feature with real design cost, not a refactor win.
