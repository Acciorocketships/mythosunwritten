# Camera blur — accepted

The director no longer assigns depth-of-field attributes. Both the foreground blur and distant tilt-shift blur are removed until the camera redesign. Bloom remains enabled, so luminous orbs retain their soft glow.

The existing director regression fails before on the old blur attributes and passes after: two tests, 12 assertions, 0.373 seconds, exit 0. All three matched game replays were visually inspected: the close tree limb and distant buildings/treetops are sharp; the orb halo remains soft. Camera and orb positions are identical. Mean RGB differences are 0.0870, 0.4894 and 0.2591/255; the differences follow the formerly blurred edges rather than a changed camera or scene.

[Near branch](diff/pinned_00_comparison.png) · [Distant trees](diff/near_orb_00_comparison.png) · [Town view](diff/second_orb_00_comparison.png) · [Verification](verification.json)

Both replays exit 0. The frozen-world fixture retains the three known AnimationPlayer instantiation path errors and teardown warnings disclosed in issue 13; it isolates the camera effect and does not revalidate old fixture geometry.
