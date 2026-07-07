# MythosUnwritten — Master Design Reference

A living reference for the game's vision and mechanics. Built on the current Godot project. Not a single implementation plan — see *§17 Decomposition*.

## Status legend

Each non-obvious claim is tagged:

- **[DECIDED]** — settled, or fixed by the existing codebase.
- **[OPEN]** — a real design decision still to be made; options recorded.
- **[REACH]** — desirable, but explicitly deferred until the core works.

---

## 1. Vision

An open-ended, turn-based fantasy RPG that is really a **world simulator with no pre-written story**. The player is one character among many in a living world. Every other character is driven by an LLM; the world itself is driven by an **orchestrator agent**. The orchestrator continuously tries to seed interesting narratives through the interplay of characters and events — but nothing is scripted. What actually happens is emergent; the multi-agent simulation has to unfold to be seen.

Vibe: **cute fantasy.**

The design bet: implement only the *mechanics of the world* (atomic actions, simple combat rules, item effects, sentiment) and let complex narratives and strategies emerge from agent interaction — the way chess's simple piece rules beget infinite strategic depth.

---

## 2. Design principles

1. **Open-ended.** No hard-coded story, no intended solution path. Mechanics, not narratives, are implemented. Every playthrough differs; creativity is a valid tool.
2. **Complexity from simple rules.** Seed characters with backstories and atomic actions; let interaction produce the complexity.
3. **No preferential treatment.** NPCs use the *same* implementation interface as the player — same inventory, same action set, same combat rules. The only difference: an NPC's decision function is an LLM; the player's is a human. This simplifies implementation *and* keeps multiplayer balanced. **[DECIDED]**
4. **Emergent strategy & non-transitivity.** Strive for a rock-paper-scissors strategy space: no single dominant approach. An aggressive military push should beat one thing and lose to another (e.g. diplomacy, or a defensive chess formation). Like chess: simple moves, deep strategy. **[DECIDED — guiding constraint]**
5. **Progression that never saturates.** Avoid both failure modes: (a) the Pokémon/Minecraft wall where the player becomes too strong and loses interest, and (b) the Garry's-Mod sandbox with no driving goal. The answer is *territory conquering on an infinite procedural map with a distance-based difficulty gradient* (see §7–§8). **[DECIDED]**
6. **Headless mode.** The game must run without visuals, for vastly easier debugging and for fast simulation/testing. **[DECIDED — core engineering requirement]**

---

## 3. World & simulation model

