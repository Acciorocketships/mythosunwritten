# District-matched masonry corner joints — pass 91

P02's exposed retaining-wall joints used scaled timber posts, creating conspicuous brown vertical strips between stone faces. Pure retaining contacts now use the existing native retaining-stone asset, fitted to the same intended joint envelope and tinted by the retaining district. Contacts involving inhabited rooms retain their timber members. Joint admission, stable IDs and surrounding construction remain unchanged.

The native stone is gray. The earlier pass-84 stone trial looked white because it omitted the district tint. This pass's first prototype used the global world seed and acquired an olive tint; it is also rejected. The final production call uses the construction's actual seed, 6667864705524842848, consistently with adjoining masonry.

## Native judgment

Four matched views show the final rebuilt production payload. The broad brown strips are replaced with blue-gray masonry, consistent with neighboring faces. The stone retains native chipped edge detail. Mixed room contacts and ordinary timber framing remain visible and intentional. The reported camera clips the top of the isolated town; front, side and overhead views establish the complete local context.

[Before front](native/before-front.png) · [After front](native/after-front.png) · [After overhead](native/after-overhead.png) · [After side](native/after-side.png).

These are actual compiled production instances in an isolated native-rendered town. They do not contain surrounding terrain or path paint, and do not close P02's separate raised-block/path-corner issues or all original T05 reports.

## Verification

- Red-first pure-stone selection fails on the saved original assembler. Final focused regression: **13 tests / 93 assertions pass**, including mixed-room timber preservation, native bounds/pivot fitting, district tint, insertion-order independence, existing joint occupancy cases and the pass-84 buried-soffit repair.
- The rebuilt frozen P02 source retains **313 instances**. Exactly **nine** stable joint IDs change asset, pose and tint. No instance is added or removed. All other instance records, walked cells, generated surface payloads and explicit collision boxes are identical. The exploratory skin-only substitution changed twelve; production correctly includes inhabited-room volume and preserves three additional timber contacts.
- Native collision shapes for all nine changed joints are exercised at five heights, three lateral offsets and four directions. **540 rays before and 540 after hit their intended bodies**, with zero misses. This establishes sampled joint closure, not player traversal or global public-space clearance. The nine native collision assets change; unchanged explicit boxes do not mean all collision is identical.
- Four before/after native render pairs complete. Two pre-existing village material UID warnings resolve through their valid text paths. No new material failure is observed.

[Payload difference](payloads/difference.json) · [Native collision probes](payloads/physics.json) · [Production change](masonry-joints.patch).

The first regression command named a nonexistent soffit test and is excluded as a full gate; the corrected final command runs all three intended files. The first difference check expected twelve prototype changes and failed; the production room-volume policy explains the actual nine, verified in the final check. No fresh-world startup, global performance, whole-town traversal or full-suite acceptance is claimed.
