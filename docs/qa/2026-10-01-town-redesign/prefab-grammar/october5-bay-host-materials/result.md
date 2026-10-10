# Outcroppings match their host finish, October 5

Two independent mismatches caused lighter projecting bays. The assembler omitted the storey's finish when emitting a bay, passing white while adjacent wall panels received the chosen house tint. Also, Pure Village kits inherited Suntail's pale `Wall` material on their native frame-extension bays.

Bays now receive the same storey finish. Pure kits use two geometry-identical variants of the Suntail bay whose one plaster surface is replaced with the exact existing Pure Village `Plaster` material. Glass, roof and timber retain their authored materials; oak/walnut variants retain the existing frame palette. Source resources remain untouched. The repeatable bake is `tools/environment_bake/bake_pure_bay_materials.gd`; it writes two visuals and six descriptors. No texture is fabricated.

The tint regression fails on the previous assembler in both kits and passes after the fix. Final tests: 2 tests / 110 assertions pass, checking shared plaster textures/color/normal map, exact native vertex/UV/normal arrays, exact collision faces/transforms, all three frame finishes, and unchanged other materials for native finish. An initial assertion compared collision Resource identity across separate saved files and failed; the final test correctly compares collision geometry and transforms.

Matched 103/grand native renders include before, tint-only, and final host-plaster versions. The tint-only image retained a noticeable material difference; the final bays match the surrounding cream plaster. Geometry and native roof connections are retained. This completes the identified bay infill/finish mismatch, not a blanket acceptance of every building material or all other outstanding town work.

The roof-palette regression suite also passes: 2 tests / 2,059 assertions. The process completed with exit 0; output is saved as `palette-tests.out` alongside this report.
