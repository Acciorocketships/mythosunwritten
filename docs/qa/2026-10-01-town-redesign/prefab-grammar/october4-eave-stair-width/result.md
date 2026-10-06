# Roof/stair corner: a physical width candidate

The previous asset-only repairs could not keep the low roof intact beside the
compact photo-town stair. A new construction trial changes the stair edge,
then regenerates clearance from its actual tread triangles. It does not shrink
the clearance height or ignore the conflicting asset.

For seed 85830433957479026/compact, `volume.transition.07.mesh` occupies 8 world
metres across. Holding its opposite edge fixed and moving its roof-side edge
inward 0.6 world metres leaves a 7.4 m flight. Combined with the existing native
flush-verge assembly at the adjoining landing, this clears every emitted part
of roof 0 from all public air. An inward move of 0.4 world metres still cuts
the straight slope and the end cap. This gives a usable geometric bracket.

The reproducible diagnostic is:

```sh
Godot --headless --path . -s tests/harness/suntail/eave_stair_width_probe.gd
```

It replaces exactly the flight's 16 original tread prisms, keeps all other
public volumes (including the landing), and regenerates the changed prisms with
`KitPublicClearance.from_mesh`. It tests every assembled roof part against those
volumes. It bypasses legitimate roof-junction/flush-verge trimming when measuring
public-air loss, so intentional ridge-end trimming cannot masquerade as another
stair collision. Assertions require the original two conflicts, failure at a
0.2 native inset, and complete public-air clearance at 0.3 native.

## Not yet a production repair

The trial changes only a copy of the floor geometry used by the diagnostic.
Production stairs, public air and roof auditing remain unchanged. The current
transition model owns two fine-grid lanes and a fixed full-width flight; simply
changing its rendered mesh would leave its guards, landing edge openings and
surface claims inconsistent. No such substitution is admitted.

The next implementation needs an explicit physical flight-edge profile shared
by tread/collision emission, guards, landing opening treatment and public-air
construction. An inward side edge must connect safely to the wider landing's
rail at both ends, and adjacent route connections must retain their required
width. Admission should use actual geometry and remain deterministic, with no
seed-specific production case. Player traversal and native close views are
required before accepting it. Alternatively the planner can choose a different
room/roof interface with the same complete-geometry proof.

This is new construction evidence for the remaining corner, not a claim that
the roof defect or the overall redesign is fixed.
