# Sheet style as one implicit solid (September 24)

Owner on `09-sheet-ridges-rocks`:
- slopes have weird edges and don't wrap corners continuously;
- stacked cliffs (an outer corner above an inner corner) leave spots with no slope, and the storeys should be one continuous slope;
- corner shapes are too angular;
- rocks are too small and spread out; bunches should form outcrops;
- ridges and valleys aren't visible; a line across the slope should roll up and down (owner sketch).

Images: last round | now, seed 2697992464. `green-wide-now.png` is a new wide view of the green massif.

## Root cause

Each foot line had its own sheet, and each column chose its own base ("hang to the lowest ground in front"). Neighbouring columns disagreed wherever the ground stepped, which produced folds at corners and no slope where storeys stacked. Overlapping sheets met in creases.

## Model (`CliffSlopeField`, `sheet` style)

- **Height per foot line.** Every merged foot line and outer-corner arc defines the slope height as a function of horizontal distance d from its lip.
  - Behind the lip it sits just under the grass cap.
  - In front it falls `a·x^0.6`, near vertical under the lip and ever gentler.
  - It keeps falling past any lower terrace edge until it meets real ground.
- **One surface.** The surface is a smooth union of every slope and the terrain (sunk 0.3 m), with a 3 m fillet between storeys and 1.4 m within one. There's no per-column frame, so storeys, outer corners above inner corners and narrow terraces flow into one hillside.
- **Joins.** A corner arc and its arms join exactly: blending fades at that seam.
- **Line ends.** A line end without an arc runs on 2.5 m past the wall, receding into it, rather than stopping in a seam.
- **Lip cap.** The union is capped at the lip, so overlapping lip caps at inner corners can't swell through the grass.
- **Ridges.** A warped two-octave ridge value (crests 8-15 m apart) scales each slope's reach ±45%. It also lifts the whole face up to 2.2 m at mid-slope, so contours at every height roll.
- **Bumps.** Small bumps are sampled by height and distance; distance-only noise drew vertical flutes on the steep upper face.
- **Mesh.** Surface nets on a world-aligned 0.5 m grid. Each column's edges span the union of its and its neighbours' level ranges (a short column beside a tall one used to leave the tall one's side open: "bars"). Normals come from the field gradient, and pieces under 60 triangles are dropped.

## Rocks

- **Outcrops.** On 14 m slots along every merged foot line (about 70% of slots), with 7-11 rocks per bunch packed within about one core width. Cliff masses stand where the slope is steep; layered rocks lie where it is gentle. They sit on the combined surface, and the solid unions a smaller ellipsoid per rock.

## Limits

- **Creases.** A few shallow vertical creases remain where storeys' slopes cross at an angle.
- **Floating clusters.** Some outcrops sit high near crests and read as clusters hanging on the steep face.
- **Coverage.** The native grass lip is now covered where the sheet rises to the crest.
- **Assets.** Rocks still load from the source packs, with no collision.
- **Plants.** The sheet style has no plants.
- **Cost.** A green-site rebuild takes about 2.5 min under load; the amber site takes 38 s.
- **Capture issue.** One amber capture iteration rendered black for every style and then hit a native-mesh assertion in unchanged corner code. The process was restarted; this is the known intermittent Metal capture state.

## Tests

The September 23 file has 23 passing tests, including:
- one slope for the whole wall;
- ridges rise and fall at 2 m and 3.5 m from the wall;
- stacked cliffs merge;
- outer corners wrap at full size;
- inner corners fill;
- chunk seams are shared;
- outcrops;
- the upper outer corner flows into the lower inner corner;
- no visible mesh holes (red with the old edge loop: 49 open edges).
