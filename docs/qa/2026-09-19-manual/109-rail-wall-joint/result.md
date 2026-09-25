# P04 upper-floor rail joint

The sloping guard now meets the underside of the actual house floor without crossing its fascia. Newly clipped handrail ends receive a post seated on their own stair flight. Houses, treads, doors and floor placement remain unchanged.

## Evidence

- Three rail/floor intersections reproduce red before floor clipping. A second red test rejects the initially unsupported cut end. The final focused run passes 14 tests / 121 assertions; the additional four-orientation support control passes 12 assertions. Combined distinct coverage is 15 tests / 133 assertions.
- Complete native, box and generated-triangle physics changes all three reported rail hits to the native floor, and adds the expected post contact. The eleven P15 roof-side rail contacts remain present. All 312 fixed-height stance and 444 crossing classifications are unchanged. As in pass 108, many of these contact generated floors; this is a regression comparison, not a claim of universally clear routes.
- Six actual character walks in the freshly generated world pass, up/down at three lateral positions. Every walk completes in 128 movement ticks. The three uphill endpoint images show the character on its landing; all three downhill endpoint images are occluded by the adjacent house, so those images are excluded as independent visual passage evidence. The logged final positions and successful movement traces are retained in `fresh/walks.json`.
- All six saved P04/P15 camera poses were inspected in the grass-enabled fresh world, plus the matching native poses and P04 close-up before/after. The floor fascia is clear, the exposed rail has support, the doorway stays clear and the prior P15 repair remains intact.
- All 48 towns across four scales seal. Native construction checks retain 11,772 clear centres and 16,915 crossings, the same 25 conservative offset pillar candidates, zero centre/gate blocks and zero measured intrusion. The fingerprint gate passes 1 test / 95 assertions. This broad corpus does not test every generated guard surface independently.
- Only generated meshes 90 and 94 of 101 change in the photographed town. Native batches and generated collision boxes are identical.

Fresh startup takes 638.870 seconds during concurrent validation; no performance acceptance is claimed. Known material UID fallbacks and the snapshot helper's editor-only shader query warning remain. Broader bridge traversal (T09), cliff art, water, streaming, town appearance and biome variation remain open.

See [diagnosis](diagnosis.md), [patch](production.patch), [physics](complete-collision.json), [walks](fresh/walks.json), [source comparison](after/source-comparison.json), [before](native/P04_termination.png), [after](after/native/P04_termination.png), and [fresh P04](fresh/P04/P04_0.png).
