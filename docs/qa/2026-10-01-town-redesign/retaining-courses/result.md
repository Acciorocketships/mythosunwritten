# Intermediate native retaining courses

## Change

Tall retained faces now accept complete native stone corbel modules at intermediate
storey tops as well as the exposed crown. The previous crown-only condition left
the lower face entirely flat. Whole measured bounds still reject public air,
neighbour geometry, towers and duplicate relief. No module is stretched or clipped.

Retaining panels use existing Pure Village stone instead of the framed Suntail
panel. This removes the repeating timber grid and gives the corbels matching
masonry. Habitable building walls and tunnel ceiling materials are unchanged.
One-band base courses retain their existing construction and need further close
review across mixed-height supports.

## Iteration and evidence

- Studied original Stone_Pillar_1/2/3 and WallStone_Bottom_Middle_30x15_2;
  source dimensions and front/back renders are saved. The pillars are largely
  straight posts, so were not added merely to replace one grid with another.
- Red regression: lower/intermediate relief absent and old framed panel selected,
  three failed assertions. Final four suites pass **8/8, 165 assertions**:
  retaining relief, ordinary wall rooms, public clearance and native ramparts.
- Rejected unframed blue-grey Suntail backing: white corbel courses looked pasted
  onto it. See `rejected-blue-backing.png`.
- Native Pure Village backing reviewed in 41/large and 67/large overviews and
  a close view of 67's retaining face. The close view shows complete projecting
  caps and curved brackets, with no invented texture or standalone arch.
- Admitted whole modules: 41 grows from 4 to 7; 67 from 9 to 16.
- Actual CharacterBody3D walks in 67/large: plaza.00 and deck.00, both directions,
  **4/4 pass** after the final material/geometry change.
- All processes terminal; `git diff --check` clean.

## Remaining acceptance

Seed 41's large path-facing support remains substantially blank: the existing
clearance rules prevent the large native corbel from fitting there. This is
still an art failure requiring a different architectural treatment. The 67 face
has improved depth but remains repetitive; this increment does not establish
full town architecture acceptance, broad streaming performance or full regression
completion. The whole redesign goal remains active.
