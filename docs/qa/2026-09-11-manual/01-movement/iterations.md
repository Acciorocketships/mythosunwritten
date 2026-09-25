# Issue 1 — movement and camera work, still under review

The four rounded screenshot pins are replayed through `ReviewCam.solve_cam`
with the tactical 26 m / 16 m boom, 1 m look offset and 50° FOV. The frozen
41 MB fixture contains the actual generated town, native visuals and physical
collision. It excludes grass and streaming jobs; live-world checks are separate.
The original overlays do not encode a recoverable full-precision camera.

## Candidates and rejected claims

1. Original per-component adaptation copies every selected MultiMesh buffer.
   Camera updates are expensive while turning, and some paired original renders
   reproduce the black corruption. No recorded movement trace freezes because
   of terrain readiness. Stops coincide with native house, guard, wall and stair
   collision, often identically with the visibility effect disabled.
2. Single-surface instance overrides retain the producer's live MultiMesh.
   The red invariant fails before this change. Some matched original renders
   have corruption absent from the candidate. This does not accept issue 4:
   other original runs do not reproduce the intermittent corruption.
3. Compiled shader history is bounded at 32; source-material owners leave when
   no active geometry uses them. A source snapshot and adapted material are
   shared across components. Geometry-instance strength retains distinct fades.
   Tests cover live source changes and retention. Reading the existing instance
   strength during installation was rejected after multi-second installation
   stalls. The parameter is private to this adapter and is cleared on release.
4. Instrumentation separates install, adaptation, source sync, and geometry type.
   In `install-kinds`, tick 4 costs 23.042 ms: 21.762 ms belongs to a two-surface
   batch install and only 1.143 ms to material adaptation. This identifies work
   outside adaptation instead of blaming the player's physical collision.
5. Retaining the live MultiMesh but duplicating only its mesh preserves rendered
   appearance, yet fails timing acceptance. In `live-buffer`, the four original
   p95 camera times are 7.547/7.349/7.675/5.283 ms; candidate values are
   8.475/5.072/15.981/11.965 ms. Maximum times improve, but recurring stalls remain.
   The geometry-retention invariant fails on this candidate, which is replaced.
6. Current candidate binds adapted surface materials to existing render meshes,
   without reading back either mesh or instance buffers. Resource-side native
   materials remain intact. Reference-counted mesh binding owners restore native
   materials after the last active geometry, including a freed final node.
   Unselected instances have zero fade strength. Validation is pending.

The `live-buffer` run produces 12 matched pairs. Differences are at most
0.000634 mean RGB levels (0–255), with at most 0.001544% of pixels changing by
more than 20 levels. Those near-zero differences establish appearance preservation
for that run, not proof of a lag fix or intermittent corruption repair. Frozen
terrain tint differs from the original game because live biome sampling is absent.

## Native shutdown investigation

The last two combined native runs pass all 13 tests (143, then 145 assertions)
but print a signal-11 crash on shutdown. One process returns 139. This is not a
clean pass. Suite isolation is in progress; the rendered world harness itself
exits cleanly. No issue is accepted yet.

## Reference

Godot documents GPU fetch/decompression as a possible cost of
[MultiMesh buffer reads](https://docs.godotengine.org/en/4.5/classes/class_renderingserver.html#class-renderingserver-method-multimesh-get-buffer),
and exposes material binding independently through
[mesh_surface_set_material](https://docs.godotengine.org/en/4.5/classes/class_renderingserver.html#class-renderingserver-method-mesh-surface-set-material).
The performance conclusions above come from local measurements, not the API
warning alone.

Later capture audit (issue 2): the inherited window helper read its viewport
before `frame_post_draw`. Correctly synchronized window captures and explicit
SubViewport captures remain complete. Earlier corrupted original PNGs cannot
by themselves establish a reproduction of the owner's actual visible glitch.
Camera CPU measurements and the retained native geometry assertions are separate.
