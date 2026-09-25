# Close cliff face investigation — rejected studies

No production geometry or material changed in this pass. Six isolated studies fail to resolve the owner's remaining smooth-face concern sufficiently, or expose unwanted angular patches. They remain fixtures, not accepted fixes. The selected production remains [13-cliff-scale](../13-cliff-scale/result.md); C01/C02 and overall cliff art remain open.

## Matched evidence

All six studies captured the same seventeen frozen amber views using `september16_cliff_transition_context.tscn`, seed 2697992464, both straight and corner generators, and the saved P05/P12/P17/P20 ReviewCam-derived poses. The original world, lighting, terrain and grass are held fixed; geometry studies rebuild crevice plants from the changed stone. Representative close, corner and wide views were inspected to reject candidates early; not all 102 captures were judged. No fresh world, traversal or performance claim is made.

| Study | Mechanism | Judgment |
|---|---|---|
| [Shallow scars](candidate/P12_reported_0.png) | Finite asymmetric shallow recesses with a chipped upper lip | Adds local marks, but the broad close face still looks soft. P17/P20 do not justify promoting this extra complexity. |
| [Stronger material](weathered/P12_reported_0.png) | Stronger existing grain, fracture bevel and restrained albedo variation; geometry unchanged | More mottling, insufficient improvement in rock form. Rejected. |
| [Narrow mass bevel](narrow-bevel/P12_reported_0.png) | Reduce broad mass transition from 0.30 to 0.14 of its radius | Harder projecting slabs and unwanted angular ledge corners; the central soft face remains. Rejected. |
| [Faceted small detail](faceted-detail/P12_reported_0.png) | Mostly linear rather than cubic interpolation for small geometric detail | Subtle angular marks without enough improvement to the broad form. Rejected. |
| [Narrow geometry and shading transition](thin-transition/P12_reported_0.png) | Confine native relief, suppressed detail and native normal borrowing closer to contact | Reveals stronger cuts, but introduces conspicuous notches and angular transitions. Rejected. |
| [Shading transition only](shading-transition/P12_reported_0.png) | Complete independent shading at 0.9 m thickness instead of 1.8 m; actual geometry unchanged | Restores some real surface detail, but [P12 +8](shading-transition/P12_reported_8.png) and [P17 +8](shading-transition/P17_reported_8.png) expose angular patches. Still fails the desired close appearance. Rejected as a blanket fix. |

Compare with the unchanged [P12 baseline](../13-cliff-scale/original-context/P12_reported_0.png), [P17 baseline](../13-cliff-scale/original-context/P17_reported_0.png), and [P20 baseline](../13-cliff-scale/original-context/P20_oblique.png). The next geometry study should address broad face structure and transitions together, rather than accumulating small marks or globally narrowing every bevel. Native shading masks some angular geometry, so withdrawing it alone is not a sufficient repair.

## Measurements and their limits

The initial physical-pocket diagnostic sampled four actual photo formations. Baseline already has **360/4,440** qualifying small concavities (8.11%) and passes all three checks. The shallow-scar candidate has **396/4,335** (9.13%), also passing. The sample population changes with actual geometry. This is **not red evidence**, and the increased count does not establish better art. The log is named `pocket-baseline.log`, and the diagnostic lives under fixtures as `pocket_probe.gd` rather than becoming a production acceptance test.

The separate blend-extent hypothesis reproduces **27,349** vertices at least 0.9 m beyond the native surface that still borrow native shading. Its proposed 0.9 m cutoff fails on baseline (`blend-red.log`) and passes all four checks for the shading-only fixture (`blend-candidate-tests.log`), while preserving zero independent shading within the first 8 cm. However, the matched images reject the candidate. Consequently `blend_probe.gd` is also an experimental fixture, not a new failing requirement in the production suite. Passing that measurement must not be used to accept this appearance.

Production straight generator SHA-256 remains `48ed73583573efdf4d4fce30d4dab6ec2c90060b468f5e9053fb52cbca186b8a`, identical to `before.gd`. Production shader remains `f91a0a3088f8790d45030665824aa055e74a97b00d21f3f30fb8bbcc83859d8a`, identical to `before.gdshader`. The production corner adapter was not edited. Existing dirty worktree changes are preserved.

## Reproduce

Fixtures are under `tests/fixtures/september17/cliff-spalls/`. To reproduce a geometry study, select its straight and corresponding corner fixture:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/ryko/story --log-file /tmp/cliff-study.log tests/harness/september16_cliff_transition_context.tscn -- --corner-study --generator=res://tests/fixtures/september17/cliff-spalls/shading-transition.gd --corner-generator=res://tests/fixtures/september17/cliff-spalls/corner-shading-transition.gd --output=res://OUTPUT
STORY_BLEND_GENERATOR=res://tests/fixtures/september17/cliff-spalls/shading-transition.gd /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story --log-file /tmp/cliff-blend-probe.log --script addons/gut/gut_cmdln.gd -gtest=res://tests/fixtures/september17/cliff-spalls/blend_probe.gd -gexit
```

For the material-only study omit both generator arguments and use `--stone-shader=res://tests/fixtures/september17/cliff-spalls/weathered.gdshader`. Omitting the blend diagnostic environment variable reproduces its baseline hypothesis failure. The study has not repaired other original judging issues.
