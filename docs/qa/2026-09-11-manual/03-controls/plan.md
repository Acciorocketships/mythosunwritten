# Camera control roles

The old close camera derives a smooth trailing heading from actual target motion,
including its 0.8 strafe blend, velocity smoothing and bounded positional follow.
The tactical view currently has no such input. Preserve its elevated fixed boom,
but derive its heading from the old close camera's reference follow motion so
left/right travel has the same angular response. Keep Q/E and tactical pointer
edge orbit available.

The close view instead captures relative mouse motion for yaw and bounded pitch.
It follows position without movement-driven yaw, keeps a small center crosshair,
and uses that heading for character facing even when looking above the horizon.
Its boom still resolves real collision. F7 carries heading between views;
Escape, focus loss, pause and teardown release capture. A game click reacquires
close mouse look after release. Native input, motion and collision probes precede
photo-pin and trajectory comparisons. The current camera is frozen in
`tests/fixtures/september11/ControlsBefore.gd` for paired evidence.
