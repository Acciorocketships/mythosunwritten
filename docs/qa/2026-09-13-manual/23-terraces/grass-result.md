# Exposed native terrace grass

The ordinary grass sampler previously knew only the underlying heightfield.
It now receives detached flat top triangles from accepted native ledges through
the existing terrain-to-grass worker handoff. The same biome, habitat, patch
assets, edge density and streaming rules apply. Actual native triangle edges
contain each patch; rocks reserve their footprint and higher ground hides the
buried part of a cap. The existing halo provides caps that cross grass tile
ownership boundaries. Ordinary ground retains its original layer eligibility.

The corrected baseline fixture produces 2,980 ordinary grass patches and zero
ledge roots. The candidate produces 2,998 patches, including 28 ledge roots.
Independent ray tests against actual native mesh triangles verify every new
root and sixteen footprint directions per patch. Four split chunk controls
retain identical buffers. Mutating a detached worker copy leaves the committed
terrain inputs unchanged. All 29 related tests pass 594 assertions in 16.146 s.

Five matched views in `grass-pairs.png` compare the original terrain-only
sampler with the candidate at P18's reconstructed angle, +/-8 degrees, a side
view and an overview. Ordinary ground grass is present in both. The broad
ledge gains matching grass while the rock footprint stays clear.

Three fresh game views in `live-after/P18` verify the real terrain and visual
workers. Fifteen inspected local grass tiles contain 140 roots on native caps;
`grass-worker.json` records their coordinates and owners. Startup takes
357.842 s; the final local grass wait takes 56 ms. No startup or general
performance improvement is claimed. Snapshot uniform enumeration emits the
existing editor-only diagnostic; the three captured game frames are valid.

## Excluded controls and limits

The first fixture and `before/P18` render used a zero shoreline-distance limit,
which rejected all grass, including ordinary ground. They are excluded. The
valid red run is `grass-valid-red.log`; valid native before views are under
`ground-before/P18`. The game frames retain the existing biome lighting; the
isolated native pairs use a fixed inspection light and do not measure lighting.

This change does not repair ledge projection, broad cliff composition, jumping
under native turf overhangs, or water. Those issues remain separately tracked.
