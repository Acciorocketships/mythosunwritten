# Compatible facade sampling for the native projecting house

PureVillageStreetHouse now names eligible full-width middle-bay sockets and
accepts explicit opening choices for them. End panels, corner/return trim,
foundations, support brackets and roofs cannot be substituted through this
interface. The reference derivation remains the default and reconstructs exactly.

The deterministic sampler selects a lower-window family per house, paired with
shuttered upper windows. Every eligible side/storey row receives an opening;
other bays can remain solid. This is constrained variation within the existing
native three-metre panel family, not random decorative overlays.

Visual iteration rejected Window_12_2 upstairs: its high glazing is partly
covered by this family's short-cornice roof. The sampler and choice validation
now restrict it to lower walls; Window_1_2 fits upstairs. A geometry regression
casts outward from actual glass vertices against native roof triangles and
confirms the former obstructs the view while the latter does not. The rejected
view is retained beside the corrected native views.

Validation:
- Reference suite unchanged: 6 tests / 6112 assertions pass.
- Coverage and 20-seed sampler tests: 2 tests / 2822 assertions pass. Sampled
  choices preserve every placement transform and every non-facade component;
  no extra overlay panels. Actual triangle closure probes include a sampled
  three-bay house.
- Independent glazing/eave test: 1 test / 4 assertions pass.
- Native sample 7 and sample 31 views rendered. Sample 7 front/underside and
  sample 31 back inspected; corrected sample 7 front confirms the upper-window
  replacement clears the eave.

Not production integrated. Facade sampling reduces blank runs but does not
solve compound footprints, roof articulation, corner towers or the massif/town
requirements. The plain reference shell remains available for reconstruction;
these narrow houses must not become the whole city distribution. Full native
corpus and holdout reconstruction, multi-volume grammar and town envelope
integration remain open.
