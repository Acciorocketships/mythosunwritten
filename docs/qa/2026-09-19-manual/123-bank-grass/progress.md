# Bank grass investigation — incomplete

The narrow control and the broader thin-ledge profile both finished. Neither
produced additional grass in the four N04 tiles: before/after counts remain
76/76, 79/79, 214/214 and 134/134. Both retain identical whole/split buffers and
zero out-of-window queries. These are negative results, not bank-grass acceptance.

The narrow-control audit found no exposed usable ledge in the local set; the
wider bank audit found no exposed cap with enough edge clearance for the existing
grass patches. The broader profile uses `0.2 * exposure + 0.8 * (1-exp(-exposure))`
with the existing depth cap. It also failed the positive new-instance gate.
Current top-level payloads are that broader trial; `narrow-control/` retains the
earlier outputs. Neither profile has been promoted to production.

The height-aware GrassField water-support change has focused test evidence but
still lacks a positive native bank-grass verification. The native replay now
completed with five angle pairs and a profile pair. It contains zero new grass
roots, which is not attachment proof. The broader profile is rejected visually:
it smooths the submerged bank without producing useful exposed ledges. A replay
parse error (`o` needed an explicit integer type) was corrected before this run.
The broader trial's log is `/tmp/bank123-broader.log`; its process finished with
exit code 1 at the positive-instance gate, without outside queries or buffer
mismatches. No trial process remains active.
