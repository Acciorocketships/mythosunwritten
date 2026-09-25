# Platform guard investigation

Photo 5 is the four-cell edge x=-3.75, band 5, z=2..5 in the frozen
September 10 stone-town source. The missing segments are -2:5:z:-1:0.

Alternatives: move the roof; add a special railing around this particular
platform; correct fall-barrier classification. The third addresses the actual
cause while preserving roofs, floors and all construction reservations.

The roof belongs to `roof.slim.blue` and has a rectangular solid reservation.
It slopes down outside this platform; its bounding cells are not full walls.
The first candidate excluded only recipes tagged pitched_roof and failed all
four assertions: this older slim recipe is tagged roof/staggered_roof, without
pitched_roof. That candidate is rejected (`after/`). The corrected rule consumes
the shared roof role and leaves all roof cells in structural clearance.

`red.txt` records all four absent sections before the production change.
`roof-ownership.txt` identifies the exact source owner and false barrier boxes.
The static after and physical verification are not acceptance until judged.
