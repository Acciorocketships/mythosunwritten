# Contextual terrain cutaway — verification in progress

The owner rejected the character silhouette because it loses nearby context. Its production integration, shaders and render layer were removed. The previous report is preserved only in `rejected-marker/result.md`; its acceptance is withdrawn.

The replacement uses the existing obstacle cutaway. Clear ground and grass stay opaque; only a real terrain obstruction enables removal of raised foreground terrain. A render-only earth section closes the solid volume exposed by that cut. It reuses the actual ground/apron triangles and their footprint. Ground material sharing alone cannot create a section: arches, native terraces and buildings do not own solid earth beneath them. The section follows actual support height during a jump, rather than rising with the actor. No collision shape, terrain mesh data, movement rule or water field changes.

## Rejected intermediate attempts

- Protecting all upward ground hid the actor behind the six/eight-metre banks. The silhouette workaround was rejected by the owner.
- A plane through the eye and feet left a horizontal strip hiding context.
- Removing raised ground revealed sky inside the solid bank. A rendered regression reproduced 6,191 changed-to-sky pixels before section closure.
- Material-wide section closure could fill arches; ownership is now explicit on the solid terrain sheets.
- A feet-height section rose during jumps; physical support anchoring replaces it.
- Frozen replay physics had been disabled along with animation; its collision bodies now remain active. Older snapshots also lack runtime grass/biome bindings and are not credited as palette/grass evidence. The snapshot writer now records those values from their actual live owners.

## Verification status

Twelve `context-owned-live/` pairs (four original reconstructed angles and ±8° views) have been visually judged. They remove the grey ground opening while revealing the ordinary character and nearby ledges. Spawn and town retain ground and grass. The final support-height refinement is being rerendered in `context-rooted-live/`; motion verification and final disposition remain pending.

Reconstruction uses the rounded player/crosshair overlay with `ReviewCam.solve_cam`, distance 26, height 16, look height 1 and FOV 50. Each before/after pair has an identical 1716×1033 camera/viewport and frozen material clocks. The rounded overlays do not provide a recoverable full-precision original camera.

`context-owned-suite.txt`: 35 tests / 259 assertions passed. Subsequent open-span and jump-support controls pass in `context-support-tests.txt` (4 tests / 20 assertions). The final combined run is in `context-rooted-suite.txt`.

The no-void GPU assertion counts newly exposed sky in the interior lower terrain region, excluding the finite test patch's antialiased outer sky silhouette. It also requires ordinary neighboring red/blue scene objects to become visible. A same-material open-span control verifies that the renderer does not invent solid earth beneath it.

The remaining near-camera coverage, back-face/interior visibility, world generation, water, collision and art issues in `../issues.md` are still pending. This is not acceptance of the entire manual pass.
