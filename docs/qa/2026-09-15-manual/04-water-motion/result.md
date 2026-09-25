# P12 — current-wave distance and transition

Status: **accepted for the reported short-distance seam**. All 26 tests / 150 assertions, fifteen judged timed view pairs and the GPU controls pass.

The current-wave field now covers 192 m rather than 96 m. Full amplitude reaches the old 48 m boundary, followed by a circular 42 m transition to zero at 90 m. The 6 m outer margin keeps this envelope inside the snapped texture, including lattice crossings. Nearby swimmer ripples retain their original 96 m domain, 256² resolution and 3 m current sampling.

## Diagnosis and alternatives

The reported view's current wavelets were clipped to a player-centred square with only a 9.6 m edge fade. Increasing the entire interaction simulation would also multiply current-field sampling or coarsen the readable entry rings. Adding an unrelated scrolling distant texture would separate the visible current from its physical wave height. The selected change enlarges only the existing transported packet field, using the same frozen native currents.

The packet field retains eight samples across its shortest 6 m wavelength. Capacity grows from 16 to 64 over four times the area, with an additional local admission cap to avoid crowding a small wet pocket. Failed wet/current/density placement retries wait 0.7 s rather than retrying every two frames. Wave amplitude and the shared 0.48 m packet-height bound are unchanged. The CPU buoyancy query now applies the same envelope as the material; previously packets outside the rendered texture could still displace a floating body.

## Evidence

- The original code fails two focused checks: insufficient current coverage and nonzero buoyancy outside the displayed packet domain. See [red.log](red.log). The first parse-invalid test invocation is excluded.
- [Native geometry and current snapshots](native/) come from a fresh production load at seed 2697992464, P12 feet `(-98.3,4,-1221)`, crosshair `(-97.2,4,-1224.4)`. Five frozen native samplers are retained alongside the saved world; no current field is invented for the photo replay.
- [Final paired replay](final-paired/) contains fifteen judged before/after pairs: the reconstructed photo azimuth and ±8°, at ticks 300, 360, 419, 450 and 540. The last two move the actual simulation centre sideways by 3 m and 12 m while keeping the viewing camera fixed. [Pose records](final-paired/poses.json) match exactly between phases. The source overlay is rounded, so the reconstruction is not a recovered original camera transform.
- Three water-region sheets expose all fifteen comparisons: [photo](final-paired/review-0.png), [left](final-paired/review--8.png), [right](final-paired/review-8.png). The current continues through the formerly quiet outer region without a nearby rectangular cutoff. Ground, banks and scenery stay intact. Full images and absolute pixel differences are retained. Changed pixels above the comparison threshold occupy 0.1685–0.7383% of each full image; this localizes the edit rather than independently proving correctness.
- The [GPU controls](controls/results.json) compare rest, water entry, wake propagation and moving-domain shifts at six times. All six ripple height images are exactly identical. A separate actual-shader envelope render matches the CPU envelope at 4,761 positions with maximum error 0.0004881 (half-float render precision). [Envelope image](controls/circular-envelope.png). An initial control with incomplete diagnostic arrays is excluded; the corrected run is clean.
- Unit controls cover the wider circular fade, continuity through a texture snap, still water remaining packet-free, far-current seeding, unchanged ripple resolution, and bounded retries. Existing refraction, compact-wavelet, shallow-turf trough and water classification controls are included in [test-config.json](test-config.json).

## Cost and limits

The final photo replay measures simulation CPU mean 0.993 → 2.039 ms, p95 8.393 → 8.878 ms. This is additional work for expanded coverage, not a performance improvement or global frame-time acceptance. Metal's per-viewport GPU timer returned zero and is unavailable here; zero is not a measured GPU cost. The separate controlled current fixture also passes its rendering checks, but its timings overlap another graphical run and are not credited as an isolated benchmark.

The current field remains finite and fades at longer range. The ambient spectrum, stationary water, local interaction simulation, terrain, static water levels, mesh topology and bank displacement budget are unchanged. These checks address P12's short-distance current seam; the cliff-drop flow defect and other water geometry reports remain separate open issues.

Test invocation uses the existing `tests/harness/september15_gut.gd` entry point, which registers the declared native terrace material UIDs without suppressing diagnostics. Two direct-addon runs passed all functional geometry checks but were marked failed for the known missing UID cache entries; a broad editor scan did not populate those baked-asset entries. Neither run is credited as a clean test pass.
