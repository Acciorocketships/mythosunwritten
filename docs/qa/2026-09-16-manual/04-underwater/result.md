# Underwater state at P01 — scoped evidence

P01's actual water sampler reports a surface near y=15 over the photographed feet at y=8, but the steep mixed tile has zero swim triggers. The previous character remained in dry movement.

Committed water surfaces now expose their sampler independently of swim-area construction. Character immersion uses that finite committed coverage to apply water drag/current and bounded sinking where the old area is absent. Camera immersion is independent of character state. `UnderwaterView` adds a depth-based tinted medium and restores the exact original camera environment on exit.

Judged final native replay: `replay6/after/P01` and `replay6/after/P10`, paired with the corresponding `replay6/before` views, three angles each, summarized in `judgment-P01.jpg` and `judgment-P10.jpg`. P01 gains coherent underwater distance attenuation including the far background; the dry P10 control retains its appearance. Pixel identity is not claimed because particles/render history differ. Earlier native-fog-only replays left the sky bright and were rejected; replay2 failed parsing and the background diagnostic is excluded.

The native two-second movement fixture changes from approximately 19.95 m of dry lateral travel to movement affected by drag and current; submerged idle acquires current drift. Raw starts/ends and state flags are in `replay6/motion.json`. Native-area swimming remains a separate state; the new steep-column immersion path does not create buoyant elevators up waterfalls.

Tests cover P01's actual sampler, entry/exit hysteresis, camera/character independence and exact environment restoration. The final 28-test / 5,318-assertion run is `../focused-final.log`; its cliff assertions do not accept the later owner-rejected art. The wrong-name `green-final.log` command is excluded.

This is site-level rendering/movement evidence. A fresh complete-world capture used the committed sampler registration before the final depth overlay revision; the final overlay is verified in native frozen production replay. General swimming, all shoreline transitions and water topology are not accepted here.
