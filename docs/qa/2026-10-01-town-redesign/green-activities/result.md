# October 3 — activities along central-green streets

The previous dresser placed one group per reserved space, scanning columns
in coordinate order. A broad central green consequently received the same
small cluster as a tiny pocket, usually at an edge. Large reserved spaces now
have an area-dependent budget of up to four groups, with deterministic shuffled
candidate order and 16 m separation between group anchors across spaces. The
budget is a maximum, not a forced placement count. Each must find a visible
ground street within 12 m and pass existing whole-group ground/path clearance.
Additional green activities sample courtyard seating, vendors, or green/camp
uses. Green seating uses a complete authored table assembly, rather than a
loose bench/barrel pair. Tree density remains independently seeded.

The first trial put 26 groups in 17/large and left unrelated objects mid-lawn;
rejected. The accepted spacing/reach gives 13 groups / 15 props (previously
5 / 10), zero trees as dictated by its urban roll. 24/large gives five groups /
five props (previously two / four), and retains 44 trees. This is improved
street-edge use, not a claim that all composition or planting is finished.

Close renders also exposed a canopy/flower-box contact. Increasing the coarse
body setback alone did not resolve it: planning volumes omit finished facade
details. `TownGroundDressing._native_ground_clearances` now indexes measured
bounds of exposed low native entries, including noncolliding flowers/trim,
before any new groups or trees. Buried pieces and high roofs are excluded.
The render harness now supplies the same finished entries and asset bounds as
production; formerly it tested only the grid. The offending canopy relocates
clear of the house in the final native render.

Validation: full dressing suite 15/15, 17,527 assertions (26.578 s), followed by
strengthening the real 17/large test with its finished kit payload: 1/1,
8,397 assertions (17.529 s), checking every new prop against low native bounds
and public surfaces, plus separated central activities within street reach.
Deterministic replay, no forced urban trees, atomic groups, actual asset demand,
canopy/root clearance, wall setbacks and hidden/buried bounds tests pass.
`git diff --check` passes. No new player-controller run in this pass.

Final evidence is in `native-clearance/` (17/24 overviews and native close views).
Earlier `final/`, `accepted/`, `close/`, and root images are superseded trials;
`accepted/` was named before the actual-geometry omission was discovered and
must not be used as final acceptance. Test and native logs copied here.

Remaining: broad building/facade composition and visual acceptance, the positive
terminal-roof fixture, full regression classification and updated production
performance/streamed-world checks. The flat review ground is not evidence of
production grass rendering. Goal remains active.
