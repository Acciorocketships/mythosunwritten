# Photo 14 — small interior roof

The new before snapshot includes accepted issues 1–9. The photographed town is
the same settlement `1181f74a2f849a6a` frozen for photo 9, so no seed-geography
change is used as a repair. The candidate source roof is the complete crown of
`spatial.parcel.maze.house.000.part00.room00`, a 2-by-2-cell tower room. At world
scale 2 its crown covers 6 by 6 metres, from y=18.08 to 22.3703 metres.

Options under examination: join the crown visually to its taller neighborhood,
use a deliberately flat planted cap for a genuinely enclosed recess, or change
the room's vertical reservation to complete a taller building. Deleting a roof
without another closed weather surface is not a valid repair. Enlarging a crown
or adding a storey cannot consume neighboring public air or private mass. The
actual source neighborhood and matched pre-change renders will decide between
these options before implementation.


The actual grid shows a complete PUBLIC_FLOOR at band 4 over all four roof
columns, with the room ending at band 2. The source plot already owns its full
0–4 height, but the generic one-band slab allowance rounds this even height
down to one storey. The roof compiler then mistakes the lower exposed plate
for an open-sky crown. This explains the little gable inside the upper town.

The candidate declares a complete public ceiling before parcel sealing. Only
an even-height house plot whose entire footprint has the existing public floor
at its own top qualifies. Its rooms use that full height; the public floor
owns the upper interface and the ordinary surface compiler closes it. Partial,
staggered and open-sky plots keep their existing roof reservations. The same
fact controls parcel identity, storeys and roof-band ownership, including
pre-composition slab reservations. No source plot is moved or retried.

The frozen regression fails before (0 of 8 expected upper-room cells) and
passes after (all 8 private cells, all four public-floor claims retained).
Physical clearance and game-render judgment are pending.


The first broader run rejected the source-marker criterion: the (-17,-12)
interstitial-roof regression has a route marker whose projected stair/floor
geometry does not supply the assumed complete ceiling. That run was stopped
after the new failure, not counted as a passing suite. The replacement reads
all four exact public-floor cells per macro column from the sealed volume.
The same volume reaches roof-band classification and its diagnostic consumers.
Parcel sealing independently checks that exact ceiling. A missing quarter-cell
or a staggered tread therefore cannot grant a full upper storey. The negative
fixture deliberately retains its source marker while removing one actual floor
cell. Ordinary plots retain the previous height contract and signature.


The corrected related suite passes 21 tests / 110 assertions in 112.28 seconds,
exit 0. Godot prints resource/RID/ObjectDB teardown leak warnings after the
passing totals; these are retained in `tests.txt`. The final physical census
is identical before and after: 132 central-clear walk cells and 188 central-
clear crossings, no lateral workaround or blocked crossing. Room comparison
adds exactly `house.000.part01.room00` (eight private cells) and preserves every
existing room's cells. No pitched unit remains over this covered house.

Final acceptance: all six after views and amplified differences were inspected.
The replacement facade closes to the upper deck without a new gap. Camera JSON
is byte-identical. See `result.md` and `verification.json` for final metrics.
