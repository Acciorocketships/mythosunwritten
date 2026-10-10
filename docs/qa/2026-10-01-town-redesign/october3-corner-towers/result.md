# Corner shafts and roof-family matching — October 3

Partial implementation; the broader redesign remains active.

## Retained

The production tower pass now attempts a grounded corner shaft before its
existing lower-wing/half-tower forms. The former roof-emergent fallback is
removed from production selection. Each corner must be the same convex corner
through every occupied shaft band, have actual bearing under its complete native
base, and clear public air, neighbours, openings and other towers. Both adjoining
wall faces participate; blocked doors are never replaced. No per-seed placement.

The large stock fitted the controlled house but none of the first three towns.
The narrow native StoneTower middle/window family fits the generated landmark
corner in 43/grand. Five towns (13,31,43,101,103) produced one corner tower and
one existing half-tower, both in 43. All five built with floating-mass count zero
and measured roof/public-air intrusions zero. This is too rare to claim the
skyline goal complete: early footprint/support reservations remain necessary.

Native cap height stays at its authored quarter-metre lap. Lowering it another
0.4m exposed stone through the cap and was rejected. Pure Village keeps its
original end-cap pieces; Suntail shortens the joining verge to the existing
wall reach. The narrow cap's measured inner lip covers the crossing eave; only
the crossed roof geometry is cut. Native shaft/cap meshes are unchanged.

`KitTowerPalette` follows the adjoining roof's kit role and colour. Blue-slate
Pure Village roofs keep the original blue cap. Suntail warm/weathered roofs
select two new native-cap material bakes using exactly the corresponding roof
wood texture, normal map and tint. Only RoofTiles changes; timber underside and
stone shaft remain independent materials. Both cap sizes have variants. This
fixes the immediate blue-cap/wood-roof mismatch, not the full compound palette.

## Evidence and limits

- `narrow-native/`: initial actual generated corner, before final lip trim.
- `final-town/`: final 43/grand native town overview and tower views.
- `final-pure/`: controlled procedural Pure Village corner, not a prefab.
- `final-wood-join/`: controlled procedural Suntail corner with matching cap.
- `corpus.json`: five-town generation survey before final roof-only seam/material edits.
- `tests.log`: 6/6 targeted tests, 1,251 assertions: corner fitting, cap removal, public clearance, collision and material-variant geometry checks.
- `pure/`, `narrow-pure/`, `narrow-join/`, `narrow-lap/`, `narrow-lip/`,
  `final-wood/`: intermediate comparisons; narrowed Pure verge and lowered cap
  were rejected. A very small isolated Pure eave fragment remains visible in the
  close-up and needs clipping cleanup; do not claim pixel-perfect closure.

No new player route or full-suite/performance acceptance is claimed here.
The gallery fixture is intentionally plain so the joint can be inspected;
it does not establish acceptance of complete building architecture.

## Still open

Reserve corners/lower wings during planning so towers are visible in more towns.
Unify roof/cap/dormer/hood/frame palette across whole compounds, then integrate
and judge the oak/walnut/birch, sage and limestone options in mixed ensembles.
The five material studies in `../october3-palette-study/` remain preview options,
not procedural Gothic architecture. Continue inhabited massifs, enclosure and
canopy review under the main plan.
