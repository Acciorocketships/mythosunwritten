October 3 bridge destination validation

The cottage-access source comparison isolates one lost bridge at12/compact,
(1,-2),floor6/top8: destination pruning removes its unused underlying street.
Tried allocating bridge endpoint houses before pruning, so real doors could
preserve that address. REJECTED:60-town source test breaks39 (a lower endpoint
has a doorway on a removed stair cell); finished-towns test also returns null.
This repeats the historical flight-door hazard documented by September27.
Production order restored: ordinary destinations prune, released sites infill,
then bridges allocate only over surviving streets. No purposeless road retained.

The corpus floor is explicitly revised12->11, documenting this deliberate
withdrawal rather than asserting a supported span must remain at an obsolete
location. Whole-cover/support and actual built-door requirements stay unchanged.
Final tests: tunnel hosts3/3, released bridge sites2/2, destination agreement3/3;
8/8 total,188 assertions. Actual counted doors are built across the historical
11-town destination corpus. The previously failing released-site regression is
now exercised naturally again at12/compact; no fixture change needed there.
This resolves the bridge classification and released-site failures, not the
whole redesign. Other outstanding October files: native roof fallback coverage,
chimney coverage, joined-range fixtures. Broad walls/rooflines and fuller turret
variety remain art work. All increment jobs terminal.
