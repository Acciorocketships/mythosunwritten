# Cliff riser correction

## Diagnostic: strong-body prototype, still unshipped

Fixed triangle direction produces tooth-like folds:

![Rejected prototype before](../58-cliff-layered-bodies/bearing-world/P12_front.png)

Choosing diagonals from local curvature removes most of the repeated teeth at the same density. This body design is still rejected:

![Corrected prototype diagnostic](diagonal-world/P12_front.png)

Simply doubling mesh density makes more teeth and is rejected:

![Rejected finer sampling](fine-world/P12_front.png)

## Actual production, matched P20 view

Before:

![Production before](../55-cliff-basal-rocks/spaced-world/P20_oblique.png)

After the isolated triangulation correction:

![Production after](production-world/P20_oblique.png)

The overall shape is retained. Broad plain faces remain an open art problem.

## Tall production control

Before:

![Tall before](../56-cliff-face-relief/before-tall/oblique.png)

After:

![Tall after](production-tall/oblique.png)

Upright supports remain too prominent; this is not acceptance of the tall composition.

## Mapped corner control

![Corner before](corner-before/P12_side.png)

![Corner after](corner-after/P12_side.png)

Game views are frozen-context replays. See [results](result.md) for the red-first test, preservation checks, rejected hypotheses and validation limits.
