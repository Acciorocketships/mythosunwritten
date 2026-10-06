# October 4 — arcade stock, siting and assembled entrance

The StreetHouse_8c family now has 104 baked stock variants, including mirrored
visuals/collision with positive runtime transforms. The exporter retains original
matrices and complete material bindings; compiler canonicalization selects the
correct mirrored stock. Arcade materials have their own export namespace so
baking does not overwrite another family's source material resources.

NativeArcadeSite anchors the real recessed ground Door_2_1 to a public address
outside the entire roof and arcade extent. Its private approach remains straight
under the covered frontage. The site records ground contact bounds and rejects
unsupported scale, invalid entry direction and the known short-eave hood conflict.
NativeHouseRecipe.arcade seals the complete stock into the existing fabric recipe
format. No production vocabulary registration or random town selection yet.

The exact source prefab was initially derivable but absent from the random
sampler. This was corrected: the distribution now includes the unchanged source,
two taller window variants and the shortened flush-window variant.

## Evidence

- Bake succeeds; source assets were not modified.
- Nine focused tests / 10,790 assertions pass. These cover all four sampled
  configurations, source reconstruction, native versus baked bounds (1 mm),
  closed roof probes, upper wall enclosure, full recipe part counts, and entry
  frames at scales 1/2 and all four cardinal directions.
- Eight standalone actual-character walks pass (inward/outward, four poses).
- Eight assembled-recipe actual-character walks pass at production scale 2.
- Baked short/tall front and back images inspected: roof junctions, window
  outcroppings, arcade, balcony and supports remain. These are isolated houses,
  not whole-town art acceptance or a final palette review.

The initial rendering process saved both short-house views, then waited idle
without drawing another frame. Its sampled stack showed the ordinary idle loop,
not ongoing import work. It was explicitly stopped. The review now uses the
existing town harness's explicit force_draw before capture; all four views
completed normally on the corrected run.

## Remaining

Register the family in the production vocabulary only with generated-town
selection, terrain support, neighbor-clearance and native art checks. The tall
family still has large quiet wall areas; source fidelity alone does not satisfy
the owner's request for varied, enclosed town composition. Wider town redesign
requirements remain active.
