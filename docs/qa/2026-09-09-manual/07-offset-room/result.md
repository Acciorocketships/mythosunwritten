# Photo 12 — visibly supported facade bay

Status: accepted for the reported unsupported projection.

The circled volume is a two-panel facade bay, not an independently offset
room stamp. Its floor already reached into the wall, but lacked visible
support beneath the deep projection. Each bay now has two plain native timber
knees connecting its bottom plate to the parent wall. Admission includes their
complete bounds; the source rooms, streets and bay footprint remain unchanged.
[Iteration notes](iteration-notes.md) record the alternatives and construction.

All 25 related tests pass with 3,725 assertions (81.802 s, exit 0), including
the earlier outcrop, seam, grass, door and rail regressions. Actual native mesh
bounds verify wall/floor contact and the reserved lower band in four
orientations. The photographed pair has zero braces before and four after.
All 100 walk cells and 140 crossings retain identical physical clearance,
with no blocked cells or crossings.

The exact reconstruction and five additional views were inspected alongside
their differences. The new knees visibly connect the bay to the wall; adjacent
buildings and paths remain unchanged. Exact-view mean absolute RGB difference
is 0.201829/255; 0.202374% of pixels change by more than 20 in any channel.
Minor orb/grass animation differences are separate from the support change.
Paired camera JSON is identical. Original camera precision remains unavailable.