- **Real-time overworld, turn-based combat.** Movement and interaction in the world happen in continuous real time (Baldur's-Gate-style). The instant combat begins (someone attacks someone), the **local area snaps into turn-based mode** and onto a tactical grid (see §5.2); when combat resolves, the area returns to real time. **[DECIDED]**
- **LLM-driven agents run asynchronously.** The physics/world sim never blocks on an LLM. Agents "think" in the background; the character waits in-world rather than freezing the game. (See §13.) **[DECIDED — but implement after core]**
- **Continuous, infinite, procedural world.** (See §11.)

---

## 4. Characters

Every character (player or NPC) has a **character sheet**:

- **Ability scores:** STR, CON, CHA, DEX, WIS, INT. Used in ability checks, combat (see §5.9 open question), and item-effectiveness gating. **[DECIDED — 6 D&D-style stats]**
- **Level** — battle strength (drives HP/defense/damage scaling and item budget). Represents *military* threat.
- **Status** — a separate attribute representing *diplomatic* threat/standing. LLM-assigned; for NPCs the orchestrator may update it but it is largely static. **For the player, status = level.** **[DECIDED]**
- **Backstory, current goal, personality.**
- **Inventory** — weapons, armor, consumables, money; tradeable/usable.
- **Persistent memory** — continuously appended with noteworthy things (quests, relationships, witnessed events) plus a recent dialogue history.
- **Sentiment map** — this character's raw sentiment toward every other character it knows of (drives territory; see §10).

### 4.1 Observation

The character's LLM observes its surroundings via an **occupancy grid** **[DECIDED — leaning]** — the same representation in and out of combat, so observation is unified with the combat lattice rather than maintaining two systems.

The system also feeds each agent the **last N actions and state transitions**, converted to readable deltas ("moved 1m north", "picked up Iron Spear").

The full structured observation schema (nearby entities, objects, terrain grid, working context) and the rest of the NPC agent runtime — agent loop, goals, memory, relationships, action call surface — are specified in **§14 (AI agent architecture)**.

### 4.2 Atomic actions

The LLM (or human UI) chooses from a small set of **atomic, high-level actions**, each of which may fail with a returned reason (e.g. jumping farther than DEX allows):

- **go to** (position / item / character)
- **jump** (position; also a hook for mounting animals/vehicles **[REACH]**)
- **attack** (target, with which item)
- **say** (text; targeted, or shout → everyone in range hears)
- **trade** (propose / accept / deny; items + money in/out — "giving" is a trade with nothing in return)
- **pick up / drop** (ground or chest)
- **examine** (observable info on an item/person in sight)
- **interact** (generic; e.g. lockpick — target entity + item used)
- **wait** (duration)
- … extensible.

### 4.3 Control loop

While an action is in progress the agent's control loop re-evaluates at some frequency (it *may* change its mind, but is biased toward continuing). It re-evaluates immediately when an action finishes or is interrupted (e.g. attacked while moving). **[DECIDED]** (Speculative-execution optimization: §13.)

---

## 5. Combat system

The heart of the brainstorm. Combat is where "simple rules → deep strategy" is made literal: a **chess-like tactical layer** that emergent multi-step planning (forks, pins, discovered attacks, defended pieces) falls out of.

### 5.1 The keystone

> **Beating a stronger opponent requires winning the chess match, not brute force.**

A hero's raw damage gets *out-scaled* at the frontier (high-level enemy minions have too much HP/defense to power through), but **minion-vs-minion capture is level-independent**. So the only scalable path to defeating a superior foe is to out-position them — capture their pieces with yours. Emergent multi-step planning is therefore not a *feature* of combat; it is the **mechanically-forced path to victory against anyone above your weight.** The numeric layer carries infinite progression; the chess layer carries skill; and the rules push you onto the chess layer exactly when the fight matters. **[DECIDED — north star]**

### 5.2 Soft grid + terrain

When combat starts, all combatants **snap to a soft grid**. Movement animates smoothly so the world still *looks* continuous, but positions and moves *resolve* on a discrete lattice. This buys chess-grade **legibility** (a fork either covers two targets or it doesn't — no fuzzy eyeballing) while keeping fluid visuals. **[DECIDED]**

Terrain carries into the fight and is part of the strategy:
- **Elevation** — sloped cells; high ground matters (see §5.10).
- **Obstacles** — trees, rocks, cliffs block movement and lines.
- **Gaps** — chasms/water create holes in the board (impassable to most, see §5.4).
- **Shove** — a unit on a cliff edge can be pushed into a chasm for an instant removal (see §5.10). **[DECIDED]**

The lattice is **square** **[DECIDED]** — it matches how terrain generation already works and how chess pieces move. The combat lattice is independent of (and probably coarser than) the terrain-generation grid.

### 5.3 Two-tier army

- **Characters** — the player and NPC commanders. The *wildcards*: gear-driven, flexible attack patterns, and **they have facing** (§5.7). A Character is the "king" of its army.
- **Minions** — chess-piece units (summoned via items, or spawned enemies). The clean, readable *substrate*: simple movement, **facing-free**. **[DECIDED]**

**Player = king:** when a character dies, **all of that character's minions despawn.** This makes commanders the strategic center of gravity and imports chess's "protect your king / hunt theirs" tension for free. Consequence to balance: the Frog (leaper) ignores minion walls, so an enemy Frog is a terrifying assassin — commanders cannot be glass cannons. **[DECIDED]**

### 5.4 Minion roster (start with four)

Move pattern and capture pattern can differ (chess's richest idea). **[DECIDED]**

| Minion | Chess analog | Movement / capture | Terrain niche |
|---|---|---|---|
| **Toadstool** | Pawn | move 1 cardinal; capture 1 diagonal | cheap, low HP, numerous; lane-blocking chaff & trade bait |
| **Cat** | Bishop (glider) | diagonal lines until blocked (move=capture) | blockable; pairs with Ent to cover all geometry |
| **Ent** | Rook (charger) | cardinal lines until blocked (move=capture) | blockable → enables discovered attacks & choke control |
| **Frog** | Knight (leaper) | L-hop, jumps over everything (move=capture) | **unblockable**; crosses gaps/walls — the terrain-ignoring assassin |

**Terrain reads differently per piece type** — a chasm is a wall to your Ent but a highway for your Frog. This is the "different pieces, different geometry" goal, multiplied by the map. **[DECIDED]**

**[OPEN]** Whether to add original asymmetric pieces beyond chess (e.g. a "Lancer": drifts slowly, captures in a long telegraphed line). Start with the four.

### 5.5 Movement as armor (the player's chess identity)

The player's movement *is* their gear loadout. Base: **1 cardinal step**. Each armor piece can add a movement capability; grants **union** together into hybrid pieces that don't exist in chess. **[DECIDED]**

- Boots → +1 diagonal (→ king-like)
- Leggings → knight-like hop
- High-tier chestplate → queen-like, up to 2 cells
- (boots + leggings → king + knight hybrid, etc.)

This ties movement directly into the loot loop and into the item power budget (§6).

### 5.6 Weapons & attack patterns

No learned spells/skills/classes — **all abilities live on items** (§6). A weapon has one or more attacks, each **targeting a pattern of cells**, each on a **cooldown** (turns until reusable) instead of D&D spell slots. More powerful attacks → longer cooldowns. **[DECIDED]**

Examples: spear = front; dagger = diagonal; sword = front + diagonals; bow = ring at distance 5–10; fireball = 3×3 AOE within range; flail = all-around-but-lower-damage. Patterns on Characters rotate with facing (§5.7).

### 5.7 Facing

**Characters have facing; minions do not.** **[DECIDED]** Character attack patterns rotate with where the unit looks, which unlocks **backstab, flanking, "turn to guard a lane,"** and punishing exposed facings — roughly doubling the emergent vocabulary. Keeping minions facing-free keeps the board clean and readable. **Rotating a Character is free — it does not cost a turn or an action.** **[DECIDED]**

### 5.8 Turn economy

**[DECIDED]** One round = one turn per player (generalizes to N players, §5.11). On your turn you activate:

- **Your Character:** move **and** one weapon action.
- **One** of your minions: a single chess move — **either** step to a move-cell **or** capture on a capture-cell (exactly like the Toadstool).

Rationale: activating *one* minion + the hero keeps the board **mostly stable** between decisions (so multi-step plans survive), while being faster than pure one-piece-per-turn chess. It also makes **command itself a scarce resource** — you can't march a whole horde, which pushes toward elite squads (static chaff still works as lane-blockers). **[REACH/loot axis]** a banner/horn item granting "+1 minion activation per turn."

### 5.9 Damage matrix

Two layers that scale independently. **Green = tactical (binary, numbers don't apply, never spongy). Numeric = progression (scales forever).**

| Attacker → Target | Rule | Layer |
|---|---|---|
| **Minion → Minion** | **Binary capture** — captured minion dies, attacker survives & takes the cell. Level/HP irrelevant. Pure chess. | tactical **[DECIDED]** |
| **Minion → Player** | Damage = f(minion level), reduced by player defense. **The unbounded scaling axis.** | numeric **[DECIDED]** |
| **Player → Minion** | **Normal weapon damage vs minion HP/defense** (minions have real, level-scaled stats). *Not* an instant wipe — so a cheap low-damage AOE can't free-clear an army; the *type* of attack matters. | numeric **[DECIDED]** |
| **Player → Player** | Weapon damage vs defense — the duel layer. | numeric **[DECIDED — rule], [OPEN — roll/armor model]** |

**[OPEN] — the roll & armor model (player-facing only).** Minion-vs-minion is deterministic regardless. For player-facing damage, undecided (leaning toward including rolls *in* combat):
- (a) **D&D to-hit:** attack roll + ability vs armor class → hit or miss.
- (b) **Armor as damage reduction:** attacks always land; AC subtracts/mitigates damage.
- (c) **Combination:** a to-hit roll *and* armor reduces damage on hit.
Constraint to weigh: dice variance in combat trades away some exact multi-step planning. Recommendation to revisit: keep the tactical (minion) layer deterministic always; if rolls are wanted, confine their variance to the player-facing numeric layer.

### 5.10 Terrain bonuses (split by layer)

Because captures are binary (no "damage" to buff), terrain expresses itself differently per layer: **[DECIDED — direction; details OPEN]**
- **Tactical (m-v-m):** terrain is *positional rules* — high ground extends a slider's reach; uphill lines can be blocked; cliff-edge units can be **shoved into a chasm** (instant removal).
- **Progression (vs players):** terrain is a *damage multiplier* — high-ground / flank / backstab attacks deal bonus damage.

### 5.11 Multiplayer & no fixed sides

There are **no predefined teams**. Any number of commanders (human or LLM) share the field; "one turn per player per round" generalizes naturally. This yields free-for-all politics — alliances, betrayal, ganging up on the leader, letting rivals bleed each other. The tactical core is already N-player-aware (pairwise capture rule, target-anyone). **[DECIDED]**

**[REACH / separate spec]** Formal alliance/pact mechanics (shared vision, no-attack windows), and online netcode/persistence. The tactical layer is designed N-aware now; the heavier *social infrastructure* is its own design pass. First version multiplayer is **local**. **[DECIDED]**

### 5.12 Minion AI (movement solving)

Because the tactical layer is genuine chess, NPC minion play can lean on existing **chess engines / solvers** rather than bespoke AI. **[DECIDED — approach]** This requires customization for what makes our board non-standard:
- the **square map's unique shape** — irregular boundaries, terrain obstacles, elevation, and chasm gaps (not a clean 8×8);
- the **player-as-"king"** moving on a custom, gear-defined pattern (not the chess king's one-step);
- potentially **more than two players** (free-for-all), which standard two-player solvers don't handle natively.

A solver gives strong, readable minion tactics cheaply; the customizations above are the real work. (LLM commanders make the higher-level decisions — which fights to take, who to ally with — while a solver can advise the per-piece tactical move.)

---

## 6. Items, rarity & the power budget

- **All abilities live on items.** No classes; no learned spells/skills/passives. A staff *emits* fireball; a pendant grants shadow-teleport; armor grants movement (§5.5). **[DECIDED]**
- **Unified effect base class.** Melee attacks, projectiles, spells, and actions share one composable base — customized by effect, damage, properties, hitbox shape, sprite, animation, movement. An arrow is "an attack with a projectile movement + arrow sprite"; magic missile = projectile + split + homing. This composability makes **randomized weapons** possible. **[DECIDED]**
- **Rarity tiers:** common, uncommon, rare, legendary, mythic, eternal. Higher rarity → higher chance of more damage and more effects. **[DECIDED]**
- **Item level & obsolescence.** Items have a level; they fall behind as the world's difficulty rises around you — driving the constant search for better gear. **[DECIDED]**
- **Unified power budget.** An item's total power = **rarity × the level of the creature that dropped it**, distributed across movement + defense + effects. Movement and defense **trade off on the same item** (a godlike-mobility chestplate has weak defense), so every drop is a real choice and the treadmill keeps its bite. **[DECIDED]**
- **Drop probability:** each of a defeated enemy's items drops with some probability (~20% each), not always. **[DECIDED]**
- **Ability-score gating of item effectiveness.** A high-level item under-performs for a user whose relevant ability score is too low (e.g. a level-8 WIS armor won't reach its full armor value below WIS 8; a high-INT staff rarely succeeds for a low-INT user). **[DECIDED; interacts with the §5.9 OPEN roll model]**

---

## 7. Progression & difficulty

- **Distance-based difficulty gradient.** Enemy *level* (HP, defense, damage) rises with distance from the player's spawn. To conquer further, you must get stronger — clean, scalable progression. **[DECIDED]**
- **Raw numbers are the infinite axis.** Composition, AI sophistication, squad size, and terrain hazards add *texture and mid-term variety* but **saturate**; only raw numeric scaling is unbounded, which a persistent long-term world needs. The binary minion layer keeps numbers from spongifying tactics (§5.1). **[DECIDED]**
- **Anti-invincibility, structurally guaranteed.** Your gear's budget is capped by what you've *killed*, which is always *behind* the frontier — so the frontier is by definition tougher than your best gear. And **grinding a safe zone can't break it**: that zone only drops its own tier of gear, below the next ring. Only *advancing* makes you stronger; skill lets a clever player punch slightly past their gear tier. **[DECIDED]**
- **Leveling.** On level-up, the character adds one point to an ability score (STR/CON/CHA/DEX/WIS/INT). **[DECIDED]**

---

## 8. Territory & ownership (the overarching goal)

The win/score driver: **conquer territory** on the infinite procedural map. Ownership is **dynamic** — NPCs pursue their own agendas and can capture territory back. Adaptable to any situation by keeping "conquering" flexible. **[DECIDED]**

**Model — unified military + diplomatic** (resolves the combat-vs-diplomacy question): **[DECIDED]**

- Ownership is computed per point as a **distance-weighted average of weighted sentiment**: look at all entities within a large radius; weight each by proximity (closer = higher, e.g. softmin); combine with their **weighted sentiment** toward each player they know. If the top ownership score for a point exceeds a threshold, that player owns it; otherwise it stays neutral.
- **Weighted sentiment** = a character's raw sentiment toward a target, scaled by that character's **status and level** — i.e. higher-status characters represent *diplomatic* weight, higher-level characters represent *military* weight. So **both paths matter**: winning battles (raising your level / removing rival owners) and winning hearts (raising sentiment) both shift ownership. This is a core source of the non-transitive strategy space (§2.4).
- **Raw sentiment** is the per-character variable in each sheet (§4).
- **Raising sentiment:** completing quests raises it (amount judged by LLM from the quest's nature). Pure talk *can* raise it but is deliberately hard — only *truly novel* diplomacy is even considered, so the game can't be cheesed by chatting up everyone. Gated by an **ability check** (CHA + roll vs a DC that factors WIS and max(status, level) — exact formula **[OPEN]**). Once a check is triggered by a given context, that context is stored in memory so similar later attempts don't re-roll. **[DECIDED — mechanism; formula OPEN]**

**[REACH] Sentiment diffusion.** Total sentiment toward you = a character's raw sentiment toward you + a normalized diffused term (their sentiment toward others × those others' sentiment toward you). So being loved by the village leader earns you partial goodwill from the villagers.

**Quests** are not random or forced — they emerge organically from NPC situations and motivations (why would *this* NPC want this done?), shaped by tuning the orchestrator and NPC prompts. Often a quest is really a wild-goose-chase adventure of gathering information, not a quest-giver handing out a task. **[DECIDED — direction; prompt-engineering work]**

---

## 9. Ability checks (the Difficulty-Class agent)

Ability checks are one-off and **hook-triggered** (not polled like the orchestrator), so a dedicated **Difficulty-Class (DC) agent** resolves them: **[DECIDED]**

1. The DC agent decides the **DC** (based on how likely it judges the action to succeed) and the **relevant ability score** (STR/INT/WIS/…).
2. A roll is made: ability score + roll vs DC.
3. On success, a second call (same agent, different system prompt) **resolves the effect** — like a scoped orchestrator.

To avoid repeated rolling, the triggering context is stored in the character's memory (§8 applies the same rule to diplomacy).

**[REACH] Custom typed actions.** Let the player type `/<freeform action>`; the DC agent sets a DC by plausibility, rolls with the relevant ability score, and on success resolves the effect.

---

## 10. Orchestrator agent

The world's "dungeon master" — the second LLM layer alongside the per-character NPC agents (§14). Responsible for: **[DECIDED — scope; ongoing prompt work]**

- **Spawning characters** with personas/skills/items/backstories predicted to weave interesting narratives. Good generation trick: first **roll the skill sheet** (sampled from ranges by unit role + local region difficulty), then let the LLM write a personality/backstory that *explains* the rolls (e.g. high CHA, low WIS → a charming fool).
- **Resolving world events** via tools: add/remove objects, edit properties/states (move an object, play an animation), trigger trap effects when a character hits a pressure plate, etc.
- **[REACH] Persistent rules.** Add/edit/remove standing effects so the LLM needn't resolve recurring effects every tick (e.g. an enchanted object that lures entities failing a check). Needs a rules engine.
- **[REACH] Terrain-generation guidance.** Let the orchestrator tweak generation parameters (or regenerate a region) when the story needs it.

---

## 11. Terrain, world generation & art direction

**This is the current main focus — the first thing being built (see §17).** The goal is for the game to look *absolutely stunning*; the terrain renderer and its atmosphere are the foundation everything else sits on. The world is **procedural, infinite, and deterministic per seed**, streamed in chunks around the active camera, and built from real low-poly assets (purchased libraries, §11.11). This section is the vision; each subsystem below (§11.3–§11.9) is its own spec → plan → build.

### 11.1 The visual target (cute fantasy)

The target vibe: **a cozy, glowing miniature diorama seen through mist.** Reference images live in `~/Desktop/game visual inspiration` (Sea of Solitude, Arise, low-poly stylized dioramas, glowing-lantern night scenes, floating islands). Four reference beats anchor the mood: **[DECIDED — art direction]**

- **Cozy daytime village** — bright, saturated low-poly meadow; warm dirt paths; stone/wood bridges; cone-firs and pebble-rocks; banner-hung timber houses; strong tilt-shift so it reads as a toy set.
- **Misty twilight forest** — teal-blue gloom, tall silhouetted firs, drifting yellow fireflies, a single warm lantern glowing on a stump; cattails and lily pads. The eerie-but-cute pocket.
- **Night pond-house** — amber windows and hanging lanterns mirrored in still water, fireflies, deep-blue ambient. The "amber-on-blue" signature at its purest.
- **Torch-lit cinematic warmth** — a knot of warm torchlight against a cool night gradient; how key moments should feel.

The defining ingredients (each detailed in §11.9):

- **Stylized low-poly base.** Flat-shaded, faceted geometry; soft rounded forms; chunky cone-firs and pebble-rocks. Cute and readable, not realistic — and it doubles perfectly as a tactical diorama for combat (§5.2).
- **Cool-vs-warm contrast (the signature).** A cool ambient base — teal, indigo, dusky-blue mist — punctuated by **warm pinpoint lights**: lantern-lit windows, hanging lanterns, campfires, glowing mushrooms (on-theme with the Toadstool minions), and floating glowing orbs. Amber-on-blue is the magic.
- **Volumetric mist & depth fog** that dissolves the background and carves the world into brighter and darker pockets.
- **Floating glowing particles everywhere** — fireflies, drifting spores, dust motes, embers — soft and warm.
- **Tilt-shift / miniature depth-of-field**, and **bloom** on every warm emissive; soft long shadows; pastel accents (pink blossom trees).

**Mood is biome-driven, not a difficulty read-out.** Luminance and palette come from the **biome** at a point (§11.3), so an eerie twilight pocket can sit near spawn and a bright meadow can sit deep in the frontier. Difficulty is carried by enemy *level*, which still rises with distance (§7); the visual gradient mainly reinforces settlement warmth (territory hubs, §8) rather than encoding danger. **[DECIDED — supersedes the earlier "luminance encodes the difficulty gradient" framing.]**

### 11.2 The generation pipeline (field stack)

Generation is a stack of **deterministic fields** sampled per world position (`Helper.*`), meshed and dressed per chunk by the field-terrain streamer. The existing base already does the first three layers; the new work slots in as additional layers over the same architecture — no rewrite. **[DECIDED — architecture]**

1. **Base heightfield** — `TerrainSurfaceField` → `TerrainChunkMesher` mesh the height/slope field; `CliffDressing` adds KayKit cliff/storey pieces. *(Exists.)*
2. **Biome fields** — `forest` / `rocky` plus a new **moisture/mood** axis resolve to named biomes that modulate everything downstream (§11.3). *(Extends existing `Helper.biome_*`.)*
3. **Water field** — rivers/ponds/lakes carved from the height/water fields, one world-space water sheet (§11.4). *(Exists, to expand.)*
4. **Aerial / floating-island layer** *(new)* — a sparse island field lifts island chunks into an altitude band with their own mini-heightfields (§11.5).
5. **Settlement & path layer** *(new)* — places villages and carves a path graph connecting them, flattening ground and reserving footprints (§11.6).
6. **Decoration & prop scatter** — deterministic per-cell flora + props, biome- and context-gated (`DecorationScatter`, to expand; §11.7).
7. **Dynamic grass layer** *(new / replacement)* — GPU-instanced wind grass over walkable ground (§11.8), replacing the static grass scenes.

Everything stays seed-deterministic and chunk-streamable (unload when no character is near, reload on return — §13), so headless generation (§2.6) reproduces the same world.

### 11.3 Biomes

**Continuous fields that resolve into named biomes.** **[DECIDED]** Today two noise axes (`forest`, `rocky`) weight the asset distribution; we add a **moisture/mood** axis and resolve the dominant combination at each point into a *named* biome. Borders stay organic (fields blend by weight); the name drives a **biome profile** — grass/tree/rock tint, fog + sky + ambient colour, foliage density, asset-size distribution, and an allowed **prop set**.

v1 biomes:

| Biome | Palette / mood | Signature content |
|---|---|---|
| **Meadow** (spawn) | bright warm green, open, high light | short grass, scattered firs, flowers, the starting village |
| **Deep forest** | deep saturated green, shaded, dense | **tall canopy trees**, bushes, mushrooms, dim floor |
| **Highland / rocky** | cool grey-green, sparse, windswept | **big boulders**, cliffs, hardy shrubs, stone henges |
| **Blossom grove** | pastel pinks, soft, dreamy | pink blossom trees, drifting petals, gentle light |
| **Twilight marsh** (pocket) | teal-indigo gloom, eerie-cute | cattails, lily pads, toadstools, **floating glowing orbs**, fog, fireflies |

**Twilight marsh is a scattered pocket biome** — it can appear anywhere, independent of distance/difficulty, as an isolated eerie hollow (§11.1). The others distribute by the forest/rocky/moisture fields. **[DECIDED]** **[OPEN]** final biome roster and the exact field→biome resolution (thresholds, blend weights).

### 11.4 Water — rivers, ponds & lakes

Rivers (ridged-noise bands), ponds, and lakes are carved by the water field (`Helper.is_water`) and rendered by a single world-space animated water sheet, so there are no per-tile seams. **[DECIDED — exists]** Extensions: crossings are spanned by **bridges** (§11.7) where a path meets water (§11.6); banks get reeds/cattails/lily-pads; twilight-marsh water is darker and orb-lit. Water is **impassable terrain in combat** — a gap/board-hole most pieces can't cross but the Frog leaps (§5.4), and a cliff-edge over water enables shove-offs (§5.10).

### 11.5 Floating islands

**A common, walkable aerial layer.** **[DECIDED]** A sparse island field lifts chunks of land into an **altitude band** above the ground plane, each island carrying its own mini-heightfield, cliffs, biome, flora, and props — small floating dioramas. Islands are a routine part of traversal, reached by **jump/traversal** (§4.2) and linked to the ground or to each other by **bridges and vine/rope ladders** (§11.7). The **void beneath an island is a combat board-hole** — impassable to most pieces, crossed by the Frog leaper, and a shove target off island edges (§5.4, §5.10). Distant, non-walkable islands also drift in the far sky for depth and spectacle. **[OPEN]** altitude-band range, island density, and how traversal reaches them (jump-only vs. required bridges/lifts); **[REACH]** moving/drifting islands.

### 11.6 Settlements & paths

**Hybrid villages: a procedural layout places hand-authored building scenes.** **[DECIDED]** Building exteriors/interiors are hand-made scenes (one or a few variants per type — matching the interior stance kept from the old §11.2); a settlement generator picks a site (flattened ground), lays out a **cluster** of buildings with orientation and spacing rules, and dresses it with props (fences, lantern posts, carts, market stalls, water wheels). A **path graph** connects settlements and points of interest, carving dirt paths across the heightfield (slight flattening), bridging water (§11.4), and lining routes with fences and **hanging lantern posts** (§11.9). Villages are the **warm-light signature of territory/social hubs** (§8). **[OPEN]** settlement placement rule (density, biome gating, spacing from spawn); **[REACH]** procedural building footprints.

### 11.7 Decoration & props

Scatter grows from flora-only into **flora + a prop catalog**, still deterministic per cell and now **biome- and context-gated**. **[DECIDED — direction]**

- **Flora:** grass, bushes, trees, mushrooms, flowers, reeds — density and size from the biome field. **Trees get taller with fuller canopies** and **rocks get bigger** (boulders), with per-biome size distributions (deep forest = tall canopy; highland = big boulders). **[DECIDED]**
- **Props:** bridges, **toadstools** (on-theme with the Toadstool minion, §5.4), **stone henges**, **carts**, **lantern posts**, fences, barrels, crates, market stalls, water wheels, signposts.
- **Context rules** place props where they read as intentional: bridges at path↔water crossings; toadstools/cattails in wet & twilight ground; stone henges in highland clearings; fences/lanterns/carts along paths and in villages; barrels/crates near buildings. **[OPEN]** the full prop catalog and per-biome/context placement weights.

### 11.8 Dynamic grass

Replace the static grass scenes with a **GPU-instanced dynamic grass** system covering walkable ground. **[DECIDED]** Blades are instanced per chunk with density from the biome foliage field, **animated by a wind shader** (rolling gusts), and **bend/part as characters move through them** (character positions fed to the grass shader as displacement). Tinted per biome (§11.3). Must stay cheap enough for the infinite streamer and be disable-able in headless mode (§2.6). **[OPEN]** interaction fidelity (simple radial push vs. persistent trampled trails) and LOD / draw-distance strategy.

### 11.9 Lighting & atmosphere

The render stack that sells the diorama — the bulk of "make it stunning." **[DECIDED — direction; tuning ongoing]**

- **Global grade:** cool ambient base, warm key light; strong **cool-vs-warm** separation. Ambient fill is a warm-neutral colour (not the blue sky) so shadowed stone still reads as stone.
- **Per-biome atmosphere:** each biome sets its own **fog colour/density, sky gradient, and ambient**, so crossing a biome border shifts the mood (§11.3). Twilight marsh = dense teal fog, low light, high firefly/orb density.
- **Warm point-lights + bloom:** lantern posts, windows, campfires, and glowing mushrooms are emissive point-lights with **bloom** — the warm pinpoints of the signature.
- **Floating glowing orbs** *(twilight pockets)* — slow-drifting **particles that also cast light** (or carry cheap point-lights): the eerie light source where there are no lanterns.
- **Particles everywhere:** fireflies, spores, dust motes, embers — biome-tuned density, always soft and warm.
- **Camera:** **tilt-shift / miniature depth-of-field** (near/far blur) and soft long shadows to sell the toy-diorama scale.

Headless mode (§2.6) skips the render stack entirely; none of it may affect simulation.

### 11.10 Mechanics tie-ins

- **Combat diorama** — the low-poly world *is* the tactical board; combat snaps onto it (§5.2).
- **Board-holes** — water and the voids under floating islands are impassable gaps most pieces can't cross but the Frog leaps; cliff/island edges enable shove-offs (§5.4, §5.10).
- **Territory signature** — settlement warm-light marks social/territory hubs (§8).
- **Difficulty vs. mood** — difficulty is enemy level by distance (§7); mood/luminance is biome-driven and does **not** primarily encode danger (§11.1).

### 11.11 Asset libraries

The world is built from **purchased low-poly asset libraries** in a consistent stylized-fantasy look, so no bespoke modelling is needed to start. Both sources below are low-poly/stylized and intermix cleanly. **[DECIDED — sources]**

- **KayKit (Kay Lousberg)** — the stylized low-poly base already in the project (KayKit cliff dressing today). Relevant packs: **Forest Nature Pack** (trees, rocks, grass — the flora of §11.7); **Dungeon Pack Remastered**, **Medieval Hexagon Pack**, and **City Builder Bits** (building/structure kit for villages & interiors, §11.6); **Halloween Bits** (cemetery/spooky props for twilight-marsh dressing & stone henges, §11.3/§11.7); **Character Packs** — Adventurers, Skeletons, Mystery Monthly + Character Animations (rigged, animated characters & monsters for §4/§5); **Fantasy Weapons Bits** / **RPG Tools Bits** / **Board Game Bits** (weapons and game-piece minions for §5/§6).
- **Daniel Mistage — STYLIZED Fantasy series** — warm, cozy fantasy content matching the reference vibe (§11.1). Relevant packs: **Fantasy Village** (800+ buildings/structures/environment — §11.6); **Fantasy Market** (stalls & vendor goods — village props + trade, §4.2/§11.6); **Fantasy Tavern & Kitchen** and **Fantasy Interior Pack** (hand-made building interiors, §11.6); **Fantasy Workshops & Crafting** (crafting stations for §10/§11.7); **Fantasy Alchemy Pack** (magical props & consumables); **Fantasy Armory**, **Forge & Armory**, and **Battle Pack** (weapons & combat props for §6).

**Indirection:** keep a thin **asset-tag → scene mapping** so field scatter and placement (§11.2, §11.7) reference *tags* (`tree`, `rock`, `bridge`, `lantern`, …), never hard-coded packs — packs can then be swapped or extended without touching generation. This matches the existing `DecorationScatter` tag system. **[DECIDED]**

---

## 12. Multiplayer

This is a multiplayer game; the world supports multiple **player** characters. **Local multiplayer first**, but architect with **online multiplayer** in mind. The "no preferential treatment" principle (§2.3) — players and NPCs sharing one interface — is what keeps multiplayer balanced. **[DECIDED]** (Combat already supports N players with no fixed sides, §5.11.)

---

## 13. Engineering & optimization

Implement only once the core works, or when speed demands it. **[REACH unless noted]**

- **Headless mode** — first-class, not an afterthought (§2.6). **[DECIDED — core]**
- **Async agents** — the sim never blocks on character/orchestrator LLM output; agents run asynchronously and the character waits in-world instead of lagging the game.
- **Speculative next action** — while an action runs, the agent also emits its *predicted* next action; when the current action finishes, start the prediction immediately while computing the real next action against fresh observations. If they match, seamless; if not, abort and switch.
- **Terrain spatial index** — index terrain; unload when no character is near, reload on return.
- **Distance-based LLM back-off** — lower the action-recalculation frequency for agents far from any human player (mainly affects long-running actions; most actions are quick). A growing back-off with distance.

---

## 14. AI agent architecture (NPC simulation)

Every NPC is a fully-simulated autonomous agent driven by an LLM. The agent is a **decision-maker only** — it never simulates the world. Movement, combat, inventory, item effects, and physics are resolved deterministically by the engine; the LLM only chooses atomic actions through the *same interface the player uses* (§2.3). This section specifies the agent's runtime loop and the structured state it reasons over. It builds on §4 (Characters) and complements §10: the two LLM layers are the per-character agents (here) and the single world "DM" orchestrator (§10). The whole system is looter-based — all abilities, attacks, and effects derive from items/equipment (§6), never from character skills or a mana system. **[DECIDED — architecture; build after the mechanical core is headless-testable, per §17.]**

### 14.1 Agent loop

The LLM is **not queried every frame** — only at decision points. Each NPC runs a repeated decide→execute cycle:

1. Observe the local environment (§14.3).
2. Retrieve relevant memories, goals, and relationship edges (§14.4–§14.6).
3. Assemble a structured context for the LLM.
4. Generate one or more structured actions (function calls, §14.7).
5. Execute them in the game engine.
6. Keep executing the current action until **completion** or **interruption** (combat begins, dialogue opens, a new threat appears, …).
7. Repeat.

This is the same continue-biased control loop as §4.3 — re-evaluating on finish/interrupt rather than per-tick — which is what keeps LLM-call volume (and cost) down. The async / speculative-next-action / distance-based back-off optimizations that ride on top live in §13.

### 14.2 Character sheet (the agent's persistent state)

The structured, persistent per-NPC state — the same character sheet defined in §4, itemized here from the agent's point of view:

- **Core:** name; health/HP; ability scores (STR/CON/CHA/DEX/WIS/INT — used for item scaling and checks, §4/§6); inventory (items held); equipment (currently equipped).
- **Identity:** generated bio/backstory; personality traits (sampled from the character-builder, §10); high-level behavioral tendencies (e.g. greedy, cautious, aggressive, friendly).
- **Goals pointer:** goals live in their own store (§14.5); the sheet carries a reference for convenience.

(Explicit health/HP and behavioral-tendency tags are the additions over §4's list.)

### 14.3 Observation system

Local, immediately-relevant world state **only**. Global state (weather, time, region-simulation layers) is **intentionally omitted for now** — not required by current gameplay design. Observation extends §4.1 (occupancy grid + last-N action/state deltas) with a structured, legible view:

- **Nearby entities** — per visible entity: id; type (NPC / player / monster / object); name (if known); relative offset (dx, dy or 3D); distance; line-of-sight status; current action (if observable); health state (if visible); equipment (if visible/relevant).
  > e.g. *Goblin (#42) — pos (+5, −2), 6.3 m, action "Attacking Merchant", Injured.*
- **Nearby objects** — interactables: ground items, chests/containers, doors, corpses, crafting stations, gameplay-relevant environment. Each with: type; position; interaction state (open/closed, locked/unlocked, …); visibility/accessibility.
- **Terrain [OPEN — representation].** Deliberately flexible for iteration. Candidate: a small adjacency grid around the NPC (e.g. 5×5 / 7×7), each tile carrying walkability, movement cost, occupancy, and terrain type — with optional elevation, cover value, and LoS-blocking. It must balance tactical usefulness (for combat, §5), compactness (LLM-context budget), and ease of generation from the procedural world. This should converge with the combat lattice (§5.2) and §4.1's occupancy grid rather than becoming a third representation.
- **Working context** — short-lived, not persisted: current conversation state, current combat state, current task ("traveling to X"), and optional scratch reasoning notes.

### 14.4 Memory system

Segmented, persistent (the "persistent memory" of §4), across three stores plus relationships (§14.6):

- **Knowledge / events** — a first-person log of experiences and facts ("Saw Alice enter the tavern yesterday", "Goblin ambush near the forest road", "Merchant buys iron weapons"). This grows large over time. Initial implementation: inject recent events directly, with an optional query tool for older items (§14.8). No consolidation is assumed at this stage.
- **Lessons / rules** — durable behavioral heuristics distilled from experience ("Fire weapons are effective against trolls", "Guards react violently to theft", "Avoid fighting multiple enemies alone"). These persistently bias future decisions.

### 14.5 Goals

Structured intent over time; goals can be marked complete, replaced, or reprioritized dynamically.

- **Long-term** (often persistent): acquire wealth, obtain powerful items, gain status/influence, explore unknown regions, survive/stay safe, or a specific assigned narrative goal.
- **Short-term** (immediately actionable): go to a location, defeat an enemy, loot an item, sell inventory, complete a trade, escape danger.

Goals feed and are shaped by the territory/sentiment loop (§8) and by quests that emerge organically from NPC situations and orchestrator seeding (§8, §10).

### 14.6 Relationship system

Relationships live **on edges between entities**, not inside any single NPC's memory — a shared graph, retrieved when interacting with that specific target. Each edge carries: target entity id; **trust**; **fear**; **respect**; **familiarity**; and a short summary of key interactions.
> e.g. *A ↔ B — trust 0.7, fear 0.2, "Helped each other escape a goblin attack."*

This is the richer, structured form of §4's **sentiment map**, and it feeds §8's ownership math — where the "raw sentiment" a character holds toward a player (scaled by status/level into *weighted* sentiment) is what these edges express. **[OPEN — reconcile]** exactly which scalar(s) here map to §8's raw-sentiment term (e.g. `trust − fear`, or a derived composite).

### 14.7 Action system

The LLM emits **structured function calls** — the concrete call surface of §4.2's atomic actions. Grouped:

- **Movement / navigation:** `MoveTo(position)` · `MoveTo(entity)` · `MoveRelative(offset)` · `Roam(area)`
- **Social:** `Talk(target)` · `Trade` / `ProposeTrade` / `AcceptTrade` / `DenyTrade(target)`
- **Inventory:** `ViewInventory()` · `Take(item)` · `Drop(item)` · `AccessInventory(target)`
- **Combat:** `Attack(target, weapon/attack-mode derived from item, §5.6)` · `Flee(destination / avoid entity)`
- **Interaction:** `Interact(target)` · `Query(target)`

Every call may fail with a returned reason (§4.2). This surface maps onto §4.2's canonical set (go to → `MoveTo`, say → `Talk`, examine → `Query`, pick up/drop → `Take`/`Drop`, interact/lockpick → `Interact`); **§4.2 remains the authoritative list** — keep the two in sync as the interface firms up.

### 14.8 Memory retrieval (simple first version)

Start lightweight: **always** inject recent memories directly, and add an **optional retrieval tool** for querying older memories on demand ("What do I remember about Alice?", "What happened near the forest?"). Heavier indexing / RAG is deferred until scale demands it. **[REACH]**

### 14.9 Agent design principles

- NPCs are full agents, equal to players in capability; only the decision function differs (§2.3).
- The LLM decides; the engine simulates (§3). All abilities originate from items (§6) — no intrinsic skills or mana.
- Observations are **local and structured**, never global state dumps (§14.3).
- Memory is segmented into events, lessons, goals, and relationship edges (§14.4–§14.6).
- Minimize LLM calls via action persistence + interruption-driven re-evaluation (§14.1, §13).
- Keep perception / memory / reasoning **modular** so each can be improved iteratively and independently.

---

## 15. Open decisions (consolidated)

1. **Combat roll & armor model (player-facing)** — to-hit roll vs armor-as-reduction vs combination; whether rolls happen in combat at all (leaning yes). Minion layer stays deterministic. (§5.9)
2. **Original asymmetric minions** beyond the four chess pieces? (§5.4)
3. **Exact diplomacy-check formula** — CHA + roll vs DC(WIS, max(status, level)). (§8)
4. **Ownership thresholds & weighting functions** (softmin temperature, radius, threshold). (§8)

## 16. Reach goals (consolidated)

- Sentiment diffusion (§8); custom `/actions` (§9); orchestrator persistent-rules engine & terrain guidance (§10); mounts/vehicles via jump (§4.2); "+activation" command gear (§5.8); formal alliances + online multiplayer + persistence (§5.11, §12); the optimization suite (§13).

## 17. Decomposition (suggested implementation order)

This document is the vision; each subsystem deserves its own spec → plan → build cycle.

1. **Terrain, world generation & art direction (§11) — the current main focus, and the first step.** Nail the stunning "cozy glowing miniature diorama" look on top of the existing field-driven heightfield, layer by layer: named biomes with per-biome palette/atmosphere (§11.3), expanded water (§11.4), the walkable floating-island layer (§11.5), hybrid villages + path network (§11.6), flora & prop scatter with taller canopy trees / bigger rocks (§11.7), GPU dynamic wind-and-character-reactive grass (§11.8), and the lighting/atmosphere stack — cool-vs-warm grade, mist/fog, warm point-lights, glowing orbs, particles, tilt-shift DoF, bloom (§11.9). Everything else is staged on a world that already looks beautiful.
2. **Combat core** (soft-grid snap, units, the four minions, turn economy, deterministic damage matrix, movement-as-armor) — the most-designed and most load-bearing gameplay piece; build it headless-testable, rendered as a diorama on the terrain.
3. **Items & power budget** (effect base class, rarity, randomization, drops) — feeds combat.
4. **Characters & atomic actions** (sheets, inventory, action interface, control loop) — needed for both human and LLM control; build the interface before the LLM brains.
5. **Ability checks (DC agent)** and **orchestrator** — the LLM layer, on top of a working mechanical sim.
6. **Territory & sentiment** — the progression goal, once characters and combat exist.
7. **Multiplayer hardening, then the reach goals.**
