# Village orbit corruption — measured repair accepted

The material/resource ownership repair from issue 1 also passes the reproduced
village corruption case. Turning the camera retains live placement buffers and
native meshes, shares adapted source materials, and keeps a bounded shader
history. This review adds no renderer switch, effect removal, or engine upgrade.

## Reproduction and judging

The original adapter fails in the editor's embedded Game view on Godot 4.5.1,
Metal Forward+, Apple M1 Pro. Two fresh GPU frames at the recorded orbit poses
contain 7,762 and 6,606 black samples out of 9,216. The second also contains
2,598 nonfinite RGB samples. Independent scene markers match both actual camera
poses. The native Game window subsequently becomes black while its toolbar
remains visible; later stale alternating buffers are excluded.

The current adapter completes **4,682 marked embedded frames in two runs** with
zero nonfinite RGB, no stale markers and at most one black sample per frame.
At both exact failure poses, black and nonfinite counts are zero. The full
current viewport images are also visually clear. An earlier standalone current
run supplies another 7,201 clean GPU observations, without the later marker.
The issue-1 adapter with the original small bubble separately completed 3,601
clean GPU observations, so the larger circle alone is not the tested repair.

[Failure-pose comparisons](embedded-failure-pairs.png) and
[numeric differences](embedded-failure-pairs.json) preserve the two pairs.
Their finite HDR-preview mean RGB differences are 16.047 and 18.358/255;
53.082% and 60.335% of finite preview pixels change over 20 levels. Magenta
denotes invalid diagnostic values and is excluded from those colour metrics.
These low-resolution HDR previews are not final game colour screenshots.

## Photo angles and preservation

Twelve newly rendered pairs cover all four screenshot pins and +/-8-degree
alternatives. Each pair shares the exact reconstructed transform recorded in
`photo-pairs/poses.json`. The supplied overlays round positions to 0.1 m, so the
original full-precision camera cannot be recovered. The frozen full village
contains 170 lights, 49 fog volumes and the actual native geometry; its frozen
lighting state is consistent within each pair.

All 24 images are valid and judged, along with their pixel differences:
[original angles](photo-pairs/contact-0.jpg),
[-8 degrees](photo-pairs/contact--8.jpg),
[+8 degrees](photo-pairs/contact-8.jpg).
Mean RGB differences range from 0.515 to 10.314/255; 0.980–18.365% of pixels
change over 20 levels. The changes follow the accepted larger visibility bubble;
native silhouettes and surfaces remain intact. Static original poses do not
reproduce the intermittent black-screen failure.

The focused native run passes **13 tests / 143 assertions**, exit 0, including
shared source/buffer ownership, independent fades, restoration, and actual
rendered pixels. The marker calibration separately checks 60 alternating GPU
states and nine boundary tags. `september11_black_gate.py` rejects both saved
fresh corrupt frames and accepts both completed marked current replays.

## Limits and rejected explanations

The original adapter can also complete clean runs. This acceptance covers the
reproduced failure and measured repaired routes; it is not a universal GPU
stability claim. The precise underlying driver fault remains unproven.
Upstream Metal residency, clustered-light and fog-history defects were plausible
leads, but no local experiment justified changing the renderer or removing
effects. A late-discard shader candidate was not adopted because the current
adapter already passed and no failing current case established its benefit.
Earlier stale readbacks, interrupted runs and argument-selection mistakes are
explicitly excluded in [iterations](iterations.md).

The temporary owned editor and QA plugin are closed/removed. Original
`project.godot` bytes are restored; validation.json records their checksum.
