# P09: water simulation boundary

**W07 verified at the reported Moonfen site.** The broad cyan band disappears in the fresh production capture and all nine controlled timed camera pairs. W08 (a larger simulation horizon) remains open; the field dimensions have not changed.

The ripple feedback stored height and velocity around 0.5 in half-float render targets. Repeated quantization accumulated a negative height bias: after 600 frames, the decoded surface reached its −0.375 m trough clamp across much of the field. The anchored edge remained at rest, creating a broad artificial depression and a visible optical boundary. This was separate from the already feathered wave-packet envelope.

The feedback now stores signed height/velocity around zero. The water material uses the same signed decode. Resolution, domain, wave packets, shoreline clearance, water geometry and physical source generation are unchanged by this repair. Blending is explicitly disabled for the feedback pass.

## Evidence

- Original annotated reference: [P09](../references/P09-12.24.32.png).
- Fresh production: [before](../baseline/P09/P09_0.png), [after](production-after/P09_0.png). Camera reconstruction uses the rounded screenshot coordinates. Fresh startup was 259.625 seconds, not a controlled performance comparison.
- Timed replay contact sheets: [600-frame rest](timed/contact-599.jpg), [controlled immersion impulse](timed/contact-629.jpg), [moving simulation origin](timed/contact-719.jpg). Each includes 0°, −8°, +8°. All nine before views retain a broad cyan band; all nine after views have a continuous transition. Nearby waves remain visible. These are controlled inputs, not an actual-player swim test.
- [Native GPU red test](gpu-red.log): one test / two assertions fail against the original feedback. [Green test](gpu-green.log): one test / two assertions pass. Final mean drift is −0.000000326 m, largest ambient displacement about 0.0021 m after 600 feedback frames. The test decodes with the production material's own height function.
- [Focused regressions](focused-tests.log): nine tests / 70 assertions pass for current transport and the earlier wave-motion envelope.

The timed replay recreates live simulations and restores detached sampler data. Ordinary saved world snapshots do not preserve live viewport textures; the initial `isolation/` captures serve only to locate the simulation dependency and are excluded from final visual acceptance.

This does not accept underwater rendering, water-source plausibility, spill geometry, general renderer stability, larger simulation distances, or overall performance.
