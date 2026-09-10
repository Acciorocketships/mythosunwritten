# Photo 10: open roof end

The accepted issues 1–10 are frozen in `/private/tmp/september9-seams-baseline`.
Photo 10 shows the end of house.003's lower continuous orange roof. Its finite
flush section clips the source at z=1.5; the native plaster gable is at z=1.568
(and z=-1.566 on the other end). The clipping therefore removes the wall while
retaining some timber frame. Original native planes have 2.2 square metres of
projected gable surface each, so this is missing geometry, not a texture filter.

Options: synthesize a flat cut cap, transfer the native end wall, or fit the
complete native end section into the reserved shorter length. The last option
preserves its complete plaster, timber, roof edge and UVs with the existing
offline `fit_visual_bounds` operation. The inner seam stays at +/-0.75; the
outer end fits +/-1.5. Only the longitudinal coordinate changes. Full original
height and transverse section remain, avoiding a new seam at the middle roof.
Both colors, ends and ordinary/tight widths require the same treatment. Public
clearance and actual native triangle coverage must pass before acceptance.

The native-triangle regression fails at all 72 gable samples before the bake
(1 test, 72 failing assertions). The fitted bake passes those samples for all
eight assets. A second test compares complete source/result triangle streams:
X/Y, UVs and triangle count are preserved, and Z follows the declared fit.
Both targeted tests pass (55,048 assertions, 2.714 seconds, exit 0). The related
roof reservation/topology/profile suite passes 25 tests / 55,200 assertions in
114.133 seconds, exit 0. Its first test is the earlier one-test version of the
targeted file; the channel comparison was run separately afterward.

The physical census remains identical to the accepted photo-14 construction:
132 walk cells and 188 crossings, all central-clear. The flush ends preserve
the original full native height (their old clipped versions lost the ridge
end detail), and retain the same shorter longitudinal boundary. Source profiles
and physical clearances pass with this complete measured height. No runtime
repair, retry, visual-only hole patch or additional decorative geometry is used.
After-render judgment is pending.
