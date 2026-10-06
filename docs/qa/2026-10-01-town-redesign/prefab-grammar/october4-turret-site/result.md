# Corner-turret compiler and ground entrance

The complete modular House_16c derivation and its one-course extension now compile
through the native recipe pipeline, retaining their baked material-binding IDs
and reflected geometry. Double reflection restores the original geometry ID
without losing the material variant. Missing bindings reject the whole payload.

`NativeTurretSite` selects the lowest authored door and the front-facing stair,
not the last door in the part list. The higher terrace door is private. Ground
is the authored zero datum; buried foundation bevels do not raise the house.
The entrance route includes the shared landing turn. Foundation contact bounds
are measured independently from modules that cross the ground datum.

Actual-character testing rejected the original stairs at production scale:
3 uphill failures out of 8 direct walks. Doubling Stone_Stair_2 doubles its
risers above the character step limit. At scale 2, both flights now use the
pack's 3 m Stone_Stair_11 at its authored world size and original landing joints.
Scale 1 preserves the original flights. The revised direct walks passed 8/8.
The final arrival margin accounts for the stair's local scale as well as the
house scale; assembled recipe walks with that margin passed 8/8, four yaws,
up/down, source and raised-course houses, with the production ground guard.

The first assembled test also rejected the public landing because the house's
whole bounding envelope treated empty ground beneath the spire reach as solid.
Recipe compilation now releases only forward ground-approach cells that have
no intersection with any module bounds. It keeps the higher occupied courses
and all other private cells. The fixture now seals with a real public landing.

Final focused tests: 9/9, 17,977 assertions across turret siting, bound asset
compilation, existing native recipe assembly and street-house siting.
Native front/back and entrance renders inspected. The frontal image shows the
replacement flight meeting the source stone landing and door; no new stair gap
was observed. Some source wall faces remain plain, so these views are not full
art acceptance of the family or of the town.

Still NOT registered for town sampling. The existing native vocabulary exporter
requires every solid cell to lie behind the street-facing entrance; this house
has a high spire and lateral mass beyond that line. Its complete reservation
must be represented or the street approach moved with real access preserved.
Do not discard the overhang reservation, clip the spire, or substitute this
house into an unrelated landmark footprint. Full-town admission, distribution,
terrain checks and player review remain next. The wider redesign goal remains
open, including broader prefab generalization and unresolved existing failures.
