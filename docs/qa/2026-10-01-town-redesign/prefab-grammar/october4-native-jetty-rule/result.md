# Native projecting-room assembly

`PureVillageJetty` encodes StreetHouse_1's 3 m-wide, 1 m-deep upper-room
projection. Local origin is the lower wall face at upper-floor level. Native
Window_3_1 closes its front, two Floor_Down halves close the underside, two
Support_4 brackets meet the lower wall joints, and timber return panels close
its sides. Preserve the source's measured floor seating offsets and uniform
1.2331678867 bracket scale; do not stretch this assembly to arbitrary depths.

The authored right side is a continuous host/jetty wall. `host_owned_returns`
records that ownership and omits the duplicate return while retaining both
brackets. The independent right-return variant mirrors the native short return,
so it reaches outward rather than extending behind the host face.

The component records its room extent, open host connection, required roof
seat, and host-owned returns. These are composition obligations, not proofs:
there is no complete higher-level assembly validator yet. Instantiating the
component alone leaves its host/top connections open by design. It is NOT
production decoration and must not be scattered onto existing roofs.

Evidence:
- 3 tests / 79 assertions pass. Eight authored meshes (front and shutters,
  floor halves, brackets, left return) match their source world vertices within
  0.2 mm and exact triangle topology. Both independent returns start at the
  host and reach the front; shared-side mode drops only its duplicate wall.
- Native source/reconstructed StreetHouse_1 views from front and below differ
  in zero pixels above 8/255; maximum mean channel error <0.00004/255.
- The harness replaces only this component in the authored host. It does not
  establish reconstruction of the rest of StreetHouse_1. The source host and
  roof are explicitly retained; no full-house grammar claim.
- Native component underside inspected: floor closes between the brackets,
  returns face outward and front wall meets the floor beam.

Next: derive the short-cornice roof and host room topology that extend over
this projection, including the authored long end caps, so the assembly can
participate in a whole-house derivation. Then validate novel host combinations,
reserved envelopes, collisions and integration into the town generator.
