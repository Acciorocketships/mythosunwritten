# Continuous profile, rocky face, quality pass (September 24)

Owner on `10-slope-solid`:
- the cliff goes straight down at the top, then turns sharply to an angle, and should be more continuous;
- many more and bigger rocks embedded in the mountain, especially sticking out of the side, which should be very rocky;
- then a quality pass on the complex geometries.

Images: last round | now, seed 2697992464. The `*-now.png` files are wide and top-down views.

## "Straight down, then a sharp turn"

- **Root cause.** The native terrain cell under a plateau reaches about 1.5 m past its wall line. The union with that ground held the slope top flat out to the cell edge and then dropped it vertically.
- **Fix.** In the band just in front of a lip, ground at that lip's level is ignored. The test reproduces a 3 m vertical drop without this.
- **Profile.** The profile is now a quarter circle spread over the whole run plus a gentle straight tail (0.35), in place of `a·x^0.6`. The tail keeps falling past lower terraces, so storeys still merge.
- **Top gap.** The slope top is now flush with the plateau grass (2 cm under), not 30 cm under. Seen from above, the gap had left a dark strip of native rock between grass and moss.

## Rocky face

- **Face rocks.** New: on 4 m slots along every merged foot line (85%, fewer on walls under 8 m), one or two 3.5-7 m rocks stand out of the face at 15-80% of the wall height. Tall stratified masses sit where the slope is steep, layered rocks where it is gentle.
- **Outcrops.** Bigger: 6-9 m cores with 8-12 rocks each.
- **Placement.** All rocks share one rule (`_add_rock`): on the combined surface, middle sunk into it, never over the crest. The solid swells into each rock with a smaller ellipsoid.
- **Speed.** Rocks are placed only near the chunk being computed; they had been placed for every halo line nine times over. The height search is a bisection. Amber rebuild: 171 s back down to 42 s.

## Quality pass

- **Views.** Each site was reviewed from four sides plus top-down, alongside the usual views.
- **Fixed.** The top strip above; face rocks on short walls lining up in a row under the lip; placement cost.
- **Harness, not geometry.** The faint vertical striping around screen centre in several views is the camera's see-through bubble at the harness player position; it appears in the unchanged default style too. Some added cameras landed inside the massif and were discarded.
- **Remaining.**
  - Short dark slivers at the ends of some upper terraces, where a slope recedes into the wall and the native wall edge shows.
  - A few shallow creases where storeys' slopes cross at an angle.
  - Rocks have no collision.
  - No plants in the sheet style.

## Tests

The September 23 file passes 24 tests, including:
- the plateau-cell regression (red without the fix: a 3 m drop);
- face rocks, above 10% of the wall and more than 12 on an 80 m wall;
- outcrops.
