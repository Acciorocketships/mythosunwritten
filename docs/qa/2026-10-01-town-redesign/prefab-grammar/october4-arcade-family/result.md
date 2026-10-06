# October 4 — prefab-derived inhabited arcade study

StreetHouse_8c now has a bounded architectural grammar. The default reproduces
the complete original prefab: all placements and material bindings match the
independent source derivation. The native arcade, recessed storefront, stepped
rear frontage, balcony, supports and connected roof stay together.

The sampler varies one or two closed upper courses and a compatible side-window
bay. Removing the upper course moves the complete roof assembly down one native
3 m course; it does not independently scatter roof pieces. Three combinations
are sampled deterministically. No geometry is stretched.

The first short variant was rejected: the original upper Window_19_2 hood
intersected the lowered eave. The short rule now substitutes a whole flush
Window_1_2 panel at that interface. The lower projecting bay remains intact.
The taller variant can use a whole Window_5_2 side bay with its original hood.
Its additional native roof material is supplied explicitly; common materials
continue to come from the source house. Missing material bindings still fail.

## Verification

Six focused tests / 10,350 assertions pass, including existing prefab
reconstruction regressions. All three sampled configurations receive native
mesh-triangle roof and upper-wall enclosure probes, including both upper courses
on the taller variants. The covered arcade remains open beneath a real floor.
The source derivation comparison checks every matrix and material binding.
Seed checks preserve complete arches and the lower projection.

Front and back native renders of the short and hooded tall variants were
inspected. The low roof clears its replacement window; the authored roof
junction, rear balcony and lower projections remain. These images use source
materials, not final production palette treatment.

## Status and limits

This family is a study, NOT enabled in production town generation. It still
needs material-bound stock baking, full envelope reservations, terrain support,
entrance access and actual-player collision checks before admission. Its tall
proportions and remaining blank areas also need judgment in a town composition.
This does not close the wider redesign or all defects in the owner's screenshot.
