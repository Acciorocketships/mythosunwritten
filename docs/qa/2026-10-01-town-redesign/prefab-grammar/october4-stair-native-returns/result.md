# Native stair landing returns

Native rendering rejected the initial short-return treatment: scaling a complete
Suntail railing onto the 0.6 world-metre shoulder crowded and flattened its posts.
The return now uses two existing Suntail `beam.floor` members and one `rail.post`.
The long flight owns the attachment post. The outer post retains the normal
railing's width instead of shrinking with the return span.

The first beam trial put its upper member above the post head. Measuring the
actual Wooden_Railings_1 mesh showed why: its cross members occupy native
Y=.471..533 and .799..862, while the post head reaches .938. These source-specific
connection dimensions now place the two return members at the native rail's
joints. No new texture or mesh asset was invented. The source dimensions apply
only to that asset; other rail assets retain the generic height fallback.

`landing_return` metadata distinguishes these short connections from ordinary
flight spans. The existing collision and floor geometry remain unchanged.
The default production caller still selects zero inset, so this remains a
construction capability awaiting profile admission.

## Verification

- Inspected native lower, upper and whole-flight views before, during and after
  the change. The final members meet below the post heads at the native rail
  heights; the doubled compressed post treatment is gone.
- Four profile/return tests, 721 assertions pass. They include exact physical
  floor widths, lane support, shoulder collision, direct/deferred guard parity,
  and three return lengths retaining one constant-width outer post.
- Combined material/profile check: 8/9 tests pass, 4,955/4,963 assertions.
  The eight failures match the previous renderer exactly (verified by temporarily
  restoring the prior renderer, running the failing test, then restoring the
  current file). Three concern `sfv.fabric.wall.rock.plain.002.miter3`; five
  concern KayKit grass assets. The broad material suite is not green.
- The isolated render uses the production cache/commit queue and kit timber
  substitution. Its ground-level test platform coincides with the background
  plane, producing a bottom-edge ground artifact; that is not evidence about
  production terrain. The upper return provides the unobscured joint view.

## Remaining work

Production profile selection and actual-player checks remain. Surface construction
occurs before `SettlementFabricPlan.set_surface_plan`; that is the appropriate
transaction boundary. The final surface cannot simply be replaced afterward:
its claims, guards and caches are already sealed. Generic fabric roof occupancy
and later native kit roof geometry differ, so any admission rule needs a final
native clearance check on representative and holdout towns. The compact-town
roof regression and overall redesign are still open.
