# Native gable detail and reflected roof repair

Native compound sites now add the pack's WindowSolo_6 round window at all four
gable peaks. Pure Village House_1 and House_9 use this surface-mounted component;
House_9 uses scale 0.77019. The generated compound uses that smaller proportion,
seated 1.45 m above its peak-panel origin and 0.25 m forward. This clears the
actual diagonal timber and plaster. Default CrossHouse.derive remains the
undressed reconstruction; NativeHouseSite requests the optional detail explicitly.

The first low placement crossed a tie beam. Raising the full-size window still
occluded some glazing behind diagonal timbers. A measured seat probe tested
scale, height and depth; the final exterior-glass test uses indexed Glass_Out
vertices, rather than unrelated vertices in a shared GLB vertex buffer or the
inward-facing Glass_In against the solid wall. Twelve gable ends across three
compound dimensions pass the actual wall/roof triangle visibility test.

## Reflection defect found in the baked town view

The source render had blue tiles, but the generated town showed two large wooden
rectangles on the roof. Negative-determinant roof instances reversed front-face
winding in the instanced renderer. NativeGrammarCompiler.placement now chooses a
baked X-reflected asset and applies the inverse reflection to its instance basis.
NativeHouseRecipe uses the same adapter. World geometry stays identical and the
runtime basis is positive. The existing baker reflects both mesh winding and
collision. The manifest exporter discovers the seven reflected module types in
the validated families and declares those variants explicitly; no runtime source
loads or material substitutions are required. Catalog: 71 ordinary modules plus
seven reflected variants = 78.

The matched before/after town views confirm the wooden roof rectangles are gone.
The round window remains visible above the braces. This corrects the earlier
native-town review: the wooden patches were a renderer reflection defect, not an
acceptable authored roof feature.

## Validation

16 tests / 13,959 assertions pass across gable/roof geometry, compiler and baked
resource dependencies, native site transforms, recipe/assembler reconstruction,
and town integration. Reflected world-space vertex sets match the originals;
recipe tests reconstruct original native transforms through reflected variants
and require positive runtime bases. The final town still preserves the entire
native house, now 110 parts, with no generic replacement and no public-air clash.
Source and baked town views were inspected. This is exterior facade work; it does
not add an accessible attic or an opening through the wall collision.

Still open: sparse lower gables, more native families, frequency and variety,
raised-site supports, broader original town art goals and final acceptance.
