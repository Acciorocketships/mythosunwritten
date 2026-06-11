# Level guaranteed-fill rule

**Status: IMPLEMENTED** as `ClusterFillRule` (`scripts/terrain/rules/ClusterFillRule.gd`).

When a placed cliff/level tile leaves an empty cardinal position that already
has >=2 same-family neighbours at the same height, the rule pushes that
position's expansion socket directly onto the queue (skipping the sparsity
roll). Notches and 1-wide slots always fill, so clusters convexify into chunky
plateaus that can host interior tiles — which is what enables vertical
stacking into terraced hills and multi-storey cliff mountains.

Differences from the original sketch:
- Threshold is >=2 neighbours (not >=3): with >=3 a snake-shaped cluster never
  develops an interior, because no empty cell ever has 3 neighbours.
- Applies to both `level` and `cliff` families with the same logic.
- Growth stays bounded because a fill needs two pre-existing neighbours — the
  rule thickens a cluster within its extent, never extends it.
