# Public masonry family, October 4

The final public-wall substitution still used Suntail house-footing stone for legacy public retaining panels. This created a blue rectangular patch beside Pure Village's cream citadel masonry in 103/grand, even though the main wall generator already used Pure Village. The final payload diagnostic identifies four coplanar contact pairs at `retaining-wall/-6/3/4/...`; checking only the kit's intermediate wall placements missed these late additions.

`KitSubstitution` now maps both public retaining-panel IDs (`sfv.fabric.wall.rock.plain.001` and `sfv.fabric.wall.rock.retaining.001`) to the existing `wall.stone.retaining_half` role. This is the native Pure Village half course used elsewhere in the retaining wall. The measured fitting preserves the complete accepted envelope, including the contact under the walking floor. Individual houses retain their own masonry and footing families. No layout/seed-specific rule or new texture was introduced.

## Evidence

- New regression checks both substitutions, exact aggregate envelope preservation and the independent Suntail house-footing role: seven assertions pass.
- The September 29 material suite passes four of five tests. Its remaining test reports the same 11 grass/miter-piece assertions with the previous mapping and this mapping. The before/after logs are saved; no overall green-suite claim.
- Final native 103/grand face view inspected against the same camera before the change: the blue patch immediately beside the ascending stair is now cream native masonry matching the surrounding wall.
- Final actual-character ascent and descent of the 103/grand gate both pass. The native support mesh changed, so bounds checks alone were not used as traversal acceptance.

## Remaining

This fixes one late public-masonry inconsistency, not all material composition. The upper house fronts still include abrupt transitions between structural sections and different families, and the skyline retains oversized roofs and tall repeated facades. The full redesign goal remains active. The diagnostic also finds separate Suntail house plinths touching Pure retaining walls; those contacts are not modified in this pass.
