# September 10: terrain, feet and edge turning

The screenshot's rising foreground was inside the old cylindrical fade even
though it projected below the character. The shader now uses a finite cone
whose apex is the camera and whose base surrounds the player. A projected-foot
boundary protects visible supporting ground. This operates on rendered surface
positions, not collision shapes: separate components and collision-free meshes
participate automatically, without making an entire terrain batch transparent.
Terrain that actually hides the character can still fade.

The reported seed is 2697992464, player (-72.9, 12.4, -201.4), crosshair
(-72.8, 13.6, -201.0). `tactical_reported_qa.tscn` uses `ReviewCam.solve_cam`
with the current 26 m distance, 16 m height and 1 m aim height. The rounded
overlay permits an inferred camera, not recovery of the original full-precision
pose. Matched opaque/fade renders and two nearby angles reproduce the old patch
and remove it after the fix. In the ground patch ROI, 24,940–28,391 pixels
previously changed by more than 10 channel levels; all three corrected pairs
have zero such pixels. Moving atmosphere causes small remaining differences.
See `cone-terrain-metrics.json` and the local render directories
`.artifacts/tactical-reported-before/` and `.artifacts/tactical-reported-after/`.

The GPU regression first failed for rising ground and near-camera surfaces;
it now protects both while retaining coverage for real intervening hills and
neighboring components. The synthetic multipart roof/wall review also retains
the reveal, opaque distant objects and material restoration.

## Directional motion

The supplied strafe clips turn the whole rig by 60 degrees. Their actual foot
travel therefore was not perpendicular to the aimed head. Mixing that rotated
root with backward motion made the diagonals especially wrong. There was also
an AnimationTree library-cache issue: replacing the player's library required
rebinding the tree before its corrected private animations were used.

The corrected private clips put 90-degree travel into the leg branches while
keeping the root frame shared with forward/backward clips. Both upper-leg
rotation and animated position offsets are transformed; changing rotations
alone leaves the foot travel wrong. Spine compensation preserves the source
head position and orientation. Source assets are unchanged. Foot phases and
normalized loop durations remain aligned.

Quaternion blends do not produce linearly spaced travel angles. The calibration
harness measures planted-foot motion on the actual evaluated tree at 33 weights
per quadrant for walking, half walk/run, running and backward blends. The inverse
lookup chooses weights from requested travel direction. Regenerate the measured
JSON and lookup script with:

```
Godot --headless --path . --log-file /private/tmp/calibration.log -s tests/harness/directional_blend_calibration.gd
```

Before correction, 12 of 16 directional checks failed, with error up to 86.3°.
The final checks pass 16 directions at five walk/run mixtures with a 6° ceiling.
Additional checks cover loop continuity, lifting feet, reversals, independent
instances and preservation of the source head pose within 0.1° and 1 mm.
The eight-direction, 30-frame rendered sequence at 10 m/s was visually inspected
at multiple phases; it retains alternating feet without the backward diagonal
misdirection. Locomotion speed remains 10 m/s; animation cadence remains capped,
so this does not establish perfect zero-slip foot planting at that speed.
Local frames: `.artifacts/tactical-retargeted-full-speed/`.

## Mouse direction and validation limits

The user's live follow-up confirmed rotation was occurring but turning the
wrong way. Positive camera-boom yaw looks left, so the outward drag contribution
now subtracts from boom yaw. Rightward dragging turns the view right; leftward
dragging turns it left. The existing edge-only distance gain is unchanged.
The regression failed on the old sign and now checks both accumulated rotation
and the resulting world-space viewing direction. Native-window tests also cover
inward return, GUI clicks, F7, focus loss and Escape release. The final sign change
has automated native-window verification, not a separate completed embedded-editor
manual replay. `tactical_input_review.tscn` remains available for that replay.

Headless focused checks pass 34 tests / 393 assertions across controls, camera,
visibility, animation, stairs and swimming (28/274 plus final animation 6/119).
GPU controls/visibility checks pass 15 tests / 122 assertions; the first combined
GPU run reached the passing summary then hit the previously observed native
signal-11 shutdown failure. The final serial GPU rerun passed 15/122 and exited 0;
an overlapping-window rerun was stopped after render-frame waits stalled.
The final animation capture also exited 0. Logs are retained locally under
`.artifacts/tactical-follow-up-validation/`.
The broad suite was not rerun for these focused changes; its documented baseline
failures remain unresolved.
