# Partial black-screen corruption

Treat the owner's partial screen-aligned corruption separately from earlier
wholly black capture readbacks. Reproduce repeated orbit in the actual native
village snapshot and classify partial versus whole-frame black. Preserve exact
camera transforms for any anomaly and compare bubble-off, local-light-off and
post-processing-off controls at that same transform. Test the original adapter
as well as the accepted current adapter. UI text is present in the manual photo;
include a small diagnostic overlay in the rendered target.

Potential causes are material/buffer adaptation, shadow or depth history,
post-processing, and clustered local lights. An upstream Apple/Metal Forward+
cluster bug has a matching broad visual description, but is not yet a local
reproduction or accepted cause:
- https://github.com/godotengine/godot/issues/121201
- https://github.com/godotengine/godot/pull/121610

Do not remove lights/effects or change renderers as a cosmetic cover without
local falsification and a preservation/performance comparison.
