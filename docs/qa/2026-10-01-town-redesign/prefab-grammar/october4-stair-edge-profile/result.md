# Physical stair edge profiles

`WarrenTransitionSurfaceBuilder.build` now accepts bounded negative/positive
lateral edge insets in local fabric metres. Treads, undersides and collision use
that physical width. Side guards follow the inset edges; short level returns
close the exposed shoulders where those edges meet the wider endpoint landings.
The returns emit collision and the same native railing redraw metadata as the
long guards. Invalid/nonfinite/negative insets, or insets that remove a reserved
lane centre, are rejected.

Deferred guard construction stores the physical half-width and original landing
centres. `PublicRealmSurfacePlan.finish_transition_guards` consumes those same
facts. Raised-court adjacency still uses the original lattice phase, not the
shifted flight centre. Zero-inset geometry and metadata are unchanged.

## Evidence

- Profile geometry in four cardinal directions, ascent/descent, stairs/ramps,
  and three unilateral/bilateral profiles: actual tread-derived air matches the
  requested edges; both lane centres remain supported; every changed landing
  shoulder has a native redraw span and collision at both rail heights.
- Direct and deferred builder output match. The actual surface-plan deferred
  guard pass is also checked. Final profile suite: 3 tests / 686 assertions.
- Production surface suite: 23 tests pass. Combined run before the final
  surface-plan integration assertions: 26 tests / 1,570 assertions.
- Thirty-two direct before/after comparisons against the saved prior builder
  confirm byte-identical dictionary payloads for default stair/ramp geometry,
  all four headings, both rises and direct/deferred guard construction.
- The compact photo-town trial now uses this real builder instead of deforming
  a copied tread mesh. All roof parts again clear public air at a 0.3 native
  (0.6 world) inset; 0.2 native still has two conflicting parts. Headroom remains
  unchanged and all other public volumes remain present.

## Admission remains open

No production caller selects a nonzero inset yet. The remaining work is to
choose profiles from actual roof/route interfaces before final sealing, verify
landing connections against adjacent uses, inspect the native rendering of the
short returns, and walk both directions in the finished town. In particular,
short spans currently use the general kit railing redraw, whose post proportions
need visual judgment. Geometry tests alone do not prove art quality.

The production roof audit remains unchanged and the known compact-town eave
conflict remains until profile selection is integrated and verified. This is
shared construction support for that repair, not completion of the redesign.
