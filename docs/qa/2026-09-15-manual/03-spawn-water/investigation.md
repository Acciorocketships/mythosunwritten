# Spawn water cutoff — investigation, not accepted

Reference: P11, September 15 at 9:44:34 AM, seed 2697992464,
player (6.7, 0, -6.4), crosshair (7.1, 1.2, -6.5).

The fresh original-code regression still fails all five ownership checks:
20/25 assertions pass in 124.718 seconds (`/tmp/september15-origin-red.log`).
Three contexts retain water at 7.9499998 m while (0,-1) is dry.

The older investigation correctly found different source domains and an
artificial outlet at z=12, but attributed the dry result too early to that
outlet. A fresh pre-cap probe finds **the origin is already dry before the
spill cap** in the smaller domain. There are also zero non-anchor wet samples
on its perimeter. Enlarging until the wet perimeter disappears is therefore
not a solution to this reproduction.

The connectivity probe confirms the larger domain admits a **31 m** initial
head at the origin. Its physical spill is **8 m**. After containment, the
**7.9499998 m** pool contains **12,561 connected samples and zero actual seed
samples**. Expanding the diagnostic domain north repeats those exact values.
The temporary high flood crossed a sill that containment subsequently dries.
The remaining pool is not supplied by any real river or pond.

The candidate captures the actual offered river/pond seeds before relaxation.
After spill containment it keeps only wet components containing surviving
seeds. This occurs before smoothing and fine rescue: genuine finer passages
can still resupply pockets from retained water. Dry bank constraints and
disconnected flood labels never count as sources. No source-domain enlargement,
terrain change, special spawn exclusion, or renderer mask is added.

The initial source-connectivity tests fail three substantive invariants on
the original behavior; the candidate passes all five tests / 11 assertions,
including fine-passage resupply. The original five-position ownership test
passes after the repair (15 assertions; dry points require no level comparison).
A wider 81-point/four-owner dry-field check also passes in the ongoing
regression run. Matched rendering and broader controls are still pending;
the candidate is not yet visually accepted.

The first standalone domain probe omitted the water plan from its source
dictionary and logged script errors. Its JSON is explicitly named
`invalid-missing-context-domain-probe.json`; none of its values are evidence.
The corrected probe and subsequent connectivity probe use the complete context.
The first connectivity probe encountered a typed-array initialization error;
`/tmp/september15-domain-connectivity-fixed.log` is the complete valid run.

Final status: subsequent matched rendering and all 51 focused tests passed. See [result.md](result.md) for the nine judged pairs, four-owner dry-field scan and acceptance limits.
