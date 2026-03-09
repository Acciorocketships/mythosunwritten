# Level guaranteed-fill rule

**Goal:** Add a rule: if a level tile can be placed and it has ≥3 neighbours (in cardinal directions) that are also level tiles, then placement is guaranteed.

- New rule (or extend existing level rule): before normal sampling, detect when the expansion socket’s cardinal neighbours include ≥3 level tiles.
- In that case, force placement of a level tile (skip sparsity roll / guarantee fill) for that socket.
- Cardinal directions: front, back, left, right (same as used elsewhere for level edge logic).
